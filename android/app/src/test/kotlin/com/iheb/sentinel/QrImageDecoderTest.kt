package com.iheb.sentinel

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** QR codes lus dans des images PNG (voir QrFixtures), sans téléphone. */
class QrImageDecoderTest {

    // Comme QrImageReader : image réduite (inSampleSize) avant décodage.
    private fun decodeFixture(name: String): List<String> {
        val file = File(QrFixtures.dir, name)
        assertTrue("fixture absente : $file", file.isFile)
        var image = Png.read(file)
        val sample = QrImageDecoder.sampleSize(image.width, image.height)
        if (sample > 1) image = image.downsample(sample)
        assertTrue(maxOf(image.width, image.height) <= QrImageDecoder.MAX_SIDE)
        return QrImageDecoder.decode(image.pixels, image.width, image.height)
    }

    @Test
    fun `QR simple`() {
        assertEquals(listOf(QrFixtures.WA_ME), decodeFixture("wa_me.png"))
    }

    @Test
    fun `capture d'ecran d'une discussion`() {
        assertEquals(listOf(QrFixtures.VCARD), decodeFixture("screenshot_chat.png"))
    }

    @Test
    fun `deux QR codes dans l'image - les deux sont listes`() {
        val codes = decodeFixture("two_codes.png")
        assertEquals(setOf(QrFixtures.TELEGRAM, QrFixtures.WIFI), codes.toSet())
        assertEquals(2, codes.size)
    }

    @Test
    fun `texte arabe en UTF-8`() {
        assertEquals(listOf(QrFixtures.ARABIC), decodeFixture("arabic.png"))
    }

    @Test
    fun `QR clair sur fond sombre`() {
        assertEquals(listOf(QrFixtures.MARKET), decodeFixture("inverted.png"))
    }

    @Test
    fun `QR penche`() {
        assertEquals(listOf(QrFixtures.APK), decodeFixture("rotated.png"))
    }

    @Test
    fun `grande photo reduite avant lecture`() {
        assertEquals(2, QrImageDecoder.sampleSize(4000, 3000))
        assertEquals(listOf(QrFixtures.WA_ME), decodeFixture("large_photo.png"))
    }

    @Test
    fun `aucun QR code - liste vide`() {
        assertTrue(decodeFixture("no_qr.png").isEmpty())
    }

    @Test
    fun `dimensions impossibles - liste vide, sans erreur`() {
        assertTrue(QrImageDecoder.decode(IntArray(0), 0, 0).isEmpty())
        assertTrue(QrImageDecoder.decode(IntArray(10), 100, 100).isEmpty())
        assertTrue(QrImageDecoder.decode(IntArray(100) { -1 }, 10, 10).isEmpty())
    }

    @Test
    fun `reduction - jamais plus grande que la limite`() {
        assertEquals(1, QrImageDecoder.sampleSize(1080, 1920))
        assertEquals(2, QrImageDecoder.sampleSize(3000, 4000))
        assertEquals(8, QrImageDecoder.sampleSize(12000, 9000))
        assertEquals(1, QrImageDecoder.sampleSize(4000, 3000, maxSide = 4000))
    }

    @Test
    fun `QR Wi-Fi cree puis relu, nom arabe compris`() {
        val text = "WIFI:T:WPA;S:بيت العائلة;P:mot\\;de\\:passe;;"
        val matrix = QrImageDecoder.encode(text)
        assertNotNull(matrix)
        assertEquals(matrix!!.size * matrix.size, matrix.modules.size)
        val image = QrFixtures.qr(text, 6)
        assertEquals(listOf(text), QrImageDecoder.decode(image.pixels, image.width, image.height))
    }

    @Test
    fun `creation refusee - vide ou trop long`() {
        assertNull(QrImageDecoder.encode(""))
        assertNull(QrImageDecoder.encode("x".repeat(QrImageDecoder.MAX_ENCODE_LENGTH + 1)))
    }

    @Test
    fun `image partagee - content seulement, jamais un fichier de Sentinel`() {
        val own = "com.iheb.sentinel"
        assertTrue(QrImageDecoder.isAcceptableUri("content", "media", own))
        assertTrue(QrImageDecoder.isAcceptableUri("content", "com.whatsapp.provider.media", own))
        assertTrue(QrImageDecoder.isAcceptableUri("CONTENT", "com.android.providers.media.documents", own))
        assertFalse(QrImageDecoder.isAcceptableUri("file", "", own))
        assertFalse(QrImageDecoder.isAcceptableUri("file", null, own))
        assertFalse(QrImageDecoder.isAcceptableUri("http", "exemple.tn", own))
        assertFalse(QrImageDecoder.isAcceptableUri("content", null, own))
        assertFalse(QrImageDecoder.isAcceptableUri("content", "com.iheb.sentinel.vaultshare", own))
        assertFalse(QrImageDecoder.isAcceptableUri("content", "com.iheb.sentinel.vaultcapture", own))
        assertFalse(QrImageDecoder.isAcceptableUri("content", "com.iheb.sentinel", own))
        assertFalse(QrImageDecoder.isAcceptableUri("content", "media;com.iheb.sentinel.vaultshare", own))
    }
}
