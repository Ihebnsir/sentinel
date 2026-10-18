package com.iheb.sentinel.firewall

import com.iheb.sentinel.firewall.TestPackets.hex
import com.iheb.sentinel.firewall.TestPackets.query
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DnsPacketTest {

    @Test
    fun `lit une requete A`() {
        val parsed = DnsPacket.parseQuery(query("www.example.com", DnsPacket.TYPE_A))
        assertNotNull(parsed)
        assertEquals(0x1234, parsed!!.id)
        assertEquals("www.example.com", parsed.name)
        assertEquals(DnsPacket.TYPE_A, parsed.type)
        assertEquals(12 + 17 + 4, parsed.questionEnd)
    }

    @Test
    fun `lit une requete AAAA et met le nom en minuscules`() {
        val parsed = DnsPacket.parseQuery(query("Ad.DoubleClick.NET", DnsPacket.TYPE_AAAA))
        assertEquals("ad.doubleclick.net", parsed!!.name)
        assertEquals(DnsPacket.TYPE_AAAA, parsed.type)
    }

    @Test
    fun `suit un pointeur de compression`() {
        // Question « example.com » en 12, puis « www » + pointeur vers 12.
        val message = hex("1234 8180 0001 0001 0000 0000") +
            TestPackets.encodeName("example.com") + hex("0001 0001") +
            hex("03") + "www".toByteArray() + hex("c00c")
        val start = 12 + 13 + 4
        val (name, end) = DnsPacket.readName(message, start)!!
        assertEquals("www.example.com", name)
        assertEquals(start + 4 + 2, end) // après le pointeur, pas après la cible
    }

    @Test
    fun `refuse un pointeur qui boucle ou va vers l'avant`() {
        val header = hex("1234 0100 0001 0000 0000 0000")
        assertNull(DnsPacket.readName(header + hex("c00c"), 12)) // vers lui-même
        assertNull(DnsPacket.readName(header + hex("c00e 00"), 12)) // vers l'avant
        // label puis pointeur qui revient au label : bornée par 255 octets.
        assertNull(DnsPacket.readName(header + hex("01 61 c00c"), 12))
    }

    @Test
    fun `ignore les paquets tronques sans exception`() {
        val full = query("www.example.com", DnsPacket.TYPE_A)
        for (size in 0 until full.size) {
            assertNull("taille $size", DnsPacket.parseQuery(full.copyOf(size)))
        }
    }

    @Test
    fun `ignore les reponses et les requetes non standard`() {
        val response = query("example.com", 1).also { it[2] = 0x81.toByte() }
        assertNull(DnsPacket.parseQuery(response))
        val twoQuestions = query("example.com", 1).also { it[5] = 2 }
        assertNull(DnsPacket.parseQuery(twoQuestions))
    }

    @Test
    fun `construit une reponse NXDOMAIN`() {
        // Requête avec EDNS (enregistrement OPT) : retiré de la réponse.
        val opt = hex("00 0029 1000 00 00 0000 0000")
        val request = query("example.com", DnsPacket.TYPE_A, additional = opt)
        val parsed = DnsPacket.parseQuery(request)!!
        val response = DnsPacket.buildEmptyResponse(request, parsed, DnsPacket.RCODE_NXDOMAIN)

        val expected = hex("1234 8183 0001 0000 0000 0000") +
            TestPackets.encodeName("example.com") + hex("0001 0001")
        assertArrayEquals(expected, response)
        assertEquals(DnsPacket.RCODE_NXDOMAIN, DnsPacket.rcode(response))
        assertTrue(DnsPacket.isResponseTo(request, parsed, response))
    }

    @Test
    fun `verifie qu'une reponse correspond a la requete`() {
        val request = query("example.com", DnsPacket.TYPE_A)
        val parsed = DnsPacket.parseQuery(request)!!
        val good = DnsPacket.buildEmptyResponse(request, parsed, 0)
        assertTrue(DnsPacket.isResponseTo(request, parsed, good))

        val otherId = good.copyOf().also { it[1] = 0x35 }
        assertFalse(DnsPacket.isResponseTo(request, parsed, otherId))
        val otherName = DnsPacket.buildEmptyResponse(
            query("example.org", DnsPacket.TYPE_A),
            DnsPacket.parseQuery(query("example.org", DnsPacket.TYPE_A))!!,
            0,
        )
        assertFalse(DnsPacket.isResponseTo(request, parsed, otherName))
        assertFalse(DnsPacket.isResponseTo(request, parsed, request)) // pas une réponse
    }
}
