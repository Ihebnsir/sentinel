package com.iheb.sentinel.firewall

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Analyse d'une application : session, enregistrement, VPN, rapport. */
class AppAnalysisTest {

    /** Note chaque appel au lieu de construire un vrai VPN. */
    private class FakeBuilder : TunBuilder {
        val routes = mutableListOf<String>()
        val dns = mutableListOf<String>()
        val addresses = mutableListOf<String>()
        val allowedApps = mutableListOf<String>()

        override fun addAddress(address: String, prefixLength: Int) {
            addresses.add("$address/$prefixLength")
        }

        override fun addRoute(address: String, prefixLength: Int) {
            routes.add("$address/$prefixLength")
        }

        override fun addDnsServer(address: String) {
            dns.add(address)
        }

        override fun addAllowedApplication(packageName: String) {
            allowedApps.add(packageName)
        }
    }

    private fun build(plan: TunPlan) = FakeBuilder().also(plan::applyTo)

    private val dnsOnly = listOf("10.111.222.2/32", "fdc5:3a71:9e04::2/128")

    @Test
    fun `VPN normal - toutes les apps, seul le DNS virtuel est route`() {
        val builder = build(TunPlan.forAnalysis(null))
        assertEquals(TunPlan.NORMAL, TunPlan.forAnalysis(null))
        assertEquals(dnsOnly, builder.routes)
        assertEquals(listOf("10.111.222.2", "fdc5:3a71:9e04::2"), builder.dns)
        assertTrue(builder.allowedApps.isEmpty())
    }

    @Test
    fun `VPN d'analyse - une seule app autorisee, toujours seulement le DNS`() {
        val session = AnalysisSession("com.zhiliaoapp.musically", "TikTok", 0L, 5)
        val builder = build(TunPlan.forAnalysis(session))
        assertEquals(listOf("com.zhiliaoapp.musically"), builder.allowedApps)
        assertEquals(dnsOnly, builder.routes)
        assertEquals(build(TunPlan.NORMAL).addresses, builder.addresses)
    }

    @Test
    fun `fin d'analyse - retour au VPN normal`() {
        val session = AnalysisSession("com.exemple", "Exemple", 0L, 2)
        val during = TunPlan.forAnalysis(session)
        val after = TunPlan.forAnalysis(null) // session terminée
        assertEquals("com.exemple", during.allowedPackage)
        assertEquals(TunPlan.NORMAL, after)
        assertTrue(build(after).allowedApps.isEmpty())
    }

    @Test
    fun `durees proposees - 2, 5 ou 15 minutes`() {
        assertEquals(setOf(2, 5, 15), AnalysisSession.ALLOWED_MINUTES)
        assertEquals(1_000L + 15 * 60_000L, AnalysisSession("a.b", "A", 1_000L, 15).endsAt)
        for (refused in listOf(0, 1, 3, 60, -5)) {
            try {
                AnalysisSession("a.b", "A", 0L, refused)
                throw AssertionError("$refused minutes accepté")
            } catch (e: IllegalArgumentException) {
                // attendu
            }
        }
    }

    @Test
    fun `fin d'analyse mesuree en temps ecoule, veille comprise`() {
        // Début à 1 000 s de elapsedRealtime ; l'heure du téléphone ne compte pas.
        val session = AnalysisSession("a.b", "A", startedAt = 0L, minutes = 2, startedElapsed = 1_000_000L)
        assertFalse(session.isOver(1_000_000L))
        assertFalse(session.isOver(1_000_000L + 119_999L))
        assertTrue(session.isOver(1_000_000L + 120_000L))
        assertTrue(session.isOver(1_000_000L + 80 * 60_000L)) // réveil après une longue veille
    }

