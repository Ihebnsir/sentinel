package com.iheb.sentinel.firewall

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException
import java.io.InputStream

class BlocklistUpdaterTest {

    @get:Rule
    val temp = TemporaryFolder()

    private fun source(id: String, category: BlockCategory, format: ListFormat, parsed: Int) =
        BlocklistSource(
            id = id, name = id, category = category, format = format, subdomains = false,
            updateUrl = "https://exemple.test/$id", parsed = parsed, license = "MIT",
            licenseUrl = "", homepage = "", attribution = "",
        )

    private val bundled = BlocklistManifest(
        generatedAt = 1000L,
        categories = emptyMap(),
        sources = listOf(
            source("hosts", BlockCategory.ADS, ListFormat.HOSTS, parsed = 4),
            source("adblock", BlockCategory.TRACKERS, ListFormat.ADBLOCK, parsed = 2),
        ),
    )

    private class FakeFetcher(val bodies: MutableMap<String, String>) : Fetcher {
        override fun open(url: String): InputStream =
            bodies[url]?.byteInputStream() ?: throw IOException("réseau absent")
    }

    private val goodBodies = mapOf(
        "https://exemple.test/hosts" to
            "127.0.0.1 localhost\n0.0.0.0 a.pub.net\n0.0.0.0 b.pub.net\n0.0.0.0 c.pub.net\n" +
            "0.0.0.0 docs.google.com\n",
        "https://exemple.test/adblock" to "! titre\n||trk.net^\n||autre.net^\n",
    )

    private fun updater(dir: File, fetcher: Fetcher, now: Long = 5000L) =
        BlocklistUpdater(dir, bundled, setOf("docs.google.com"), fetcher, clock = { now })

    private fun loadCategory(dir: File, manifest: BlocklistManifest, category: BlockCategory): CategoryList {
        val file = manifest.categories.getValue(category)
        return File(dir, file.file).inputStream().use { CategoryList.read(it, file.sha256) }
    }

    @Test
    fun `mise a jour reussie - fichiers et manifeste coherents`() {
        val dir = temp.newFolder()
        val result = updater(dir, FakeFetcher(goodBodies.toMutableMap()))
            .update(setOf(BlockCategory.ADS, BlockCategory.TRACKERS))
        assertTrue(result.success)

        val manifest = updater(dir, FakeFetcher(mutableMapOf())).readLocalManifest()!!
        assertEquals(5000L, manifest.generatedAt)
        val ads = loadCategory(dir, manifest, BlockCategory.ADS)
        assertEquals(3, ads.size) // docs.google.com (protégé) retiré
        assertFalse(ads.matches("docs.google.com"))
        assertTrue(loadCategory(dir, manifest, BlockCategory.TRACKERS).matches("x.trk.net"))
        // Pas de fichier temporaire oublié.
        assertTrue(dir.listFiles()!!.none { it.name.endsWith(".tmp") })
    }

    @Test
    fun `echec - l'ancienne version est gardee`() {
        val dir = temp.newFolder()
        updater(dir, FakeFetcher(goodBodies.toMutableMap()), now = 5000L)
            .update(setOf(BlockCategory.ADS))
        val before = updater(dir, FakeFetcher(mutableMapOf())).readLocalManifest()!!

        // Réseau coupé : rien ne change.
        val offline = updater(dir, FakeFetcher(mutableMapOf()), now = 9000L)
            .update(setOf(BlockCategory.ADS))
        assertFalse(offline.success)
        assertEquals(setOf(BlockCategory.ADS), offline.failed)
        val after = updater(dir, FakeFetcher(mutableMapOf())).readLocalManifest()!!
        assertEquals(before.generatedAt, after.generatedAt)
        assertEquals(3, loadCategory(dir, after, BlockCategory.ADS).size)
    }

    @Test
    fun `liste videe ou tronquee refusee`() {
        val dir = temp.newFolder()
        val bodies = goodBodies.toMutableMap()
        bodies["https://exemple.test/hosts"] = "0.0.0.0 seul.net\n" // 1 au lieu de 4
        val result = updater(dir, FakeFetcher(bodies)).update(setOf(BlockCategory.ADS))
        assertFalse(result.success)
        assertEquals(null, updater(dir, FakeFetcher(mutableMapOf())).readLocalManifest())
    }

    @Test
    fun `format inattendu refuse - trop de lignes invalides`() {
        val dir = temp.newFolder()
        val bodies = goodBodies.toMutableMap()
        // Une page HTML à la place de la liste.
        bodies["https://exemple.test/hosts"] =
            "<html>\n<body>\n0.0.0.0 a.net\n0.0.0.0 b.net\n0.0.0.0 c.net\n<p>erreur</p>\n</html>\n"
        assertFalse(updater(dir, FakeFetcher(bodies)).update(setOf(BlockCategory.ADS)).success)
    }

    @Test
    fun `une categorie en echec n'empeche pas les autres`() {
        val dir = temp.newFolder()
        val bodies = goodBodies.toMutableMap()
        bodies.remove("https://exemple.test/adblock")
        val result = updater(dir, FakeFetcher(bodies))
            .update(setOf(BlockCategory.ADS, BlockCategory.TRACKERS))
        assertEquals(setOf(BlockCategory.ADS), result.updated)
        assertEquals(setOf(BlockCategory.TRACKERS), result.failed)
        val manifest = updater(dir, FakeFetcher(mutableMapOf())).readLocalManifest()!!
        assertEquals(setOf(BlockCategory.ADS), manifest.categories.keys)
    }

    @Test
    fun `taille maximale - lecture interrompue`() {
        val limited = LimitedInputStream(ByteArray(100).inputStream(), max = 50)
        try {
            limited.readBytes()
            throw AssertionError("Taille dépassée acceptée")
        } catch (e: IOException) {
            // attendu
        }
    }

    @Test
    fun `coherence - bornes`() {
        assertTrue(BlocklistUpdater.isConsistent(100, 5, 120))
        assertFalse(BlocklistUpdater.isConsistent(0, 0, 120)) // vide
        assertFalse(BlocklistUpdater.isConsistent(50, 0, 120)) // moins de la moitié
        assertFalse(BlocklistUpdater.isConsistent(700, 0, 120)) // plus de 5 fois
        assertFalse(BlocklistUpdater.isConsistent(100, 20, 120)) // 17 % invalides
    }
}
