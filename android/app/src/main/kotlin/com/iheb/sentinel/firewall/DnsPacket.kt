package com.iheb.sentinel.firewall

/** La question d'une requête DNS : nom demandé (en minuscules) et type. */
class DnsQuery(
    val id: Int,
    val name: String,
    val type: Int,
    val questionEnd: Int, // fin de la question dans le message
)

/**
 * Lecture et construction de messages DNS (RFC 1035), sans Android :
 * testable avec JUnit. Ne lève jamais d'exception sur un message
 * mal formé : renvoie null.
 */
object DnsPacket {
    const val TYPE_A = 1
    const val TYPE_AAAA = 28

    const val RCODE_SERVFAIL = 2
    const val RCODE_NXDOMAIN = 3

    private const val HEADER_SIZE = 12
    private const val MAX_NAME_LENGTH = 255
    private const val FLAG_RESPONSE = 0x8000
    private const val FLAG_RECURSION_AVAILABLE = 0x0080
    private const val OPCODE_AND_RD = 0x7900 // opcode + « récursion demandée »

    /** La question d'une requête standard, ou null si illisible. */
    fun parseQuery(message: ByteArray): DnsQuery? {
        if (message.size < HEADER_SIZE) return null
        val flags = u16(message, 2)
        if (flags and FLAG_RESPONSE != 0) return null // c'est une réponse
        if ((flags shr 11) and 0xF != 0) return null // pas une requête standard
        if (u16(message, 4) != 1) return null // une seule question attendue
        val (name, nameEnd) = readName(message, HEADER_SIZE) ?: return null
        if (nameEnd + 4 > message.size) return null // type et classe absents
        return DnsQuery(
            id = u16(message, 0),
            name = name,
            type = u16(message, nameEnd),
            questionEnd = nameEnd + 4,
        )
    }

    /**
     * Lit un nom (« www.example.com ») à partir de [start], en suivant les
     * pointeurs de compression. Renvoie le nom et la position juste après
     * lui dans le message, ou null si le nom est mal formé.
     */
    fun readName(message: ByteArray, start: Int): Pair<String, Int>? {
        val name = StringBuilder()
        var pos = start
        var end = -1 // position après le nom, fixée au premier pointeur
        var length = 0
        while (true) {
            if (pos >= message.size) return null
            val len = message[pos].toInt() and 0xFF
            when {
                len == 0 -> {
                    if (end < 0) end = pos + 1
                    return name.toString() to end
                }
                len and 0xC0 == 0xC0 -> {
                    if (pos + 1 >= message.size) return null
                    val target = ((len and 0x3F) shl 8) or (message[pos + 1].toInt() and 0xFF)
                    // Uniquement vers l'arrière : un pointeur vers l'avant
                    // (ou vers lui-même) pourrait boucler à l'infini.
                    if (target >= pos || target < HEADER_SIZE) return null
                    if (end < 0) end = pos + 2
                    pos = target
                }
                len and 0xC0 != 0 -> return null // 0x40 et 0x80 : réservés
                else -> {
                    if (pos + 1 + len > message.size) return null
                    length += len + 1
                    // Garde aussi contre les boucles label → pointeur arrière.
                    if (length > MAX_NAME_LENGTH) return null
                    if (name.isNotEmpty()) name.append('.')
                    for (i in pos + 1..pos + len) {
                        name.append(lowerAscii(message[i].toInt() and 0xFF))
                    }
                    pos += len + 1
                }
            }
        }
    }

    /**
     * Réponse sans aucune adresse : en-tête + question recopiée.
     * [rcode] : NXDOMAIN (domaine bloqué) ou SERVFAIL (échec).
     */
    fun buildEmptyResponse(query: ByteArray, parsed: DnsQuery, rcode: Int): ByteArray {
        val out = query.copyOf(parsed.questionEnd)
        val flags = FLAG_RESPONSE or (u16(query, 2) and OPCODE_AND_RD) or
            FLAG_RECURSION_AVAILABLE or (rcode and 0xF)
        put16(out, 2, flags)
        put16(out, 4, 1) // une question
        put16(out, 6, 0) // aucune réponse
        put16(out, 8, 0)
        put16(out, 10, 0) // EDNS retiré : la réponse reste minimale
        return out
    }

    /** Vrai si [response] répond bien à cette requête (même id, même question). */
    fun isResponseTo(query: ByteArray, parsed: DnsQuery, response: ByteArray): Boolean {
        if (response.size < parsed.questionEnd) return false
        if (u16(response, 0) != parsed.id) return false
        if (u16(response, 2) and FLAG_RESPONSE == 0) return false
        for (i in 4 until 6) if (response[i] != query[i]) return false
        for (i in HEADER_SIZE until parsed.questionEnd) if (response[i] != query[i]) return false
        return true
    }

    /** Le code de réponse (0 = OK, 3 = NXDOMAIN…). */
    fun rcode(message: ByteArray): Int = u16(message, 2) and 0xF

    private fun lowerAscii(b: Int): Char =
        if (b in 'A'.code..'Z'.code) (b + 32).toChar() else b.toChar()

    internal fun u16(data: ByteArray, offset: Int): Int =
        ((data[offset].toInt() and 0xFF) shl 8) or (data[offset + 1].toInt() and 0xFF)

    internal fun put16(data: ByteArray, offset: Int, value: Int) {
        data[offset] = (value shr 8).toByte()
        data[offset + 1] = value.toByte()
    }
}
