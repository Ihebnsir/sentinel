package com.iheb.sentinel.firewall

import java.io.EOFException
import java.io.IOException
import java.io.InputStream

/**
 * DNS sur une connexion TCP ou TLS (RFC 7766, RFC 7858) : chaque message
 * est précédé de sa longueur sur 2 octets (gros-boutiste).
 */
object DnsFraming {
    const val MAX_MESSAGE = 65_535

    fun frame(message: ByteArray): ByteArray {
        require(message.isNotEmpty() && message.size <= MAX_MESSAGE) { "Taille DNS invalide" }
        return byteArrayOf((message.size ushr 8).toByte(), message.size.toByte()) + message
    }

    /** Lit un message encadré ; EOFException si la connexion se coupe avant la fin. */
    fun read(input: InputStream): ByteArray {
        val high = input.read()
        val low = input.read()
        if (high < 0 || low < 0) throw EOFException("Connexion fermée")
        val length = (high shl 8) or low
        if (length == 0) throw IOException("Message vide")
        val message = ByteArray(length)
        var offset = 0
        while (offset < length) {
            val n = input.read(message, offset, length - offset)
            if (n < 0) throw EOFException("Message tronqué")
            offset += n
        }
        return message
    }
}
