package com.iheb.sentinel.firewall

import org.json.JSONObject

/** Une marque souvent imitée, et ses vrais sites (assets/data/known_brands.json). */
class KnownBrand(
    val name: String,
    val keywords: List<String>,
    val officialDomains: List<String>,
)

/**
 * Règle d'usurpation de marque : MÊME logique que impersonatedBrand()
 * en Dart (lib/services/phishing/url_analyzer.dart). Les deux sont
 * vérifiées par test/fixtures/brand_parity.json.
 */
object BrandRules {

    const val FORMAT_VERSION = 1

    /** Lit known_brands.json ; lance une exception si le fichier est invalide. */
    fun parse(json: String): List<KnownBrand> {
        val root = JSONObject(json)
        require(root.getInt("formatVersion") == FORMAT_VERSION) { "Version inconnue" }
        val array = root.getJSONArray("brands")
        return (0 until array.length()).map { i ->
            val item = array.getJSONObject(i)
            KnownBrand(
                name = item.getString("name"),
                keywords = strings(item, "keywords"),
                officialDomains = strings(item, "officialDomains"),
            )
        }
    }

    // Deuxièmes niveaux du type « com.tn » (même liste que _secondLevels en Dart).
    private val SECOND_LEVELS = setOf("com", "org", "net", "gov", "edu", "ens", "nat", "co")

    /**
     * Nom du domaine enregistrable : « laposte » pour « www.laposte.fr »,
     * « biat » pour « biat.com.tn ». null pour un nom sans extension.
     */
    fun registrableName(host: String): String? {
        val labels = host.split('.')
        val hasSecondLevel = labels.size >= 3 &&
            labels.last().length == 2 &&
            labels[labels.size - 2] in SECOND_LEVELS
        val domainParts = if (hasSecondLevel) 3 else 2
        return if (labels.size >= domainParts) labels[labels.size - domainParts] else null
    }

    /**
     * Extensions bon marché des arnaques : MÊME liste que suspiciousTlds
     * en Dart (url_analyzer.dart), vérifiée par brand_parity.json.
     */
    val SUSPICIOUS_TLDS = setOf("xyz", "top", "icu", "click", "live", "buzz", "rest", "cfd")

    /**
     * La marque que [host] imite, ou null. Un mot-clé court (< 5 lettres)
     * doit être un morceau entier du domaine ; un mot-clé long peut être
     * collé au début ou à la fin d'un morceau (« laposte-colis »,
     * « monlaposte »), pas au milieu d'un autre mot (« imposter »).
     * Jamais signalés : le domaine officiel et ses sous-domaines, et le
     * mot-clé seul suivi d'une extension étrangère (« laposte.fr », « orange.be »).
     */
    fun impersonatedBrand(host: String, brands: List<KnownBrand>): KnownBrand? {
        if (brands.isEmpty()) return null
        val parts = host.split('.', '-')
        // Morceaux où chercher un mot-clé long : chaque partie, et chaque
        // étiquette sans ses tirets (« la-poste-tn » → « lapostetn »).
        val pieces = parts + host.split('.').map { it.replace("-", "") }
        val tld = host.substringAfterLast('.')
        // Pas d'exemption pour une extension d'arnaque (« biat.xyz ») ni
        // tunisienne : une marque tunisienne n'a pas d'« autre pays » en .tn.
        val exemptable = tld !in SUSPICIOUS_TLDS && tld != "tn"
        val name = if (exemptable) registrableName(host) else null
        for (brand in brands) {
            val mentioned = brand.keywords.any { k ->
                k in parts ||
                    (k.length >= 5 && pieces.any { p -> p.startsWith(k) || p.endsWith(k) })
            }
            if (!mentioned) continue
            // Mot-clé seul + extension : sans doute le vrai site de la même
            // marque dans un autre pays. Signalé seulement s'il est combiné à
            // d'autres mots (« laposte-colis.xyz ») ou en sous-domaine d'un autre site.
            if (name in brand.keywords) continue
            val official = brand.officialDomains.any { d -> host == d || host.endsWith(".$d") }
            if (!official) return brand
        }
        return null
    }

    private fun strings(item: JSONObject, key: String): List<String> {
        val array = item.getJSONArray(key)
        return (0 until array.length()).map { array.getString(it) }
    }
}
