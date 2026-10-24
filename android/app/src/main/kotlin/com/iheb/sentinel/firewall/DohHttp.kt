package com.iheb.sentinel.firewall

import java.io.ByteArrayOutputStream
import java.io.EOFException
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream

/**
 * HTTP/2 minimal pour DNS-over-HTTPS (RFC 8484, RFC 9113) vers Quad9, qui
 * refuse HTTP/1.1 (505). Écrit à la main : la connexion part vers l'adresse
 * IP, sans aucune résolution DNS (qui repasserait par le pare-feu).
 * Une requête à la fois par connexion ; flux 1, 3, 5… sur une connexion
 * réutilisée. En-têtes HPACK en littéral, sans compression Huffman.
 */
object DohHttp {
    const val PATH = "/dns-query"
    const val ALPN = "h2"
    private const val TYPE = "application/dns-message"

    private val PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".toByteArray(Charsets.US_ASCII)

    // Types et drapeaux de trames (RFC 9113, section 6).
    private const val DATA = 0x0
    private const val HEADERS = 0x1
    private const val RST_STREAM = 0x3
    private const val SETTINGS = 0x4
    private const val PING = 0x6
    private const val GOAWAY = 0x7
    private const val CONTINUATION = 0x9
    private const val END_STREAM = 0x1
    private const val ACK = 0x1
    private const val END_HEADERS = 0x4
    private const val PADDED = 0x8
    private const val PRIORITY = 0x20
    private const val MAX_FRAME = 16_384

    /** Début de connexion : préface et réglages vides (valeurs par défaut). */
    fun connectionPreface(): ByteArray = PREFACE + frame(SETTINGS, 0, 0, ByteArray(0))

    /** Requête POST sur le flux [streamId] : trame HEADERS puis DATA. */
    fun request(message: ByteArray, streamId: Int, host: String = Quad9.SERVER_NAME): ByteArray {
        require(message.isNotEmpty() && message.size <= DnsFraming.MAX_MESSAGE) { "Taille DNS invalide" }
        require(streamId > 0 && streamId % 2 == 1) { "Flux client impair" }
        val headers = ByteArrayOutputStream().apply {
            write(0x83) // :method POST (table statique, index 3)
            write(0x87) // :scheme https (index 7)
            literal(4, PATH) // :path
            literal(1, host) // :authority
            literal(31, TYPE) // content-type
            literal(19, TYPE) // accept
            literal(28, message.size.toString()) // content-length
        }.toByteArray()
        val out = ByteArrayOutputStream()
        out.write(frame(HEADERS, END_HEADERS, streamId, headers))
        var offset = 0
        while (offset < message.size) {
            val end = minOf(offset + MAX_FRAME, message.size)
            val last = end == message.size
            out.write(frame(DATA, if (last) END_STREAM else 0, streamId, message.copyOfRange(offset, end)))
            offset = end
        }
        return out.toByteArray()
    }

    /**
     * Lit la réponse du flux [streamId] : statut 200 exigé, corps = message
     * DNS. Répond aux SETTINGS et PING du serveur sur [output].
     */
    fun readResponse(input: InputStream, output: OutputStream, streamId: Int): ByteArray {
        var status: Int? = null
        val body = ByteArrayOutputStream()
        while (true) {
            val header = readExactly(input, 9)
            val length = ((header[0].toInt() and 0xFF) shl 16) or
                ((header[1].toInt() and 0xFF) shl 8) or (header[2].toInt() and 0xFF)
            val type = header[3].toInt() and 0xFF
            val flags = header[4].toInt() and 0xFF
            val stream = ((header[5].toInt() and 0x7F) shl 24) or ((header[6].toInt() and 0xFF) shl 16) or
                ((header[7].toInt() and 0xFF) shl 8) or (header[8].toInt() and 0xFF)
            if (length > MAX_FRAME) throw IOException("Trame trop grande")
            val payload = readExactly(input, length)
            when (type) {
                SETTINGS -> if (flags and ACK == 0) {
                    output.write(frame(SETTINGS, ACK, 0, ByteArray(0)))
                    output.flush()
                }
                PING -> if (flags and ACK == 0) {
                    output.write(frame(PING, ACK, 0, payload))
                    output.flush()
                }
                GOAWAY -> throw IOException("Connexion refermée par le serveur (GOAWAY)")
                RST_STREAM -> if (stream == streamId) throw IOException("Flux annulé (RST_STREAM)")
                HEADERS -> if (stream == streamId) {
                    status = status ?: statusOf(unpad(payload, flags, priority = flags and PRIORITY != 0))
                    if (status != 200) throw IOException("Statut HTTP $status")
                    if (flags and END_STREAM != 0) break
                }
                CONTINUATION -> Unit // suite d'en-têtes : le statut est déjà lu
                DATA -> if (stream == streamId) {
                    if (status != 200) throw IOException("Données avant le statut")
                    body.write(unpad(payload, flags, priority = false))
                    if (body.size() > DnsFraming.MAX_MESSAGE) throw IOException("Réponse trop grande")
                    if (flags and END_STREAM != 0) break
                }
                else -> Unit // WINDOW_UPDATE, PRIORITY… : sans effet ici
            }
        }
        if (body.size() == 0) throw IOException("Réponse vide")
        return body.toByteArray()
    }

