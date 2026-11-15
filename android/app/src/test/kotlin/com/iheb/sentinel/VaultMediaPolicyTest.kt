package com.iheb.sentinel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

/** Documents du coffre : recompression, PDF, partage, manifeste. */
class VaultMediaPolicyTest {

    @Test
    fun `image legere et raisonnable gardee telle quelle`() {
        assertTrue(VaultMediaPolicy.keepsOriginal("image/jpeg", 500_000, 2000, 1500))
        assertTrue(VaultMediaPolicy.keepsOriginal("image/png", 100_000, 800, 600))
    }

    @Test
    fun `image lourde, immense ou d'un autre format recompressee`() {
        assertFalse(VaultMediaPolicy.keepsOriginal("image/jpeg", 5_000_000, 2000, 1500))
        assertFalse(VaultMediaPolicy.keepsOriginal("image/jpeg", 500_000, 4000, 3000))
        assertFalse(VaultMediaPolicy.keepsOriginal("image/heic", 500_000, 800, 600))
        assertFalse(VaultMediaPolicy.keepsOriginal(null, 500_000, 800, 600))
    }

    @Test
    fun `echantillonnage par puissances de 2, jamais sous la taille cible`() {
        assertEquals(1, VaultMediaPolicy.sampleSize(2000, 1500))
        assertEquals(1, VaultMediaPolicy.sampleSize(4000, 3000))
        assertEquals(2, VaultMediaPolicy.sampleSize(6000, 4000))
        assertEquals(4, VaultMediaPolicy.sampleSize(12000, 9000))
        for (side in listOf(3000, 6000, 12000, 20000)) {
            assertTrue(side / VaultMediaPolicy.sampleSize(side, side) >= VaultMediaPolicy.MAX_SIDE)
        }
    }

    @Test
    fun `echelle finale - plus grand cote ramene a 2560`() {
        assertEquals(1f, VaultMediaPolicy.fitScale(1000, 800))
        assertEquals(0.5f, VaultMediaPolicy.fitScale(5120, 3000))
        assertEquals(0.5f, VaultMediaPolicy.fitScale(3000, 5120))
    }

    @Test
    fun `PDF reconnu a ses premiers octets`() {
        assertTrue(VaultMediaPolicy.isPdf("%PDF-1.7\n".toByteArray()))
        assertFalse(VaultMediaPolicy.isPdf("%PD".toByteArray()))
        assertFalse(VaultMediaPolicy.isPdf(byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte())))
    }

    @Test
    fun `largeur de rendu bornee`() {
        assertEquals(200, VaultMediaPolicy.pdfWidth(0))
        assertEquals(1080, VaultMediaPolicy.pdfWidth(1080))
        assertEquals(VaultMediaPolicy.MAX_PDF_WIDTH, VaultMediaPolicy.pdfWidth(10_000))
    }

    @Test
    fun `nom de partage neutre - jamais le titre`() {
        assertEquals("sentinel-document.pdf", VaultMediaPolicy.shareName("application/pdf"))
        assertEquals("sentinel-document.jpg", VaultMediaPolicy.shareName("image/jpeg"))
        assertEquals("sentinel-document.png", VaultMediaPolicy.shareName("image/png"))
    }

    @Test
    fun `fournisseurs de la photo et du partage non exportes`() {
        val ns = "http://schemas.android.com/apk/res/android"
        val factory = DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }
        val doc = factory.newDocumentBuilder().parse(File("src/main/AndroidManifest.xml"))
        val nodes = doc.getElementsByTagName("provider")
        val providers = (0 until nodes.length).map { nodes.item(it) as Element }
        val authorities = providers.map { it.getAttributeNS(ns, "authorities") }
        assertTrue("\${applicationId}.vaultcapture" in authorities)
        assertTrue("\${applicationId}.vaultshare" in authorities)
        for (p in providers) {
            assertEquals("false", p.getAttributeNS(ns, "exported"))
            assertEquals("true", p.getAttributeNS(ns, "grantUriPermissions"))
        }
        // Aucune permission de stockage : le sélecteur d'Android suffit.
        val perms = doc.getElementsByTagName("uses-permission")
        val names = (0 until perms.length).map { (perms.item(it) as Element).getAttributeNS(ns, "name") }
        assertTrue(names.none { "STORAGE" in it || "MEDIA_IMAGES" in it })
    }

    @Test
    fun `FileProvider limite au seul dossier de la photo`() {
        val text = File("src/main/res/xml/vault_capture_paths.xml").readText()
        assertTrue("path=\"vault_capture/\"" in text)
        assertFalse("<root-path" in text || "<files-path" in text || "<external" in text)
    }
}
