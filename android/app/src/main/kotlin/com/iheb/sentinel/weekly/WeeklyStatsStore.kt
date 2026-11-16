package com.iheb.sentinel.weekly

import android.content.Context
import java.util.TimeZone
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.TimeUnit

/**
 * Bilan de la semaine enregistré sur le téléphone (SharedPreferences
 * privées, exclues de la sauvegarde Android comme tout le reste).
 * Seulement des compteurs : voir WeeklyLedger.
 */
object WeeklyStatsStore {
    private const val PREFS = "sentinel_weekly"
    private const val KEY_WEEKS = "weeks"
    private const val KEY_NOTIFY = "notify_enabled"
    private const val KEY_LAST_NOTIFIED = "last_notified_week"

    // Le pare-feu compte beaucoup : écriture groupée au plus 30 s après.
    private const val FLUSH_DELAY_SECONDS = 30L

    private val pending = HashMap<String, Long>()
    private var flushScheduled = false

    private val writer by lazy {
        ScheduledThreadPoolExecutor(1) { r -> Thread(r, "sentinel-weekly").apply { isDaemon = true } }
    }

    fun currentWeek(now: Long = System.currentTimeMillis()): Long =
        WeeklyLedger.weekOf(now, TimeZone.getDefault().getOffset(now))

    /** +[n] sur un compteur de la liste fermée (appelable depuis n'importe quel thread). */
    fun count(context: Context, key: String, n: Long = 1) {
        if (key !in WeeklyLedger.COUNTERS || n <= 0) return
        val app = context.applicationContext
        synchronized(this) {
            pending[key] = (pending[key] ?: 0L) + n
            if (flushScheduled) return
            flushScheduled = true
        }
        writer.schedule({ flush(app) }, FLUSH_DELAY_SECONDS, TimeUnit.SECONDS)
    }

    /** Écrit tout de suite les compteurs en attente. */
    fun flush(context: Context) {
        val deltas = synchronized(this) {
            flushScheduled = false
            HashMap(pending).also { pending.clear() }
        }
        if (deltas.isEmpty()) return
        update(context) { weeks, week -> WeeklyLedger.add(weeks, week, deltas) }
    }

    fun setGauge(context: Context, key: String, value: Int) =
        update(context) { weeks, week -> WeeklyLedger.setGauge(weeks, week, key, value) }

    fun recordScore(context: Context, score: Int) =
        update(context) { weeks, week -> WeeklyLedger.recordScore(weeks, week, score) }

    /** Semaine en cours et précédente ; efface au passage les trop anciennes. */
    fun snapshot(context: Context): Map<String, Any?> {
        flush(context)
        val weeks = update(context) { weeks, _ -> weeks }
        return WeeklyLedger.snapshot(weeks, currentWeek())
    }

    /** Semaines gardées (après effacement des anciennes). */
    fun weeks(context: Context): List<WeekStats> = update(context) { weeks, _ -> weeks }

    fun notificationsEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_NOTIFY, false)

    fun setNotificationsEnabled(context: Context, enabled: Boolean) {
        val editor = prefs(context).edit().putBoolean(KEY_NOTIFY, enabled)
        // Pas de notification immédiate pour une semaine déjà finie.
        if (enabled) editor.putLong(KEY_LAST_NOTIFIED, currentWeek())
        editor.apply()
        WeeklyReportJob.sync(context)
    }

    fun lastNotifiedWeek(context: Context): Long? =
        prefs(context).takeIf { it.contains(KEY_LAST_NOTIFIED) }?.getLong(KEY_LAST_NOTIFIED, 0)

    fun markNotified(context: Context, week: Long) {
        prefs(context).edit().putLong(KEY_LAST_NOTIFIED, week).apply()
    }

    // Lit, efface les semaines trop anciennes, applique [change], écrit.
    @Synchronized
    private fun update(context: Context, change: (List<WeekStats>, Long) -> List<WeekStats>): List<WeekStats> {
        val prefs = prefs(context)
        val week = currentWeek()
        val before = prefs.getString(KEY_WEEKS, null)
        val weeks = WeeklyLedger.prune(change(WeeklyLedger.prune(WeeklyLedger.fromJson(before), week), week), week)
        val after = if (weeks.isEmpty()) null else WeeklyLedger.toJson(weeks)
        if (after != before) {
            val editor = prefs.edit()
            if (after == null) editor.remove(KEY_WEEKS) else editor.putString(KEY_WEEKS, after)
            editor.apply()
            // Des données existent : la tâche quotidienne les effacera à temps.
            if (before == null) WeeklyReportJob.sync(context)
        }
        return weeks
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
