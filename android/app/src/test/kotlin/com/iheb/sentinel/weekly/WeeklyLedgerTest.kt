package com.iheb.sentinel.weekly

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Bilan de la semaine : agrégation, effacement après 8 semaines, notification. */
class WeeklyLedgerTest {

    private val day = 24 * 60 * 60 * 1000L

    // Lundi 16 novembre 2026 = jour 20773 depuis le 1er janvier 1970.
    private val monday = 20773L

    @Test
    fun `la semaine commence le lundi en heure locale`() {
        val mondayNoon = monday * day + 12 * 3_600_000L
        assertEquals(monday, WeeklyLedger.weekOf(mondayNoon, 0))
        // Dimanche 23 h 30 : encore la même semaine.
        assertEquals(monday, WeeklyLedger.weekOf((monday + 6) * day + 23 * 3_600_000L + 1_800_000L, 0))
        // Lundi suivant.
        assertEquals(monday + 7, WeeklyLedger.weekOf((monday + 7) * day, 0))
        // Dimanche 23 h UTC = lundi 0 h à Tunis (UTC+1).
        assertEquals(monday + 7, WeeklyLedger.weekOf((monday + 6) * day + 23 * 3_600_000L, 3_600_000))
        // Avant 1970 aussi (floorDiv) : le 29 décembre 1969 était un lundi.
        assertEquals(-3L, WeeklyLedger.weekOf(0, 0))
    }

    @Test
    fun `les compteurs s'additionnent dans la bonne semaine`() {
        var weeks = WeeklyLedger.add(emptyList(), monday, mapOf("blocked_trackers" to 5L))
        weeks = WeeklyLedger.add(weeks, monday, mapOf("blocked_trackers" to 3L, "messages" to 1L))
        weeks = WeeklyLedger.add(weeks, monday - 7, mapOf("messages" to 2L))
        val current = weeks.single { it.week == monday }
        assertEquals(8L, current.counters["blocked_trackers"])
        assertEquals(1L, current.counters["messages"])
        assertEquals(2L, weeks.single { it.week == monday - 7 }.counters["messages"])
    }

    @Test
    fun `cles inconnues et valeurs absurdes refusees`() {
        val weeks = WeeklyLedger.add(
            emptyList(), monday,
            mapOf("exemple.com" to 1L, "wifi_Maison" to 1L, "messages" to -4L, "scam_alerts" to 0L),
        )
        assertTrue(weeks.isEmpty())
        assertTrue(WeeklyLedger.setGauge(emptyList(), monday, "nom_reseau", 3).isEmpty())
        assertTrue(WeeklyLedger.setGauge(emptyList(), monday, "risky_apps", -1).isEmpty())
        assertTrue(WeeklyLedger.recordScore(emptyList(), monday, 140).isEmpty())
    }

    @Test
    fun `score de debut garde, score de fin remplace`() {
        var weeks = WeeklyLedger.recordScore(emptyList(), monday, 52)
        weeks = WeeklyLedger.recordScore(weeks, monday, 61)
        weeks = WeeklyLedger.recordScore(weeks, monday, 74)
        val stats = weeks.single()
        assertEquals(52, stats.scoreStart)
        assertEquals(74, stats.scoreEnd)
    }

    @Test
    fun `une jauge garde la derniere valeur vue`() {
        var weeks = WeeklyLedger.setGauge(emptyList(), monday, "risky_apps", 4)
        weeks = WeeklyLedger.setGauge(weeks, monday, "risky_apps", 2)
        weeks = WeeklyLedger.setGauge(weeks, monday, "pw_weak", 0)
        assertEquals(mapOf("risky_apps" to 2, "pw_weak" to 0), weeks.single().gauges)
    }

    @Test
    fun `effacement apres 8 semaines`() {
        var weeks = emptyList<WeekStats>()
        for (i in 0..11) weeks = WeeklyLedger.add(weeks, monday - i * 7L, mapOf("messages" to 1L))
        val kept = WeeklyLedger.prune(weeks, monday)
        assertEquals(8, kept.size)
        assertEquals(monday - 49, kept.first().week) // 7 semaines avant
        assertEquals(monday, kept.last().week)
        // La semaine suivante, la plus ancienne disparaît.
        val nextWeek = WeeklyLedger.prune(kept, monday + 7)
        assertEquals(7, nextWeek.size)
        assertEquals(monday - 42, nextWeek.first().week)
    }

    @Test
    fun `semaines du futur et semaines vides effacees`() {
        val weeks = listOf(
            WeekStats(monday + 7, counters = mapOf("messages" to 1L)), // horloge avancée
            WeekStats(monday),
            WeekStats(monday - 7, counters = mapOf("messages" to 1L)),
        )
        assertEquals(listOf(monday - 7), WeeklyLedger.prune(weeks, monday).map { it.week })
    }

    @Test
    fun `aller-retour JSON sans perte, cles inconnues ignorees`() {
        var weeks = WeeklyLedger.add(emptyList(), monday, mapOf("blocked_malware" to 3L))
        weeks = WeeklyLedger.setGauge(weeks, monday, "pw_reused", 2)
        weeks = WeeklyLedger.recordScore(weeks, monday, 66)
        assertEquals(weeks, WeeklyLedger.fromJson(WeeklyLedger.toJson(weeks)))

        val forged = """[{"w":$monday,"c":{"messages":2,"site.com":9},"g":{"ssid":1}}]"""
        val read = WeeklyLedger.fromJson(forged).single()
        assertEquals(mapOf("messages" to 2L), read.counters)
        assertTrue(read.gauges.isEmpty())
        assertTrue(WeeklyLedger.fromJson("pas du json").isEmpty())
        assertTrue(WeeklyLedger.fromJson(null).isEmpty())
    }

    @Test
    fun `instantane semaine en cours et precedente`() {
        val weeks = WeeklyLedger.add(emptyList(), monday - 7, mapOf("messages" to 4L))
        val snapshot = WeeklyLedger.snapshot(weeks, monday)
        assertEquals(monday, (snapshot["current"] as Map<*, *>)["week"])
        assertEquals(mapOf("messages" to 4L), (snapshot["previous"] as Map<*, *>)["counters"])
        assertNull(WeeklyLedger.snapshot(emptyList(), monday)["previous"])
    }

    @Test
    fun `notification une fois par semaine, le lundi des 9 h`() {
        val previous = WeekStats(monday - 7, counters = mapOf("messages" to 1L))
        assertTrue(WeeklyLedger.shouldNotify(true, monday, monday - 7, 9, previous))
        assertFalse(WeeklyLedger.shouldNotify(true, monday, monday - 7, 8, previous)) // trop tôt
        assertFalse(WeeklyLedger.shouldNotify(true, monday, monday, 10, previous)) // déjà envoyée
        assertFalse(WeeklyLedger.shouldNotify(false, monday, monday - 7, 10, previous)) // option coupée
        assertFalse(WeeklyLedger.shouldNotify(true, monday, null, 10, null)) // rien à montrer
        assertFalse(WeeklyLedger.shouldNotify(true, monday, null, 10, WeekStats(monday - 7)))
    }
}
