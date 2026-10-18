package com.iheb.sentinel.firewall

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ListParserTest {

    private fun parse(text: String, format: ListFormat, subdomains: Boolean = false) =
        ListParser.parse(text.reader().buffered(), format, subdomains)

    @Test
    fun `format hosts - IP puis un ou plusieurs noms`() {
        val result = parse(
            """
            # AdAway default blocklist
            127.0.0.1  localhost
            ::1  localhost
            127.0.0.1 analytics.163.com
            0.0.0.0 ads.example.org tracker.example.org # commentaire
            8.8.8.8 pas-un-blocage.com
            """.trimIndent(),
            ListFormat.HOSTS,
        )
        assertEquals(
            listOf(
                ListEntry("analytics.163.com", false),
                ListEntry("ads.example.org", false),
                ListEntry("tracker.example.org", false),
            ),
            result.entries,
        )
        // « localhost » n'est pas une erreur ; l'IP 8.8.8.8, si.
        assertEquals(1, result.invalidLines)
    }

    @Test
    fun `format domaines - un par ligne, jokers et sous-domaines`() {
        val text = "# titre\n\n00000.live\n*.joker.net\ndeux mots.com\n"
        val exact = parse(text, ListFormat.DOMAINS, subdomains = false)
        assertEquals(
            listOf(ListEntry("00000.live", false), ListEntry("joker.net", true)),
            exact.entries,
        )
        assertEquals(1, exact.invalidLines)
        // Liste « Wild_ » : chaque ligne couvre aussi les sous-domaines.
        val wild = parse(text, ListFormat.DOMAINS, subdomains = true)
        assertTrue(wild.entries.all { it.includeSubdomains })
    }

    @Test
    fun `format adblock - seules les regles de domaine sont gardees`() {
        val result = parse(
            """
            [Adblock Plus 2.0]
            ! Title: AdGuard CNAME
            ||a8.net^
            ||pl02.prolitteris.2cnt.net^${'$'}important
            ##.bandeau-pub
            @@||exception.com^
            ||chemin.com/pub^
            ||-invalide.com^
            """.trimIndent(),
            ListFormat.ADBLOCK,
        )
        assertEquals(
            listOf(ListEntry("a8.net", true), ListEntry("pl02.prolitteris.2cnt.net", true)),
            result.entries,
        )
        // Règles cosmétiques et exceptions : ignorées. Domaine mal formé : invalide.
        assertEquals(1, result.invalidLines)
    }

    @Test
    fun `normalisation - minuscules, point final, espaces`() {
        assertEquals("ads.example.com", DomainNames.normalize("  ADS.Example.COM. "))
    }

    @Test
    fun `punycode - les domaines accentues sont convertis`() {
        assertEquals("xn--caf-dma.fr", DomainNames.normalize("café.fr"))
        assertEquals("xn--caf-dma.fr", DomainNames.normalize("CAFÉ.FR"))
        val result = parse("0.0.0.0 bücher.de\n", ListFormat.HOSTS)
        assertEquals("xn--bcher-kva.de", result.entries.single().domain)
    }

    @Test
    fun `entrees invalides refusees`() {
        for (bad in listOf(
            "", "localhost", "com", "192.168.1.1", "-debut.com", "fin-.com", "a..b.com",
            "espace dedans.com", "a/b.com", "x".repeat(64) + ".com", "a.b.c." + "d".repeat(250),
        )) {
            assertNull(bad, DomainNames.normalize(bad))
        }
        assertTrue(DomainNames.isValidAscii("_dmarc.example.com"))
        assertTrue(DomainNames.isValidAscii("1.2.3.example"))
        assertFalse(DomainNames.isValidAscii("1.2.3.4"))
    }

    @Test
    fun `parents et neutralisation`() {
        assertEquals(listOf("a.b.c", "b.c", "c"), DomainNames.parents("a.b.c"))
        assertEquals("site[.]xyz", DomainNames.defang("site.xyz"))
    }

    @Test
    fun `taux de lignes invalides`() {
        val result = parse("ok.com\nmauvais mot\n", ListFormat.DOMAINS)
        assertEquals(0.5, result.invalidRatio, 0.0001)
    }
}
