package com.iheb.sentinel.firewall

import com.iheb.sentinel.firewall.CategoryList.Companion.toHex
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.File
import java.security.MessageDigest

/** Fusion des sources, fichiers générés et manifeste. */
class BlocklistFilesTest {

    private fun sha(text: String) =
        MessageDigest.getInstance("SHA-256").digest(text.toByteArray()).toHex()

    @Test
    fun `fusion - domaines proteges retires`() {
        val builder = CategoryBuilder(setOf("docs.google.com", "github.io", "google.com"))
        builder.add(ListEntry("docs.google.com", false)) // exact protégé
        builder.add(ListEntry("google.com", true)) // couvrirait google.com
        builder.add(ListEntry("github.io", true)) // couvrirait tout GitHub Pages
        builder.add(ListEntry("faux-site.github.io", false)) // site précis : gardé
        builder.add(ListEntry("evil.docs.google.com", false)) // nom différent : gardé
        assertEquals(listOf("evil.docs.google.com", "faux-site.github.io"), builder.buildLines())
        assertEquals(3, builder.removedProtected)
    }

    @Test
    fun `fusion - doublons et entrees deja couvertes retires`() {
        val builder = CategoryBuilder(emptySet())
        listOf(
            ListEntry("pub.net", true),
            ListEntry("a.pub.net", true), // couvert par *.pub.net
            ListEntry("b.pub.net", false), // couvert aussi
            ListEntry("pub.net", false), // couvert (le joker inclut le domaine)
            ListEntry("seul.org", false),
            ListEntry("seul.org", false), // doublon
        ).forEach(builder::add)
        assertEquals(listOf("*.pub.net", "seul.org"), builder.buildLines())
    }

    @Test
    fun `lecture d'un fichier - SHA-256 verifie`() {
        val text = "*.pub.net\na.org\nb.org\n"
        val list = CategoryList.read(text.byteInputStream(), sha(text))
        assertEquals(1, list.wildcard.size)
        assertEquals(2, list.exact.size)
        try {
            CategoryList.read(text.byteInputStream(), sha("autre chose"))
            fail("SHA-256 différent accepté")
        } catch (e: IllegalArgumentException) {
            // attendu
        }
    }

    @Test
    fun `lecture d'un fichier - mal trie, doublon ou invalide refuse`() {
        for (bad in listOf("b.org\na.org\n", "a.org\na.org\n", "a.org\npas valide\n")) {
            try {
                CategoryList.read(bad.byteInputStream(), null)
                fail("Accepté : $bad")
            } catch (e: IllegalArgumentException) {
                // attendu
            }
        }
    }

    @Test
    fun `manifeste - chemins et adresses dangereux refuses`() {
        val base = """{"formatVersion":1,"generatedAt":"2026-10-19T00:00:00Z","categories":[%s],"sources":[%s]}"""
        val cat = """{"id":"ads","file":"%s","entries":1,"sha256":"${"a".repeat(64)}"}"""
        val src = """{"id":"x","name":"x","category":"ads","format":"hosts","subdomains":false,
            "updateUrl":"%s","parsed":1,"license":"MIT","licenseUrl":"","homepage":"","attribution":""}"""
        val ok = BlocklistManifest.parse(base.format(cat.format("ads.txt"), src.format("https://a.b/c")))
        assertEquals("ads.txt", ok.categories[BlockCategory.ADS]?.file)
        for (json in listOf(
            base.format(cat.format("../../shared_prefs/x.txt"), ""),
            base.format(cat.format("ads.txt"), src.format("http://a.b/c")),
            base.format("", "").replace("\"formatVersion\":1", "\"formatVersion\":2"),
        )) {
            try {
                BlocklistManifest.parse(json)
                fail("Accepté : $json")
            } catch (e: Exception) {
                // attendu
            }
        }
    }

    /** Le manifeste livré dans l'app correspond bien aux fichiers livrés. */
    @Test
    fun `manifeste livre - SHA-256 et nombres conformes aux fichiers`() {
        val dir = assetsDir()
        val manifest = BlocklistManifest.parse(File(dir, "manifest.json").readText())
        // « Imitations de marques » est une règle : pas de fichier de liste.
        val withList = BlockCategory.entries.filter { it.hasList }
        assertEquals(withList.toSet(), manifest.categories.keys)
        assertTrue(manifest.sources.isNotEmpty())
        for (file in manifest.categories.values) {
            val list = File(dir, file.file).inputStream().use { CategoryList.read(it, file.sha256) }
            assertEquals(file.file, file.entries, list.size)
            assertTrue(file.file, list.size > 1000)
        }
        // Chaque catégorie a au moins une source, avec licence et attribution.
        for (category in withList) {
            val sources = manifest.sources.filter { it.category == category }
            assertTrue(category.id, sources.isNotEmpty())
            assertTrue(sources.all { it.license.isNotBlank() && it.attribution.isNotBlank() })
        }
    }

    @Test
    fun `listes livrees - aucun domaine protege bloque`() {
        val dir = assetsDir()
        val protected = File(dir, "protected.txt").readLines()
            .map { it.substringBefore('#').trim() }.filter { it.isNotEmpty() }
        val policy = shippedPolicy()
        for (name in protected) assertEquals(name, null, policy.check(name))
        assertFalse(protected.isEmpty())
    }

    @Test
    fun `listes livrees - infrastructure protegee, sites pieges dessus toujours bloques`() {
        val policy = shippedPolicy()
        // Faux positif constaté : cache AMP de Google, classé hameçonnage.
        assertEquals(null, policy.check("cdn.ampproject.org"))
        assertEquals(null, policy.check("bit.ly"))
        assertEquals(null, policy.check("l.instagram.com"))
        // L'hébergeur entier n'est plus bloqué (ancien « *.amplifyapp.com »)…
        assertEquals(null, policy.check("amplifyapp.com"))
        assertEquals(null, policy.check("mon-vrai-site.amplifyapp.com"))
        // … mais les sites piégés connus, eux, restent bloqués un par un.
        assertEquals(BlockCategory.MALWARE, policy.check("0utlook-owa.d1n3vfe0lukbep.amplifyapp.com"))
        assertEquals(BlockCategory.MALWARE, policy.check("0ffice-servr-0utl00k-i6tr8.firebaseapp.com"))
    }

    private fun shippedPolicy(): BlockPolicy {
        val dir = assetsDir()
        val manifest = BlocklistManifest.parse(File(dir, "manifest.json").readText())
        return BlockPolicy(
            manifest.categories.mapValues { (_, f) ->
                File(dir, f.file).inputStream().use { CategoryList.read(it, f.sha256) }
            },
            BlockCategory.entries.toSet(),
            DomainSet.EMPTY,
        )
    }

    companion object {
        /** assets/blocklists depuis le dossier du module (android/app). */
        fun assetsDir(): File {
            var dir: File? = File("").absoluteFile
            while (dir != null) {
                val candidate = File(dir, "assets/blocklists")
                if (File(candidate, "manifest.json").isFile) return candidate
                dir = dir.parentFile
            }
            throw IllegalStateException("assets/blocklists introuvable")
        }
    }
}
