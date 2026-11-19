package com.iheb.sentinel.firewall

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Onglet Liens : liste Malware et liste blanche, sans VPN. */
class LinkLookupTest {

    private fun list(vararg lines: String): CategoryList {
        val text = lines.sorted().joinToString("\n", postfix = "\n")
        return CategoryList.read(text.byteInputStream(), expectedSha256 = null)
    }

    private val malware = list("*.phishing.xyz", "biat-securite.top")

    private fun check(raw: String, allow: Set<String> = emptySet(), test: String? = null) =
        LinkLookup.check(raw, DomainSet.of(allow), malware, test)

    @Test
    fun `domaine de la liste Malware - dangereux`() {
        val c = check("biat-securite.top")!!
        assertTrue(c.dangerous)
        assertFalse(c.allowed)
        assertTrue(check("login.phishing.xyz")!!.dangerous) // sous-domaine d'un joker
    }

    @Test
    fun `vrai site tunisien - rien`() {
        val c = check("www.biat.com.tn")!!
        assertFalse(c.dangerous)
        assertFalse(c.allowed)
        assertEquals("www.biat.com.tn", c.domain)
    }

    @Test
    fun `liste blanche - passe avant la liste Malware, sous-domaines compris`() {
        val c = check("a.phishing.xyz", allow = setOf("phishing.xyz"))!!
        assertTrue(c.allowed)
        assertFalse(c.dangerous)
    }

    @Test
    fun `normalisation - majuscules, point final, accents`() {
        assertEquals("biat-securite.top", check("BIAT-Securite.TOP.")!!.domain)
        assertEquals("xn--caf-dma.tn", check("café.tn")!!.domain)
    }

    @Test
    fun `adresse IP ou texte - null`() {
        assertNull(check("192.168.1.10"))
        assertNull(check("bonjour"))
        assertNull(check(""))
    }

    @Test
    fun `domaine de test du build debug`() {
        assertTrue(check("example.com", test = "example.com")!!.dangerous)
        assertFalse(check("example.com")!!.dangerous)
    }
}
