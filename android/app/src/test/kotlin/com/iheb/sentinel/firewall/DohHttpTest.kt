package com.iheb.sentinel.firewall

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException

/** SEN-10 : HTTP/2 minimal de DNS-over-HTTPS (Quad9 refuse HTTP/1.1). */
class DohHttpTest {

    // Trame HTTP/2 : longueur (3 o), type, drapeaux, flux (4 o), contenu.
    private fun frame(type: Int, flags: Int, stream: Int, payload: ByteArray = byteArrayOf()) =
        byteArrayOf(
            (payload.size ushr 16).toByte(), (payload.size ushr 8).toByte(), payload.size.toByte(),
            type.toByte(), flags.toByte(), 0, 0, 0, stream.toByte(),
        ) + payload

    private val dns = byteArrayOf(0x42, 0x42, 1, 0)

    private fun read(vararg frames: ByteArray, sent: ByteArrayOutputStream = ByteArrayOutputStream()) =
        DohHttp.readResponse(ByteArrayInputStream(frames.reduce { a, b -> a + b }), sent, 1)

    @Test
    fun `preface puis SETTINGS vide`() {
        val preface = DohHttp.connectionPreface()
        assertTrue(String(preface, Charsets.US_ASCII).startsWith("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"))
        assertArrayEquals(frame(4, 0, 0), preface.copyOfRange(24, preface.size))
    }

    @Test
    fun `requete - HEADERS puis DATA avec fin de flux, sans Huffman`() {
        val bytes = DohHttp.request(dns, streamId = 3)
        assertEquals(1, bytes[3].toInt()) // HEADERS
        assertEquals(0x4, bytes[4].toInt()) // END_HEADERS
        assertEquals(3, bytes[8].toInt()) // flux 3
        val headersLength = ((bytes[1].toInt() and 0xFF) shl 8) or (bytes[2].toInt() and 0xFF)
        val block = String(bytes, 9, headersLength, Charsets.ISO_8859_1)
        assertEquals(0x83, bytes[9].toInt() and 0xFF) // :method POST
        assertEquals(0x87, bytes[10].toInt() and 0xFF) // :scheme https
        assertTrue(block.contains("/dns-query"))
        assertTrue(block.contains("dns.quad9.net"))
        assertTrue(block.contains("application/dns-message"))
        val data = bytes.copyOfRange(9 + headersLength, bytes.size)
        assertArrayEquals(frame(0, 0x1, 3, dns), data) // DATA, END_STREAM
    }

    @Test
    fun `reponse 200 - corps, et ACK aux SETTINGS et PING du serveur`() {
        val sent = ByteArrayOutputStream()
        val ping = byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8)
        val body = read(
            frame(4, 0, 0, ByteArray(6)), // SETTINGS du serveur
            frame(4, 1, 0), // ACK de nos SETTINGS
            frame(6, 0, 0, ping), // PING
            frame(1, 0x4, 1, byteArrayOf(0x88.toByte())), // :status 200 (index 8)
            frame(0, 0, 1, byteArrayOf(9, 8)),
            frame(0, 0x1, 1, byteArrayOf(7)), // fin du flux
            sent = sent,
        )
        assertArrayEquals(byteArrayOf(9, 8, 7), body)
        assertArrayEquals(frame(4, 1, 0) + frame(6, 1, 0, ping), sent.toByteArray())
    }

    @Test
    fun `trames d'un autre flux ignorees, DATA avec bourrage`() {
        val padded = byteArrayOf(2) + byteArrayOf(5, 6) + byteArrayOf(0, 0) // 2 octets de bourrage
        val body = read(
            frame(1, 0x4, 5, byteArrayOf(0x8E.toByte())), // autre flux : 500, ignoré
            frame(1, 0x4, 1, byteArrayOf(0x88.toByte())),
            frame(0, 0x1 or 0x8, 1, padded),
        )
        assertArrayEquals(byteArrayOf(5, 6), body)
    }

    @Test
    fun `erreurs - jamais de reponse DNS inventee`() {
        expectIo { read(frame(1, 0x4, 1, byteArrayOf(0x8E.toByte())), frame(0, 1, 1, dns)) } // 500
        expectIo { read(frame(7, 0, 0, ByteArray(8))) } // GOAWAY
        expectIo { read(frame(3, 0, 1, ByteArray(4))) } // RST_STREAM
        expectIo { read(frame(0, 1, 1, dns)) } // données sans statut
        expectIo { read(frame(1, 0x5, 1, byteArrayOf(0x88.toByte()))) } // 200 sans corps
        expectIo { read(frame(1, 0x4, 1, byteArrayOf(0x88.toByte()))) } // connexion coupée
    }

    @Test
    fun `statut - table statique ou litteral en clair, Huffman refuse`() {
        assertEquals(200, DohHttp.statusOf(byteArrayOf(0x88.toByte())))
        assertEquals(404, DohHttp.statusOf(byteArrayOf(0x8D.toByte())))
        // Changement de taille de table (0x3F 0xE1 0x1F) puis :status indexé.
        assertEquals(200, DohHttp.statusOf(byteArrayOf(0x3F, 0xE1.toByte(), 0x1F, 0x88.toByte())))
        // Littéral, nom = index 8, valeur « 503 » en clair.
        assertEquals(503, DohHttp.statusOf(byteArrayOf(0x08, 3) + "503".toByteArray()))
        expectIo { DohHttp.statusOf(byteArrayOf(0x08, 0x82.toByte(), 0x10, 0x01)) } // Huffman
        expectIo { DohHttp.statusOf(byteArrayOf(0x82.toByte())) } // :method, pas un statut
    }

    @Test
    fun `flux client impair seulement`() {
        try {
            DohHttp.request(dns, streamId = 2)
            fail("flux pair accepté")
        } catch (e: IllegalArgumentException) {
            // attendu
        }
    }

    private fun expectIo(block: () -> Unit) {
        try {
            block()
            fail("IOException attendue")
        } catch (e: IOException) {
            // attendu
        }
    }
}
