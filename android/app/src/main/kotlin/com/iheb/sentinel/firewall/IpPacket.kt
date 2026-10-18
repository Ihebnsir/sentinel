package com.iheb.sentinel.firewall

/** Un datagramme UDP lu dans un paquet IPv4 ou IPv6. */
class UdpPacket(
    val ipVersion: Int, // 4 ou 6
    val source: ByteArray, // adresse (4 ou 16 octets)
    val destination: ByteArray,
    val sourcePort: Int,
    val destinationPort: Int,
    val payload: ByteArray, // ici : le message DNS
)

/**
 * Lecture et construction de paquets IP/UDP, sans Android : testable avec
 * JUnit. Un paquet mal formé donne null, jamais d'exception.
 */
object IpPacket {
    const val PROTOCOL_UDP = 17

    private const val IPV4_HEADER = 20
    private const val IPV6_HEADER = 40
    private const val UDP_HEADER = 8
    private const val TTL = 64

    /** Le datagramme UDP contenu dans [packet], ou null (TCP, fragment…). */
    fun parseUdp(packet: ByteArray, length: Int = packet.size): UdpPacket? {
        if (length < 1 || length > packet.size) return null
        return when ((packet[0].toInt() and 0xFF) shr 4) {
            4 -> parseIpv4(packet, length)
            6 -> parseIpv6(packet, length)
            else -> null
        }
    }

    private fun parseIpv4(packet: ByteArray, length: Int): UdpPacket? {
        if (length < IPV4_HEADER) return null
        val headerLength = (packet[0].toInt() and 0x0F) * 4
        val totalLength = u16(packet, 2)
        if (headerLength < IPV4_HEADER || totalLength < headerLength + UDP_HEADER) return null
        if (totalLength > length) return null // paquet tronqué
        // Fragment (bit « encore des fragments » ou décalage) : ignoré.
        if (u16(packet, 6) and 0x3FFF != 0) return null
        if (packet[9].toInt() and 0xFF != PROTOCOL_UDP) return null
        return parseUdpHeader(
            packet,
            udpStart = headerLength,
            available = totalLength - headerLength,
            ipVersion = 4,
            source = packet.copyOfRange(12, 16),
            destination = packet.copyOfRange(16, 20),
        )
    }

    private fun parseIpv6(packet: ByteArray, length: Int): UdpPacket? {
        if (length < IPV6_HEADER + UDP_HEADER) return null
        val payloadLength = u16(packet, 4)
        if (IPV6_HEADER + payloadLength > length) return null // paquet tronqué
        // En-têtes d'extension non gérés : jamais utilisés pour le DNS.
        if (packet[6].toInt() and 0xFF != PROTOCOL_UDP) return null
        return parseUdpHeader(
            packet,
            udpStart = IPV6_HEADER,
            available = payloadLength,
            ipVersion = 6,
            source = packet.copyOfRange(8, 24),
            destination = packet.copyOfRange(24, 40),
        )
    }

    private fun parseUdpHeader(
        packet: ByteArray,
        udpStart: Int,
        available: Int,
        ipVersion: Int,
        source: ByteArray,
        destination: ByteArray,
    ): UdpPacket? {
        if (available < UDP_HEADER) return null
        val udpLength = u16(packet, udpStart + 4)
        if (udpLength < UDP_HEADER || udpLength > available) return null
        return UdpPacket(
            ipVersion = ipVersion,
            source = source,
            destination = destination,
            sourcePort = u16(packet, udpStart),
            destinationPort = u16(packet, udpStart + 2),
            payload = packet.copyOfRange(udpStart + UDP_HEADER, udpStart + udpLength),
        )
    }

    /** Construit un paquet IP + UDP complet, sommes de contrôle comprises. */
    fun buildUdp(
        ipVersion: Int,
        source: ByteArray,
        destination: ByteArray,
        sourcePort: Int,
        destinationPort: Int,
        payload: ByteArray,
    ): ByteArray {
        val udpLength = UDP_HEADER + payload.size
        val headerLength = if (ipVersion == 4) IPV4_HEADER else IPV6_HEADER
        val out = ByteArray(headerLength + udpLength)
        if (ipVersion == 4) {
            out[0] = 0x45 // version 4, en-tête de 5 × 4 octets
            put16(out, 2, out.size)
            put16(out, 6, 0x4000) // « ne pas fragmenter »
            out[8] = TTL.toByte()
            out[9] = PROTOCOL_UDP.toByte()
            source.copyInto(out, 12)
            destination.copyInto(out, 16)
            put16(out, 10, checksum(out, 0, IPV4_HEADER))
        } else {
            out[0] = 0x60 // version 6
            put16(out, 4, udpLength)
            out[6] = PROTOCOL_UDP.toByte()
            out[7] = TTL.toByte()
            source.copyInto(out, 8)
            destination.copyInto(out, 24)
        }
        put16(out, headerLength, sourcePort)
        put16(out, headerLength + 2, destinationPort)
        put16(out, headerLength + 4, udpLength)
        payload.copyInto(out, headerLength + UDP_HEADER)
        // Somme UDP : calculée sur un « pseudo-en-tête » (adresses,
        // protocole, longueur) + l'en-tête UDP + les données.
        val pseudo = sumWords(source) + sumWords(destination) + PROTOCOL_UDP + udpLength
        val udpChecksum = checksum(out, headerLength, udpLength, pseudo)
        // 0 voudrait dire « pas de somme » : on écrit 0xFFFF à la place.
        put16(out, headerLength + 6, if (udpChecksum == 0) 0xFFFF else udpChecksum)
        return out
    }

    /** Somme de contrôle Internet (RFC 1071) : complément à 1 sur 16 bits. */
    fun checksum(data: ByteArray, offset: Int, length: Int, initial: Long = 0L): Int {
        var sum = initial
        var i = offset
        val end = offset + length
        while (i + 1 < end) {
            sum += u16(data, i)
            i += 2
        }
        if (i < end) sum += (data[i].toInt() and 0xFF) shl 8 // octet impair
        while (sum shr 16 != 0L) sum = (sum and 0xFFFF) + (sum shr 16)
        return (sum.inv() and 0xFFFF).toInt()
    }

    private fun sumWords(bytes: ByteArray): Long {
        var sum = 0L
        var i = 0
        while (i + 1 < bytes.size) {
            sum += u16(bytes, i)
            i += 2
        }
        return sum
    }

    private fun u16(data: ByteArray, offset: Int): Int = DnsPacket.u16(data, offset)

    private fun put16(data: ByteArray, offset: Int, value: Int) = DnsPacket.put16(data, offset, value)
}
