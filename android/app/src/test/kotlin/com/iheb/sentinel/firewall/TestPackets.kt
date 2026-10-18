package com.iheb.sentinel.firewall

import java.io.ByteArrayOutputStream
import java.net.InetAddress

/** Petits outils pour fabriquer des paquets de test à la main. */
object TestPackets {
    val CLIENT_V4: ByteArray = InetAddress.getByName("10.111.222.1").address
    val DNS_V4: ByteArray = InetAddress.getByName("10.111.222.2").address
    val CLIENT_V6: ByteArray = InetAddress.getByName("fdc5:3a71:9e04::1").address
    val DNS_V6: ByteArray = InetAddress.getByName("fdc5:3a71:9e04::2").address

    fun hex(text: String): ByteArray =
        text.replace(" ", "").chunked(2).map { it.toInt(16).toByte() }.toByteArray()

    /** « www.example.com » → 3www7example3com0 */
    fun encodeName(name: String): ByteArray {
        val out = ByteArrayOutputStream()
        for (label in name.split('.')) {
            out.write(label.length)
            out.write(label.toByteArray(Charsets.US_ASCII))
        }
        out.write(0)
        return out.toByteArray()
    }

    /** Requête DNS standard (récursion demandée), une question. */
    fun query(name: String, type: Int, id: Int = 0x1234, additional: ByteArray = ByteArray(0)): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(hex("%04x 0100 0001 0000 0000 %04x".format(id, if (additional.isEmpty()) 0 else 1)))
        out.write(encodeName(name))
        out.write(hex("%04x 0001".format(type)))
        out.write(additional)
        return out.toByteArray()
    }

    /** Paquet IP complet du téléphone vers le DNS virtuel, port source 40000. */
    fun fromPhone(dns: ByteArray, ipVersion: Int = 4, destinationPort: Int = 53): ByteArray =
        IpPacket.buildUdp(
            ipVersion = ipVersion,
            source = if (ipVersion == 4) CLIENT_V4 else CLIENT_V6,
            destination = if (ipVersion == 4) DNS_V4 else DNS_V6,
            sourcePort = 40000,
            destinationPort = destinationPort,
            payload = dns,
        )
}
