package com.iheb.sentinel.firewall

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import javax.crypto.KeyGenerator

/** Rapports d'analyse : stockage privé chiffré, suppression après 24 h (SEN-14). */
class AppReportStoreTest {

    @get:Rule
    val folder = TemporaryFolder()

    private val hour = 60 * 60 * 1000L
    private var now = 100 * hour

    // Vrai AES-256-GCM (JVM) ; dans l'app, la clé vient du Keystore Android.
    private val key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
    private val cipher = AesGcmReportCipher { key }

    private fun store(dir: File = File(folder.root, "app_reports")) = AppReportStore(dir, cipher) { now }

    @Test
    fun `rapport visible pendant 24 h puis supprime`() {
        val store = store()
        store.save("1", now, """{"id":"1"}""")
        now += 23 * hour
        assertEquals(listOf("""{"id":"1"}"""), store.list())
        now += hour // 24 h pile
        assertEquals(emptyList<String>(), store.list())
        assertEquals(0, folder.root.resolve("app_reports").listFiles()!!.size) // fichier effacé
    }

    @Test
    fun `isExpired - limites`() {
        val end = 10 * hour
        assertFalse(AppReportStore.isExpired(end, end))
        assertFalse(AppReportStore.isExpired(end, end + 24 * hour - 1))
        assertTrue(AppReportStore.isExpired(end, end + 24 * hour))
        assertTrue(AppReportStore.isExpired(end, end - 25 * hour)) // horloge reculée
    }

    @Test
    fun `plus recents d'abord, suppression a la demande`() {
        val store = store()
        store.save("1", now, "un")
        store.save("2", now + 1, "deux")
        assertEquals(listOf("deux", "un"), store.list())
        store.delete("1")
        assertEquals(listOf("deux"), store.list())
    }

    @Test
    fun `identifiant refuse - pas de chemin`() {
        val store = store()
        store.save("1", now, "un")
        store.delete("../1")
        store.delete("1/../..")
        assertEquals(listOf("un"), store.list())
        try {
            store.save("../x", now, "piège")
            throw AssertionError("identifiant accepté")
        } catch (e: IllegalArgumentException) {
            // attendu
        }
    }

    @Test
    fun `au plus 10 rapports`() {
        val store = store()
        for (i in 1..12) store.save("$i", now + i, "r$i")
        val all = store.list()
        assertEquals(AppReportStore.MAX_REPORTS, all.size)
        assertEquals("r12", all.first())
        assertEquals("r3", all.last())
    }

    @Test
    fun `prochaine expiration et fichiers inconnus`() {
        val dir = File(folder.root, "app_reports")
        val store = store(dir)
        assertNull(store.nextExpiry())
        store.save("1", now, "un")
        store.save("2", now - hour, "deux")
        assertEquals(now - hour + 24 * hour, store.nextExpiry())
        File(dir, "intrus.txt").writeText("x")
        store.purgeExpired()
        assertFalse(File(dir, "intrus.txt").exists())
        assertEquals(2, store.list().size)
    }

    @Test
    fun `chiffre sur le disque - aucun domaine en clair`() {
        val dir = File(folder.root, "app_reports")
        store(dir).save("1", now, """{"domains":["domaine-secret.example"]}""")
        val bytes = dir.listFiles()!!.single().readBytes()
        assertFalse(String(bytes, Charsets.ISO_8859_1).contains("domaine-secret"))
        assertEquals(1.toByte(), bytes[0]) // version du format
    }

    @Test
    fun `fichier modifie - refuse et supprime`() {
        val dir = File(folder.root, "app_reports")
        val store = store(dir)
        store.save("1", now, "un")
        val file = dir.listFiles()!!.single()
        val bytes = file.readBytes()
        bytes[bytes.size - 1] = (bytes[bytes.size - 1].toInt() xor 1).toByte()
        file.writeBytes(bytes)
        assertEquals(emptyList<String>(), store.list())
        assertFalse(file.exists())
    }

    @Test
    fun `fichier renomme pour repousser l'expiration - refuse`() {
        val dir = File(folder.root, "app_reports")
        val store = store(dir)
        store.save("1", now, "un")
        val file = dir.listFiles()!!.single()
        assertTrue(file.renameTo(File(dir, "${now + 20 * hour}-1.json")))
        now += 23 * hour
        assertEquals(emptyList<String>(), store.list())
    }

    @Test
    fun `ancien rapport en clair (version precedente) - supprime`() {
        val dir = File(folder.root, "app_reports").apply { mkdirs() }
        val old = File(dir, "$now-1.json").apply { writeText("""{"id":"1"}""") }
        assertEquals(emptyList<String>(), store(dir).list())
        assertFalse(old.exists())
    }

    @Test
    fun `jamais relu apres 24 h, meme sans passage du nettoyage`() {
        val dir = File(folder.root, "app_reports")
        val store = store(dir)
        store.save("1", now, "un")
        now += 24 * hour + 1
        // Pas de purgeExpired() ni d'alarme : la lecture seule suffit.
        assertEquals(emptyList<String>(), store.list())
        assertEquals(0, dir.listFiles()!!.size)
    }

    @Test
    fun `cles differentes - illisible`() {
        val dir = File(folder.root, "app_reports")
        store(dir).save("1", now, "un")
        val otherKey = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
        val other = AppReportStore(dir, AesGcmReportCipher { otherKey }) { now }
        assertEquals(emptyList<String>(), other.list())
    }
}
