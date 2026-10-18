package com.iheb.sentinel.firewall

import com.iheb.sentinel.firewall.TestPackets.hex
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class IpPacketTest {

    // Réponse NXDOMAIN à « example.com » (id 0x1234), 29 octets.
    private val nxdomain = hex("1234 8183 0001 0000 0000 0000") +
        TestPackets.encodeName("example.com") + hex("0001 0001")

    private fun u16(data: ByteArray, offset: Int) = DnsPacket.u16(data, offset)

    @Test
    fun `somme de controle IPv4 de l'exemple de Wikipedia`() {
        // Exemple classique : la somme attendue est 0xB861.
        val header = hex("4500 0073 0000 4000 4011 0000 c0a8 0001 c0a8 00c7")
        assertEquals(0xB861, IpPacket.checksum(header, 0, header.size))
        // Avec la somme en place, la vérification donne 0.
        header[10] = 0xB8.toByte()
        header[11] = 0x61
        assertEquals(0, IpPacket.checksum(header, 0, header.size))
    }

    @Test
    fun `paquet IPv4 UDP avec sommes de controle correctes`() {
        val packet = IpPacket.buildUdp(
            4, TestPackets.DNS_V4, TestPackets.CLIENT_V4, 53, 40000, nxdomain,
        )
        assertEquals(57, packet.size)
        assertEquals(57, u16(packet, 2))
        // Valeurs calculées à part (implémentation Python indépendante).
        assertEquals(0x69D2, u16(packet, 10))
        assertEquals(0x3027, u16(packet, 26))
        assertEquals(0, IpPacket.checksum(packet, 0, 20)) // en-tête valide
    }

    @Test
    fun `paquet IPv6 UDP avec somme de controle correcte`() {
        val packet = IpPacket.buildUdp(
            6, TestPackets.DNS_V6, TestPackets.CLIENT_V6, 53, 40000, nxdomain,
        )
        assertEquals(40 + 8 + nxdomain.size, packet.size)
        assertEquals(8 + nxdomain.size, u16(packet, 4))
        assertEquals(0x548F, u16(packet, 46))
    }

    @Test
    fun `relit un paquet construit`() {
        for (version in listOf(4, 6)) {
            val packet = TestPackets.fromPhone(nxdomain, ipVersion = version)
            val udp = IpPacket.parseUdp(packet)
            assertNotNull(udp)
            assertEquals(version, udp!!.ipVersion)
            assertEquals(40000, udp.sourcePort)
            assertEquals(53, udp.destinationPort)
            assertArrayEquals(nxdomain, udp.payload)
        }
    }

    @Test
    fun `ignore les paquets tronques, TCP et fragments sans exception`() {
        for (version in listOf(4, 6)) {
            val packet = TestPackets.fromPhone(nxdomain, ipVersion = version)
            for (size in 0 until packet.size) {
                assertNull("IPv$version taille $size", IpPacket.parseUdp(packet, size))
            }
        }
        val tcp = TestPackets.fromPhone(nxdomain).also { it[9] = 6 }
        assertNull(IpPacket.parseUdp(tcp))
        val fragment = TestPackets.fromPhone(nxdomain).also { it[6] = 0x20 } // MF
        assertNull(IpPacket.parseUdp(fragment))
        assertNull(IpPacket.parseUdp(byteArrayOf(0x75)))
    }
}
