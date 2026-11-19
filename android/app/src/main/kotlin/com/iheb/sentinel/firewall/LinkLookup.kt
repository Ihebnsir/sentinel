package com.iheb.sentinel.firewall

/** Ce que les listes du pare-feu disent d'un domaine (onglet Liens). */
data class DomainCheck(
    /** Domaine normalisé (minuscules, punycode). */
    val domain: String,
    /** Dans la liste blanche de l'utilisateur (ou sous-domaine d'un site autorisé). */
    val allowed: Boolean,
    /** Dans la liste « Malware et hameçonnage » (jamais vrai si autorisé). */
    val dangerous: Boolean,
)

/**
 * Vérification d'un domaine pour l'onglet Liens, sans réseau et sans VPN.
 * Mêmes règles que le pare-feu : la liste blanche passe avant tout.
 * Fonction pure, testée sur la JVM (LinkLookupTest).
 */
object LinkLookup {
    /** null si [raw] n'est pas un nom de domaine (adresse IP, texte…). */
    fun check(
        raw: String,
        allowlist: DomainSet,
        malware: CategoryList,
        testDomain: String? = null,
    ): DomainCheck? {
        val name = DomainNames.normalize(raw) ?: return null
        val allowed = BlockPolicy.matchesWithParents(allowlist, name)
        val test = testDomain != null && (name == testDomain || name.endsWith(".$testDomain"))
        val dangerous = !allowed && (test || malware.matches(name))
        return DomainCheck(name, allowed, dangerous)
    }
}
