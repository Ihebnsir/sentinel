package com.iheb.sentinel.firewall

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Mêmes cas que test/brand_parity_test.dart : Kotlin et Dart doivent
 * donner exactement la même réponse pour chaque domaine.
 */
class BrandParityTest {

    private val brands = BrandRules.parse(repoFile("assets/data/known_brands.json").readText())

    @Test
    fun `parite avec Dart - test fixtures brand_parity json`() {
        val cases = JSONObject(repoFile("test/fixtures/brand_parity.json").readText())
            .getJSONArray("cases")
        assertTrue(cases.length() >= 40)
        val failures = mutableListOf<String>()
        for (i in 0 until cases.length()) {
            val item = cases.getJSONObject(i)
            val host = item.getString("host")
            val expected = if (item.isNull("brand")) null else item.getString("brand")
            val actual = BrandRules.impersonatedBrand(host, brands)?.name
            if (actual != expected) failures.add("$host : attendu $expected, obtenu $actual")
        }
        assertEquals(emptyList<String>(), failures)
    }

    @Test
    fun `extensions suspectes - meme liste qu'en Dart`() {
        val tlds = JSONObject(repoFile("test/fixtures/brand_parity.json").readText())
            .getJSONArray("suspiciousTlds")
        assertEquals((0 until tlds.length()).map { tlds.getString(it) }.toSet(), BrandRules.SUSPICIOUS_TLDS)
        assertEquals(tlds.length(), BrandRules.SUSPICIOUS_TLDS.size) // aucun doublon
    }

    @Test
    fun `fichier partage - 22 marques lues`() {
        assertEquals(22, brands.size)
        assertEquals("La Poste Tunisienne", brands.first().name)
        assertEquals(listOf("poste", "laposte"), brands.first().keywords)
        assertEquals(listOf("poste.tn"), brands.first().officialDomains)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `version inconnue refusee`() {
        BrandRules.parse("""{"formatVersion": 2, "brands": []}""")
    }

    @Test
    fun `sans marques - rien n'est signale`() {
        assertNull(BrandRules.impersonatedBrand("poste-tn.xyz", emptyList()))
    }

    companion object {
        /** Fichier du dépôt, cherché depuis le dossier du module (android/app). */
        fun repoFile(path: String): File {
            var dir: File? = File("").absoluteFile
            while (dir != null) {
                val candidate = File(dir, path)
                if (candidate.isFile) return candidate
                dir = dir.parentFile
            }
            throw IllegalStateException("$path introuvable")
        }
    }
}
