package com.iheb.sentinel.firewall

import java.io.IOException
import java.util.concurrent.ConcurrentHashMap

/** Comment partent les requêtes DNS vers Quad9 (affiché dans l'écran du pare-feu). */
enum class UpstreamMode(val id: String) {
    IDLE("idle"), // pas encore de requête
    DOT("dot"), // DNS-over-TLS, port 853
    DOH("doh"), // DNS-over-HTTPS, port 443
    PLAIN("plain"), // en clair, seulement si l'utilisateur l'a autorisé
    FAILING("failing"), // aucun transport chiffré ne répond : SERVFAIL
}

/** Un moyen d'envoyer une requête DNS et de recevoir la réponse. */
interface DnsTransport {
    val mode: UpstreamMode

    /** Réponse brute ; IOException en cas d'échec (délai, refus, certificat…). */
    fun exchange(request: ByteArray): ByteArray

    fun close()
}

/**
 * Choisit le transport (SEN-10) : d'abord les transports chiffrés, dans
 * l'ordre (DoT puis DoH) ; un transport en panne passe en dernier pendant
 * [retryAfterMs]. Le transport en clair n'est JAMAIS utilisé sans
 * [plainAllowed] (choix explicite de l'utilisateur pour ce réseau) :
 * sinon resolve() renvoie null et l'appelant répond SERVFAIL.
 */
class UpstreamResolver(
    private val encrypted: List<DnsTransport>,
    private val plain: DnsTransport,
    private val plainAllowed: () -> Boolean,
    private val clock: () -> Long = System::currentTimeMillis,
    private val retryAfterMs: Long = 5 * 60 * 1000L,
) {
    @Volatile
    var mode: UpstreamMode = UpstreamMode.IDLE
        private set

    private val downUntil = ConcurrentHashMap<UpstreamMode, Long>()

    /** Réponse acceptée par [accept] (bonne question), ou null. */
    fun resolve(request: ByteArray, accept: (ByteArray) -> Boolean): ByteArray? {
        val now = clock()
        // Tri stable : l'ordre DoT, DoH est gardé parmi ceux qui marchent.
        val ordered = encrypted.sortedBy { if ((downUntil[it.mode] ?: 0L) > now) 1 else 0 }
        for (transport in ordered) {
            val response = tryExchange(transport, request, accept)
            if (response != null) {
                downUntil.remove(transport.mode)
                mode = transport.mode
                return response
            }
            downUntil[transport.mode] = now + retryAfterMs
        }
        if (plainAllowed()) {
            val response = tryExchange(plain, request, accept)
            if (response != null) {
                mode = UpstreamMode.PLAIN
                return response
            }
        }
        mode = UpstreamMode.FAILING
        return null
    }

    fun close() {
        encrypted.forEach { it.close() }
        plain.close()
    }

    private fun tryExchange(
        transport: DnsTransport,
        request: ByteArray,
        accept: (ByteArray) -> Boolean,
    ): ByteArray? = try {
        transport.exchange(request).takeIf(accept)
    } catch (e: IOException) {
        null
    }
}
