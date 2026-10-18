package com.iheb.sentinel.firewall

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BlockPolicyTest {

    private fun list(vararg lines: String): CategoryList {
        val text = lines.sorted().joinToString("\n", postfix = "\n")
        return CategoryList.read(text.byteInputStream(), expectedSha256 = null)
    }

    private val malware = list("*.phishing.xyz", "faux-site.github.io")
    private val trackers = list("*.doubleclick.net", "metrics.example.com", "*.both.net")
    private val ads = list("*.ads.net", "*.both.net")
    private val lists = mapOf(
        BlockCategory.MALWARE to malware,
        BlockCategory.TRACKERS to trackers,
        BlockCategory.ADS to ads,
    )

    private fun policy(
        enabled: Set<BlockCategory> = BlockCategory.entries.toSet(),
        allow: Set<String> = emptySet(),
    ) = BlockPolicy(lists, enabled, DomainSet.of(allow))

    @Test
    fun `entree exacte - seulement ce nom`() {
        assertTrue(malware.matches("faux-site.github.io"))
        assertFalse(malware.matches("sous.faux-site.github.io"))
        assertFalse(malware.matches("github.io"))
        assertTrue(trackers.matches("metrics.example.com"))
        assertFalse(trackers.matches("example.com"))
    }

    @Test
    fun `entree joker - le domaine et tous ses sous-domaines`() {
        assertTrue(trackers.matches("doubleclick.net"))
        assertTrue(trackers.matches("ad.g.doubleclick.net"))
        assertFalse(trackers.matches("notdoubleclick.net"))
        assertFalse(trackers.matches("doubleclick.net.evil.org"))
        assertFalse(trackers.matches("net"))
    }

    @Test
    fun `chaque blocage indique sa categorie`() {
        val policy = policy()
        assertEquals(BlockCategory.MALWARE, policy.check("login.phishing.xyz"))
        assertEquals(BlockCategory.TRACKERS, policy.check("ad.doubleclick.net"))
        assertEquals(BlockCategory.ADS, policy.check("x.ads.net"))
        assertNull(policy.check("www.wikipedia.org"))
    }

    @Test
    fun `domaine dans deux categories - la prioritaire gagne`() {
        assertEquals(BlockCategory.TRACKERS, policy().check("a.both.net"))
        // Traqueurs coupés : toujours bloqué, mais au titre des publicités.
        val noTrackers = policy(enabled = setOf(BlockCategory.MALWARE, BlockCategory.ADS))
        assertEquals(BlockCategory.ADS, noTrackers.check("a.both.net"))
    }

    @Test
    fun `categorie desactivee - plus de blocage`() {
        val policy = policy(enabled = setOf(BlockCategory.MALWARE, BlockCategory.TRACKERS))
        assertNull(policy.check("x.ads.net"))
        assertEquals(BlockCategory.MALWARE, policy.check("phishing.xyz"))
        assertNull(policy(enabled = emptySet()).check("phishing.xyz"))
    }

    @Test
    fun `liste blanche prioritaire sur tout, sous-domaines compris`() {
        val policy = policy(allow = setOf("phishing.xyz", "doubleclick.net"))
        assertNull(policy.check("phishing.xyz"))
        assertNull(policy.check("login.phishing.xyz"))
        assertNull(policy.check("ad.g.doubleclick.net"))
        // Un domaine parent de l'entrée blanche reste bloqué.
        val narrow = policy(allow = setOf("ok.phishing.xyz"))
        assertNull(narrow.check("ok.phishing.xyz"))
        assertEquals(BlockCategory.MALWARE, narrow.check("ko.phishing.xyz"))
    }

    @Test
    fun `noms non normalises acceptes`() {
        assertEquals(BlockCategory.MALWARE, policy().check("LOGIN.Phishing.XYZ."))
        assertNull(policy().check(""))
    }

    @Test
    fun `domaine de test rattache au malware en debug`() {
        val debug = BlockPolicy(lists, BlockCategory.entries.toSet(), DomainSet.EMPTY, "example.com")
        assertEquals(BlockCategory.MALWARE, debug.check("www.example.com"))
        assertNull(policy().check("example.com"))
    }

    @Test
    fun `limite d'alertes - une par domaine et par heure, 10 au total`() {
        var now = 0L
        val limiter = AlertLimiter(clock = { now })
        assertTrue(limiter.tryAcquire("a.xyz"))
        assertFalse(limiter.tryAcquire("a.xyz"))
        now = 59 * 60 * 1000L
        assertFalse(limiter.tryAcquire("a.xyz"))
        now = 60 * 60 * 1000L
        assertTrue(limiter.tryAcquire("a.xyz")) // une heure plus tard

        val many = AlertLimiter(clock = { 0L })
        repeat(10) { assertTrue(many.tryAcquire("d$it.xyz")) }
        assertFalse(many.tryAcquire("d10.xyz"))
    }
}
