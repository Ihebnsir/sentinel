package com.iheb.sentinel.firewall

/**
 * Liste de domaines bloqués. Bloquer « doubleclick.net » bloque aussi
 * « ad.doubleclick.net », mais pas « notdoubleclick.net ».
 */
class DomainBlocklist(domains: Collection<String>) {

    private val blocked: Set<String> =
        domains.map(::normalize).filter { it.isNotEmpty() }.toHashSet()

    val size: Int get() = blocked.size

    /** Vrai si [name] ou l'un de ses domaines parents est bloqué. */
    fun isBlocked(name: String): Boolean {
        var candidate = normalize(name)
        while (candidate.isNotEmpty()) {
            if (candidate in blocked) return true
            val dot = candidate.indexOf('.')
            if (dot < 0) return false
            candidate = candidate.substring(dot + 1) // a.b.c → b.c
        }
        return false
    }

    companion object {
        /** Liste de départ : régies publicitaires et traqueurs très connus. */
        val TRACKERS = listOf(
            "doubleclick.net",
            "googlesyndication.com",
            "googleadservices.com",
            "adnxs.com",
            "scorecardresearch.com",
            "taboola.com",
            "outbrain.com",
        )

        /** Bloqué en build debug uniquement, pour tester facilement. */
        const val TEST_DOMAIN = "example.com"

        fun builtIn(includeTestDomain: Boolean): DomainBlocklist =
            DomainBlocklist(if (includeTestDomain) TRACKERS + TEST_DOMAIN else TRACKERS)

        // Minuscules (sans dépendre de la langue du téléphone), sans point final.
        fun normalize(name: String): String = name.trim().trimEnd('.').lowercase()
    }
}
