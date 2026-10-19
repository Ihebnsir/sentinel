package com.iheb.sentinel.firewall

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

/** Catégorie « Imitations de marques » dans BlockPolicy. */
class ImpersonationPolicyTest {

    private val brands = BrandRules.parse(
        BrandParityTest.repoFile("assets/data/known_brands.json").readText(),
    )

    private fun list(vararg lines: String): CategoryList {
        val text = lines.sorted().joinToString("\n", postfix = "\n")
        return CategoryList.read(text.byteInputStream(), expectedSha256 = null)
    }

    private val lists = mapOf(
        BlockCategory.MALWARE to list("*.poste-colis.xyz"),
        BlockCategory.TRACKERS to list("*.biat-stats.net"),
        BlockCategory.ADS to list("*.ads.net"),
    )

    private fun policy(
        enabled: Set<BlockCategory> = BlockCategory.entries.toSet(),
        allow: Set<String> = emptySet(),
    ) = BlockPolicy(lists, enabled, DomainSet.of(allow), brands = brands)

    @Test
    fun `active par defaut, alerte comme Malware, sans liste a telecharger`() {
        val category = BlockCategory.IMPERSONATION
        assertEquals(true, category.defaultEnabled)
        assertEquals(true, category.alerts)
        assertFalse(category.hasList)
        assertEquals(category, BlockCategory.fromId("impersonation"))
    }

    @Test
    fun `domaine absent des listes qui imite une marque - bloque`() {
        assertEquals(BlockCategory.IMPERSONATION, policy().check("poste-tn.xyz"))
        assertEquals(BlockCategory.IMPERSONATION, policy().check("BIAT-Securite.com."))
        assertEquals("La Poste Tunisienne", policy().impersonatedBrand("poste-tn.xyz")?.name)
    }

    @Test
    fun `domaine officiel et domaine ordinaire - autorises`() {
        assertNull(policy().check("www.poste.tn"))
        assertNull(policy().check("ebanking.biat.com.tn"))
        assertNull(policy().check("google.com"))
    }

    @Test
    fun `meme marque dans un autre pays - autorisee, combinaisons bloquees`() {
        assertNull(policy().check("laposte.fr"))
        assertNull(policy().check("www.laposte.fr"))
        assertNull(policy().check("orange.be"))
        assertNull(policy().check("orange.com"))
        assertEquals(BlockCategory.IMPERSONATION, policy().check("laposte-tn-livraison.xyz"))
        assertEquals(BlockCategory.IMPERSONATION, policy().check("orange-recharge.top"))
        assertEquals(BlockCategory.IMPERSONATION, policy().check("biat-secure.com"))
        assertEquals(BlockCategory.IMPERSONATION, policy().check("laposte.fr.colis-suivi.xyz"))
    }

    @Test
    fun `mot-cle seul - bloque si extension suspecte ou tunisienne`() {
        assertEquals(BlockCategory.IMPERSONATION, policy().check("biat.xyz"))
        assertEquals(BlockCategory.IMPERSONATION, policy().check("cnam.tn"))
        assertEquals(BlockCategory.IMPERSONATION, policy().check("laposte.com.tn"))
        assertNull(policy().check("cnam.nat.tn")) // le vrai site
    }

    @Test
    fun `mot-cle long au milieu d'un autre mot - autorise`() {
        assertNull(policy().check("imposter.com"))
        assertEquals(BlockCategory.IMPERSONATION, policy().check("monlaposte.com"))
    }

    @Test
    fun `les listes passent avant l'imitation`() {
        assertEquals(BlockCategory.MALWARE, policy().check("a.poste-colis.xyz"))
        assertEquals(BlockCategory.TRACKERS, policy().check("x.biat-stats.net"))
    }

    @Test
    fun `liste blanche prioritaire sur l'imitation`() {
        val allow = policy(allow = setOf("poste-tn.xyz", "laposte-colis.fr"))
        assertNull(allow.check("poste-tn.xyz"))
        assertNull(allow.check("www.laposte-colis.fr")) // sous-domaine aussi
        assertEquals(BlockCategory.IMPERSONATION, allow.check("poste-tn.top"))
    }

    @Test
    fun `categorie coupee - plus de blocage mais toujours classee pour le rapport`() {
        val off = policy(enabled = BlockCategory.entries.toSet() - BlockCategory.IMPERSONATION)
        assertNull(off.check("poste-tn.xyz"))
        assertEquals(BlockCategory.IMPERSONATION, off.classify("poste-tn.xyz"))
    }

    @Test
    fun `classify ignore les reglages - categories coupees et liste blanche`() {
        val p = policy(enabled = emptySet(), allow = setOf("ads.net"))
        assertEquals(BlockCategory.ADS, p.classify("pub.ads.net"))
        assertEquals(BlockCategory.MALWARE, p.classify("a.poste-colis.xyz"))
        assertNull(p.classify("google.com"))
        assertNull(p.check("pub.ads.net"))
    }

    @Test
    fun `sans marques chargees - aucune imitation`() {
        val p = BlockPolicy(lists, BlockCategory.entries.toSet(), DomainSet.EMPTY)
        assertNull(p.check("poste-tn.xyz"))
    }
}