    /**
     * Statut de la réponse : premier en-tête du bloc (« :status »). Le
     * serveur utilise la table statique (index 8 à 14) ; une valeur
     * compressée (Huffman) est refusée.
     */
    fun statusOf(block: ByteArray): Int {
        var i = 0
        // Changements de taille de la table dynamique (préfixe 001) : ignorés.
        while (i < block.size && block[i].toInt() and 0xE0 == 0x20) i += integerLength(block, i, 5)
        if (i >= block.size) throw IOException("Statut absent")
        val first = block[i].toInt() and 0xFF
        if (first and 0x80 != 0) {
            return when (first and 0x7F) {
                8 -> 200; 9 -> 204; 10 -> 206; 11 -> 304; 12 -> 400; 13 -> 404; 14 -> 500
                else -> throw IOException("Statut inattendu")
            }
        }
        // Littéral avec nom indexé (:status = index 8 à 14), valeur en clair.
        val prefix = if (first and 0x40 != 0) 6 else 4
        val nameIndex = first and ((1 shl prefix) - 1)
        if (nameIndex !in 8..14) throw IOException("Statut absent")
        val valueStart = i + 1
        if (valueStart >= block.size || block[valueStart].toInt() and 0x80 != 0) {
            throw IOException("Statut compressé non pris en charge")
        }
        val length = block[valueStart].toInt() and 0x7F
        if (valueStart + 1 + length > block.size) throw IOException("Statut tronqué")
        return String(block, valueStart + 1, length, Charsets.US_ASCII).toIntOrNull()
            ?: throw IOException("Statut invalide")
    }

    private fun frame(type: Int, flags: Int, streamId: Int, payload: ByteArray): ByteArray {
        val n = payload.size
        return byteArrayOf(
            (n ushr 16).toByte(), (n ushr 8).toByte(), n.toByte(),
            type.toByte(), flags.toByte(),
            (streamId ushr 24).toByte(), (streamId ushr 16).toByte(),
            (streamId ushr 8).toByte(), streamId.toByte(),
        ) + payload
    }

    // Littéral sans indexation, nom pris dans la table statique, valeur en clair.
    private fun ByteArrayOutputStream.literal(nameIndex: Int, value: String) {
        writeInteger(nameIndex, prefixBits = 4, firstByte = 0x00)
        val bytes = value.toByteArray(Charsets.US_ASCII)
        writeInteger(bytes.size, prefixBits = 7, firstByte = 0x00)
        write(bytes)
    }

    // Entier HPACK (RFC 7541, section 5.1).
    private fun ByteArrayOutputStream.writeInteger(value: Int, prefixBits: Int, firstByte: Int) {
        val max = (1 shl prefixBits) - 1
        if (value < max) {
            write(firstByte or value)
            return
        }
        write(firstByte or max)
        var rest = value - max
        while (rest >= 128) {
            write((rest and 0x7F) or 0x80)
            rest = rest ushr 7
        }
        write(rest)
    }

    // Nombre d'octets d'un entier HPACK commençant à [start].
    private fun integerLength(block: ByteArray, start: Int, prefixBits: Int): Int {
        val max = (1 shl prefixBits) - 1
        if (block[start].toInt() and max != max) return 1
        var i = start + 1
        while (i < block.size && block[i].toInt() and 0x80 != 0) i++
        return i - start + 1
    }

    private fun unpad(payload: ByteArray, flags: Int, priority: Boolean): ByteArray {
        var start = 0
        var end = payload.size
        if (flags and PADDED != 0) {
            if (payload.isEmpty()) throw IOException("Trame invalide")
            end -= payload[0].toInt() and 0xFF
            start = 1
        }
        if (priority) start += 5
        if (start > end) throw IOException("Trame invalide")
        return payload.copyOfRange(start, end)
    }

    private fun readExactly(input: InputStream, length: Int): ByteArray {
        val data = ByteArray(length)
        var offset = 0
        while (offset < length) {
            val n = input.read(data, offset, length - offset)
            if (n < 0) throw EOFException("Connexion fermée")
            offset += n
        }
        return data
    }
}