    @Test
    fun `reveil de fin - en temps ecoule, independant de l'heure du telephone`() {
        // Même début en elapsedRealtime, heures du téléphone très différentes.
        val a = AnalysisSession("a.b", "A", startedAt = 0L, minutes = 15, startedElapsed = 5_000L)
        val b = AnalysisSession("a.b", "A", startedAt = 9_999_999L, minutes = 15, startedElapsed = 5_000L)
        assertEquals(5_000L + 15 * 60_000L, a.endsAtElapsed)
        assertEquals(a.endsAtElapsed, b.endsAtElapsed)
        // L'alarme sonne à endsAtElapsed : l'analyse est alors bien finie.
        assertTrue(a.isOver(a.endsAtElapsed))
        assertFalse(a.isOver(a.endsAtElapsed - 1))
    }

    @Test
    fun `reveil de fin - exact sauf si Android 12+ l'interdit`() {
        assertEquals(AlarmMode.EXACT, AnalysisAlarm.mode(sdkInt = 30, canScheduleExact = false))
        assertEquals(AlarmMode.EXACT, AnalysisAlarm.mode(sdkInt = 33, canScheduleExact = true))
        assertEquals(AlarmMode.INEXACT, AnalysisAlarm.mode(sdkInt = 34, canScheduleExact = false))
    }

    @Test
    fun `enregistrement - compte par domaine, bloque si au moins une fois`() {
        val recorder = DomainRecorder()
        recorder.record("cdn.exemple.com", null, false)
        recorder.record("t.traqueur.net", BlockCategory.TRACKERS, true)
        recorder.record("cdn.exemple.com", null, false)
        recorder.record("t.traqueur.net", BlockCategory.TRACKERS, false)
        recorder.record("t.traqueur.net", BlockCategory.TRACKERS, true)
        val snapshot = recorder.snapshot()
        assertEquals(listOf("t.traqueur.net", "cdn.exemple.com"), snapshot.map { it.name })
        assertEquals(listOf(3, 2), snapshot.map { it.count })
        assertTrue(snapshot[0].blocked)
        assertFalse(snapshot[1].blocked)
        assertEquals(2, recorder.size)
    }

    @Test
    fun `enregistrement - plafond de domaines differents`() {
        val recorder = DomainRecorder(maxDomains = 2)
        recorder.record("a.com", null, false)
        recorder.record("b.com", null, false)
        recorder.record("c.com", null, false) // ignoré
        recorder.record("a.com", null, false) // déjà connu : compté
        assertEquals(2, recorder.size)
        assertTrue(recorder.truncated)
        assertEquals(2, recorder.snapshot().first { it.name == "a.com" }.count)
    }

    @Test
    fun `rapport JSON - champs lus par Dart`() {
        val session = AnalysisSession("com.exemple", "Exemple", 1_000L, 2)
        session.recorder.record("poste-tn.xyz", BlockCategory.IMPERSONATION, true)
        session.recorder.record("cdn.exemple.com", null, false)
        val json = JSONObject(
            AppReport.toJson(session, 61_000L, session.recorder.snapshot(), false) { name ->
                if (name == "poste-tn.xyz") "La Poste Tunisienne" else null
            },
        )
        assertEquals(1, json.getInt("formatVersion"))
        assertEquals("1000", json.getString("id"))
        assertEquals("Exemple", json.getString("appLabel"))
        assertEquals(2, json.getInt("plannedMinutes"))
        assertTrue(json.getBoolean("stoppedEarly")) // 1 min sur 2
        val domains = json.getJSONArray("domains")
        val first = domains.getJSONObject(0)
        assertEquals("cdn.exemple.com", first.getString("name")) // ordre alphabétique à égalité
        assertEquals("other", first.getString("category"))
        assertFalse(first.has("brand"))
        val second = domains.getJSONObject(1)
        assertEquals("impersonation", second.getString("category"))
        assertEquals("La Poste Tunisienne", second.getString("brand"))
        assertTrue(second.getBoolean("blocked"))
    }

    @Test
    fun `rapport JSON - analyse menee jusqu'au bout`() {
        val session = AnalysisSession("com.exemple", "Exemple", 0L, 2)
        val json = JSONObject(AppReport.toJson(session, 120_000L, emptyList(), true) { null })
        assertFalse(json.getBoolean("stoppedEarly"))
        assertTrue(json.getBoolean("truncated"))
        assertEquals(0, json.getJSONArray("domains").length())
    }
}
