package com.iheb.sentinel.firewall

import com.iheb.sentinel.firewall.TestPackets.query
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class DnsFilterTest {

    private val blocklist = DomainBlocklist(listOf("doubleclick.net", "Example.COM."))

    @Test
    fun `bloque le domaine et ses sous-domaines`() {
        assertTrue(blocklist.isBlocked("doubleclick.net"))
        assertTrue(blocklist.isBlocked("ad.g.doubleclick.net"))
        assertTrue(blocklist.isBlocked("WWW.EXAMPLE.COM."))
    }

    @Test
    fun `ne bloque pas les domaines qui se ressemblent`() {
        assertFalse(blocklist.isBlocked("notdoubleclick.net"))
        assertFalse(blocklist.isBlocked("doubleclick.net.evil.org"))
        assertFalse(blocklist.isBlocked("net"))
        assertFalse(blocklist.isBlocked(""))
    }

    @Test
    fun `domaine de test seulement en debug`() {
        assertTrue(DomainBlocklist.builtIn(includeTestDomain = true).isBlocked("example.com"))
        assertFalse(DomainBlocklist.builtIn(includeTestDomain = false).isBlocked("example.com"))
        assertTrue(DomainBlocklist.builtIn(includeTestDomain = false).isBlocked("ad.doubleclick.net"))
    }

    @Test
    fun `domaine bloque - reponse NXDOMAIN renvoyee au telephone`() {
        val filter = DnsFilter(blocklist)
        for (version in listOf(4, 6)) {
            val request = query("ads.doubleclick.net", DnsPacket.TYPE_AAAA)
            val packet = TestPackets.fromPhone(request, ipVersion = version)
            val decision = filter.decide(packet, packet.size) as FilterDecision.Blocked

            val reply = IpPacket.parseUdp(decision.packet)!!
            // Adresses et ports inversés : du DNS virtuel vers le téléphone.
            val phone = if (version == 4) TestPackets.CLIENT_V4 else TestPackets.CLIENT_V6
            assertArrayEquals(phone, reply.destination)
            assertEquals(53, reply.sourcePort)
            assertEquals(40000, reply.destinationPort)
            assertEquals(DnsPacket.RCODE_NXDOMAIN, DnsPacket.rcode(reply.payload))
        }
    }

    @Test
    fun `domaine autorise - transfere au resolveur`() {
        val packet = TestPackets.fromPhone(query("www.wikipedia.org", DnsPacket.TYPE_A))
        val decision = DnsFilter(blocklist).decide(packet, packet.size) as FilterDecision.Forward
        assertEquals("www.wikipedia.org", decision.query.name)
    }

    @Test
    fun `ignore ce qui n'est pas une requete DNS`() {
        val filter = DnsFilter(blocklist)
        val otherPort = TestPackets.fromPhone(query("example.com", 1), destinationPort = 443)
        assertSame(FilterDecision.Ignore, filter.decide(otherPort, otherPort.size))
        val garbage = TestPackets.fromPhone(byteArrayOf(1, 2, 3))
        assertSame(FilterDecision.Ignore, filter.decide(garbage, garbage.size))
        assertSame(FilterDecision.Ignore, filter.decide(ByteArray(10), 10))
    }
}
