package com.iheb.sentinel.firewall

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File
import kotlin.random.Random

class DomainSetTest {

    @Test
    fun `recherche exacte et a partir d'un indice`() {
        val set = DomainSet.of(listOf("b.org", "a.com", "c.net", "a.com"))
        assertEquals(3, set.size)
        assertTrue(set.contains("a.com"))
        assertTrue(set.contains("www.a.com", start = 4))
        assertFalse(set.contains("a.co"))
        assertFalse(set.contains("a.comm"))
        assertFalse(DomainSet.EMPTY.contains("a.com"))
    }

    /** Une liste réaliste : la vraie liste « Malware » livrée dans l'app. */
    private fun realList(): CategoryList {
        val dir = BlocklistFilesTest.assetsDir()
        val manifest = BlocklistManifest.parse(File(dir, "manifest.json").readText())
        val file = manifest.categories.getValue(BlockCategory.MALWARE)
        return File(dir, file.file).inputStream().use { CategoryList.read(it, file.sha256) }
    }

    private fun queries(list: File, count: Int): List<String> {
        // « *.x » → « www.x » (sous-domaine) ; entrée exacte → elle-même.
        val names = list.readLines().map { if (it.startsWith("*.")) "www." + it.substring(2) else it }
        val random = Random(42)
        // Moitié de noms bloqués, moitié inconnus.
        return List(count) { i ->
            if (i % 2 == 0) names[random.nextInt(names.size)]
            else "site${random.nextInt()}.exemple-inconnu.com"
        }
    }

    @Test
    fun `performance - recherche rapide sur une grande liste`() {
        val list = realList()
        assertTrue(list.size > 100_000)
        val dir = BlocklistFilesTest.assetsDir()
        val names = queries(File(dir, "malware.txt"), 200_000)
        repeat(2) { names.forEach(list::matches) } // échauffement de la JVM
        val start = System.nanoTime()
        var hits = 0
        for (name in names) if (list.matches(name)) hits++
        val micros = (System.nanoTime() - start) / 1000.0 / names.size
        assertTrue("trop peu de correspondances : $hits", hits > 50_000)
        // Large marge : quelques microsecondes en pratique, contre des
        // dizaines de millisecondes pour une requête DNS réseau.
        assertTrue("recherche trop lente : $micros µs", micros < 50)
        // Mémoire : environ 30 octets par entrée.
        assertTrue(list.memoryBytes < list.size * 40L)
    }

    /**
     * Mesure comparative HashSet / tableau trié (chiffres de
     * docs/ARCHITECTURE.md). Lancée seulement à la demande :
     * SENTINEL_BENCH=1 ./gradlew testDebugUnitTest --tests '*DomainSetTest*' -i
     */
    @Test
    fun benchmark() {
        assumeTrue(System.getenv("SENTINEL_BENCH") != null)
        val dir = BlocklistFilesTest.assetsDir()
        val file = File(dir, "malware.txt")
        val lines = file.readLines()
        val names = queries(file, 500_000)
        val runtime = Runtime.getRuntime()

        fun used(): Long {
            repeat(3) { System.gc(); Thread.sleep(100) }
            return runtime.totalMemory() - runtime.freeMemory()
        }

        fun time(label: String, lookup: (String) -> Boolean) {
            repeat(3) { names.forEach { lookup(it) } }
            val start = System.nanoTime()
            names.forEach { lookup(it) }
            val ns = (System.nanoTime() - start) / names.size
            println("$label : $ns ns par recherche (sous-domaines compris)")
        }

        var before = used()
        val start = System.nanoTime()
        val hash = HashSet<String>(lines.size * 2)
        lines.forEach { hash.add(String(it.toCharArray())) }
        println("HashSet : construit en ${(System.nanoTime() - start) / 1_000_000} ms, " +
            "${(used() - before) / lines.size} octets/entrée (mesuré)")
        time("HashSet") { name ->
            name in hash || DomainNames.parents(name).any { "*.$it" in hash }
        }
        hash.clear()

        before = used()
        val t0 = System.nanoTime()
        val compact = file.inputStream().use { CategoryList.read(it, null) }
        println("Tableau trié : lu et construit en ${(System.nanoTime() - t0) / 1_000_000} ms, " +
            "${(used() - before) / lines.size} octets/entrée (mesuré), " +
            "${compact.memoryBytes / lines.size} octets/entrée (calculé)")
        time("Tableau trié", compact::matches)
        println("Entrées : ${lines.size}, fichier : ${file.length() / 1024} Kio")
    }
}
