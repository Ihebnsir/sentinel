package com.iheb.sentinel.weekly

import org.json.JSONArray
import org.json.JSONObject

/**
 * Compteurs d'une semaine. Que des nombres : jamais de domaine,
 * de texte de message ni de nom de réseau.
 */
data class WeekStats(
    /** Lundi de la semaine, en jours depuis le 1er janvier 1970. */
    val week: Long,
    /** Totaux qui s'additionnent (requêtes bloquées, messages…). */
    val counters: Map<String, Long> = emptyMap(),
    /** Dernière valeur vue (apps à risque, mots de passe faibles…). */
    val gauges: Map<String, Int> = emptyMap(),
    /** Premier score de la semaine. */
    val scoreStart: Int? = null,
    /** Dernier score de la semaine. */
    val scoreEnd: Int? = null,
) {
    val isEmpty: Boolean
        get() = counters.values.all { it == 0L } && gauges.isEmpty() && scoreEnd == null
}

/**
 * Agrégation et effacement du bilan de la semaine (logique pure, testée
 * sur la JVM). L'enregistrement est dans WeeklyStatsStore.
 */
object WeeklyLedger {
    /** Semaines gardées : la semaine en cours et les 7 précédentes. */
    const val RETENTION_WEEKS = 8

    private const val DAY_MS = 24 * 60 * 60 * 1000L
    private const val MAX_DELTA = 1_000_000L
    private const val MAX_GAUGE = 100_000

    /** Liste fermée : toute autre clé est refusée (pas de texte libre). */
    val COUNTERS = setOf(
        "messages",
        "scam_alerts",
        "blocked_malware",
        "blocked_trackers",
        "blocked_ads",
        "blocked_impersonation",
    )
    val GAUGES = setOf("risky_apps", "pw_weak", "pw_reused", "pw_breached")

    /** Lundi (heure locale) de la semaine qui contient [epochMillis]. */
    fun weekOf(epochMillis: Long, utcOffsetMillis: Int): Long {
        val day = Math.floorDiv(epochMillis + utcOffsetMillis, DAY_MS)
        // Le 1er janvier 1970 (jour 0) était un jeudi.
        return day - Math.floorMod(day + 3, 7L)
    }

    /** Ajoute [deltas] aux compteurs de la semaine [week]. */
    fun add(weeks: List<WeekStats>, week: Long, deltas: Map<String, Long>): List<WeekStats> {
        val valid = deltas.filter { (key, n) -> key in COUNTERS && n in 1..MAX_DELTA }
        if (valid.isEmpty()) return weeks
        return change(weeks, week) { stats ->
            val counters = stats.counters.toMutableMap()
            for ((key, n) in valid) counters[key] = (counters[key] ?: 0L) + n
            stats.copy(counters = counters)
        }
    }

    /** Remplace la dernière valeur vue de [key]. */
    fun setGauge(weeks: List<WeekStats>, week: Long, key: String, value: Int): List<WeekStats> {
        if (key !in GAUGES || value !in 0..MAX_GAUGE) return weeks
        return change(weeks, week) { it.copy(gauges = it.gauges + (key to value)) }
    }

    /** Le premier score de la semaine reste, le dernier remplace l'ancien. */
    fun recordScore(weeks: List<WeekStats>, week: Long, score: Int): List<WeekStats> {
        if (score !in 0..100) return weeks
        return change(weeks, week) { it.copy(scoreStart = it.scoreStart ?: score, scoreEnd = score) }
    }

    /**
     * Efface les semaines trop anciennes (plus de 8 semaines) et celles
     * « du futur » (horloge changée) ; trie par date.
     */
    fun prune(weeks: List<WeekStats>, currentWeek: Long): List<WeekStats> {
        val oldest = currentWeek - (RETENTION_WEEKS - 1) * 7L
        return weeks.filter { it.week in oldest..currentWeek && !it.isEmpty }.sortedBy { it.week }
    }

    /** La notification part une fois par semaine, le lundi dès 9 h (ou après). */
    fun shouldNotify(
        enabled: Boolean,
        currentWeek: Long,
        lastNotifiedWeek: Long?,
        localHour: Int,
        previous: WeekStats?,
    ): Boolean {
        if (!enabled || localHour < 9) return false
        if (lastNotifiedWeek != null && lastNotifiedWeek >= currentWeek) return false
        // Rien à montrer pour la semaine passée : pas de notification.
        return previous != null && !previous.isEmpty
    }

    /** Semaine en cours et précédente, pour l'écran « Bilan » (Dart). */
    fun snapshot(weeks: List<WeekStats>, currentWeek: Long): Map<String, Any?> {
        val current = weeks.firstOrNull { it.week == currentWeek } ?: WeekStats(currentWeek)
        val previous = weeks.firstOrNull { it.week == currentWeek - 7 }
        return mapOf("current" to toMap(current), "previous" to previous?.let(::toMap))
    }

    private fun toMap(stats: WeekStats): Map<String, Any?> = mapOf(
        "week" to stats.week,
        "counters" to stats.counters,
        "gauges" to stats.gauges,
        "scoreStart" to stats.scoreStart,
        "scoreEnd" to stats.scoreEnd,
    )

    private fun change(weeks: List<WeekStats>, week: Long, update: (WeekStats) -> WeekStats): List<WeekStats> {
        val existing = weeks.firstOrNull { it.week == week } ?: WeekStats(week)
        return weeks.filter { it.week != week } + update(existing)
    }

    fun toJson(weeks: List<WeekStats>): String {
        val array = JSONArray()
        for (stats in weeks) {
            val item = JSONObject().put("w", stats.week)
            item.put("c", JSONObject().apply { stats.counters.forEach { (k, v) -> put(k, v) } })
            item.put("g", JSONObject().apply { stats.gauges.forEach { (k, v) -> put(k, v) } })
            stats.scoreStart?.let { item.put("s0", it) }
            stats.scoreEnd?.let { item.put("s1", it) }
            array.put(item)
        }
        return array.toString()
    }

    /** Lecture tolérante : contenu illisible → aucune semaine ; clés inconnues ignorées. */
    fun fromJson(json: String?): List<WeekStats> {
        if (json.isNullOrEmpty()) return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).mapNotNull { index ->
                val item = array.optJSONObject(index) ?: return@mapNotNull null
                if (!item.has("w")) return@mapNotNull null
                val c = item.optJSONObject("c")
                val g = item.optJSONObject("g")
                WeekStats(
                    week = item.getLong("w"),
                    counters = COUNTERS.filter { c?.has(it) == true }
                        .associateWith { c!!.getLong(it) }
                        .filterValues { it > 0 },
                    gauges = GAUGES.filter { g?.has(it) == true }.associateWith { g!!.getInt(it) },
                    scoreStart = if (item.has("s0")) item.getInt("s0") else null,
                    scoreEnd = if (item.has("s1")) item.getInt("s1") else null,
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }
}
