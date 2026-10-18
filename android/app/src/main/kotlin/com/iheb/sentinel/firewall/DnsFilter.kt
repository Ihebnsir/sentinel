package com.iheb.sentinel.firewall

/** Ce qu'il faut faire d'un paquet lu dans l'interface TUN. */
sealed class FilterDecision {
    /** Pas une requête DNS lisible : on l'ignore. */
    object Ignore : FilterDecision()

    /** Domaine bloqué : [packet] est la réponse à écrire dans le TUN. */
    class Blocked(val packet: ByteArray) : FilterDecision()

    /** Domaine autorisé : à transférer au résolveur amont. */
    class Forward(val udp: UdpPacket, val query: DnsQuery) : FilterDecision()
}

/**
 * Décide du sort de chaque paquet, sans Android (testable avec JUnit).
 * Ne journalise jamais le nom demandé : c'est l'historique de navigation.
 */
class DnsFilter(private val blocklist: DomainBlocklist) {

    fun decide(packet: ByteArray, length: Int): FilterDecision {
        val udp = IpPacket.parseUdp(packet, length) ?: return FilterDecision.Ignore
        if (udp.destinationPort != DNS_PORT) return FilterDecision.Ignore
        val query = DnsPacket.parseQuery(udp.payload) ?: return FilterDecision.Ignore
        if (!blocklist.isBlocked(query.name)) return FilterDecision.Forward(udp, query)
        // NXDOMAIN pour tous les types (A, AAAA, HTTPS…) : « ce domaine
        // n'existe pas ». Voir docs/SECURITY_DESIGN.md pour le choix.
        val response = DnsPacket.buildEmptyResponse(udp.payload, query, DnsPacket.RCODE_NXDOMAIN)
        return FilterDecision.Blocked(replyTo(udp, response))
    }

    /** Paquet de réponse : adresses et ports inversés par rapport à [request]. */
    fun replyTo(request: UdpPacket, dnsMessage: ByteArray): ByteArray = IpPacket.buildUdp(
        ipVersion = request.ipVersion,
        source = request.destination,
        destination = request.source,
        sourcePort = request.destinationPort,
        destinationPort = request.sourcePort,
        payload = dnsMessage,
    )

    companion object {
        const val DNS_PORT = 53
    }
}
