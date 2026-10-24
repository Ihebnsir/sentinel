package com.iheb.sentinel.firewall

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.EOFException
import java.io.FilterInputStream
import java.io.IOException
import java.io.InputStream

/** SEN-10 : framing DNS sur TCP/TLS (2 octets de longueur). */
class DnsFramingTest {

    // Flux qui ne rend qu'un octet à la fois, comme un réseau lent.
    private class OneByteAtATime(input: InputStream) : FilterInputStream(input) {
        override fun read(b: ByteArray, off: Int, len: Int): Int = super.read(b, off, minOf(len, 1))
    }

    @Test
    fun `longueur sur 2 octets, gros-boutiste`() {
        val message = ByteArray(300) { it.toByte() }
        val framed = DnsFraming.frame(message)
        assertEquals(302, framed.size)
        assertEquals(0x01, framed[0].toInt() and 0xFF) // 300 = 0x012C
        assertEquals(0x2C, framed[1].toInt() and 0xFF)
    }

    @Test
    fun `aller-retour, meme octet par octet`() {
        val message = ByteArray(1000) { (it * 7).toByte() }
        val input = OneByteAtATime(ByteArrayInputStream(DnsFraming.frame(message)))
        assertArrayEquals(message, DnsFraming.read(input))
    }

    @Test
    fun `deux messages a la suite sur la meme connexion`() {
        val a = byteArrayOf(1, 2, 3)
        val b = byteArrayOf(4, 5)
        val input = ByteArrayInputStream(DnsFraming.frame(a) + DnsFraming.frame(b))
        assertArrayEquals(a, DnsFraming.read(input))
        assertArrayEquals(b, DnsFraming.read(input))
    }

    @Test
    fun `connexion coupee - erreur, jamais de message partiel`() {
        expectIo { DnsFraming.read(ByteArrayInputStream(byteArrayOf())) }
        expectIo { DnsFraming.read(ByteArrayInputStream(byteArrayOf(0))) }
        val truncated = DnsFraming.frame(ByteArray(10)).copyOf(7)
        expectIo { DnsFraming.read(ByteArrayInputStream(truncated)) }
        expectIo { DnsFraming.read(ByteArrayInputStream(byteArrayOf(0, 0))) } // longueur 0
    }

    @Test
    fun `tailles refusees a l'envoi`() {
        expectIllegal { DnsFraming.frame(ByteArray(0)) }
        expectIllegal { DnsFraming.frame(ByteArray(DnsFraming.MAX_MESSAGE + 1)) }
        assertEquals(DnsFraming.MAX_MESSAGE + 2, DnsFraming.frame(ByteArray(DnsFraming.MAX_MESSAGE)).size)
    }

    private fun expectIo(block: () -> Unit) {
        try {
            block()
            fail("IOException attendue")
        } catch (e: IOException) {
            if (e !is EOFException && e.message.isNullOrEmpty()) fail("message attendu")
        }
    }

    private fun expectIllegal(block: () -> Unit) {
        try {
            block()
            fail("IllegalArgumentException attendue")
        } catch (e: IllegalArgumentException) {
            // attendu
        }
    }
}
