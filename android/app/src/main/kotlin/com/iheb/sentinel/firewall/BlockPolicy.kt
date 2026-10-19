package com.iheb.sentinel.firewall

/** Catégories de listes, dans l'ordre de priorité (même ordre que update_lists.py). */
enum class BlockCategory(
    val id: String,
    val label: String,
    val defaultEnabled: Boolean,
    /** Une notification est-elle affichée quand elle bloque un domaine ? */
    val alerts: Boolean,
    /** Faux : pas de fichier de liste, une règle (imitation de marque). */
    val hasList: Boolean = true,
) {
    MALWARE("malware", "Malware et hameçonnage", defaultEnabled = true, alerts = true),
    TRACKERS("trackers", "Traqueurs", defaultEnabled = true, alerts = false),
    ADS("ads", "Publicités", defaultEnabled = false, alerts = false),

    /** Domaine absent des listes mais qui imite une marque connue (BrandRules). */
    IMPERSONATION(
        "impersonation", "Imitations de marques",
        defaultEnabled = true, alerts = true, hasList = false,
    );

    companion object {
        fun fromId(id: String?): BlockCategory? = entries.firstOrNull { it.id == id }
    }
}

/**
 * Photo figée des règles : listes chargées, catégories actives, liste
 * blanche. Pour changer une règle, on construit une nouvelle photo et on
 * remplace l'ancienne d'un coup (aucun verrou pendant la recherche).
 */
class BlockPolicy(
    private val lists: Map<BlockCategory, CategoryList>,
    val enabled: Set<BlockCategory>,
    /** Liste blanche : le domaine ET ses sous-domaines passent toujours. */
    private val allowlist: DomainSet,
    /** Domaine de test (build debug) : rangé dans « Malware » pour tester l'alerte. */
    private val testDomain: String? = null,
    /** Marques de known_brands.json, pour la catégorie « Imitations de marques ». */
    private val brands: List<KnownBrand> = emptyList(),
) {

    /**
     * La catégorie qui bloque [name], ou null s'il est autorisé.
     * Ordre : liste blanche (avant tout), listes, puis imitation de marque.
     */
    fun check(name: String): BlockCategory? {
        val normalized = normalizeQuery(name) ?: return null
        if (matchesWithParents(allowlist, normalized)) return null
        if (testDomain != null && BlockCategory.MALWARE in enabled &&
            (normalized == testDomain || normalized.endsWith(".$testDomain"))
        ) {
            return BlockCategory.MALWARE
        }
        for (category in BlockCategory.entries) {
            if (category !in enabled) continue
            if (lists[category]?.matches(normalized) == true) return category
        }
        if (BlockCategory.IMPERSONATION in enabled &&
            BrandRules.impersonatedBrand(normalized, brands) != null
        ) {
            return BlockCategory.IMPERSONATION
        }
        return null
    }

    /**
     * Catégorie de [name] pour le rapport d'analyse, que la catégorie soit
     * active ou non et sans tenir compte de la liste blanche. null : « autre ».
     */
    fun classify(name: String): BlockCategory? {
        val normalized = normalizeQuery(name) ?: return null
        for (category in BlockCategory.entries) {
            if (lists[category]?.matches(normalized) == true) return category
        }
        if (BrandRules.impersonatedBrand(normalized, brands) != null) {
            return BlockCategory.IMPERSONATION
        }
        return null
    }

    /** La marque imitée par [name] (texte de l'alerte), ou null. */
    fun impersonatedBrand(name: String): KnownBrand? {
        val normalized = normalizeQuery(name) ?: return null
        return BrandRules.impersonatedBrand(normalized, brands)
    }

    /** Nom normalisé, ou null s'il est invalide (enregistré tel quel dans le rapport). */
    fun normalized(name: String): String? = normalizeQuery(name)

    /** Nombre d'entrées de [category] si elle est chargée, sinon null. */
    fun size(category: BlockCategory): Int? = lists[category]?.size

    companion object {
        val EMPTY = BlockPolicy(emptyMap(), emptySet(), DomainSet.EMPTY)

        private fun matchesWithParents(set: DomainSet, name: String): Boolean {
            if (set.size == 0) return false
            var start = 0
            while (true) {
                if (set.contains(name, start)) return true
                val dot = name.indexOf('.', start)
                if (dot < 0) return false
                start = dot + 1
            }
        }

        // Les noms lus dans les paquets DNS sont déjà en minuscules ASCII :
        // dans ce cas (le plus fréquent), aucune copie.
        private fun normalizeQuery(name: String): String? {
            val simple = name.isNotEmpty() && !name.endsWith('.') &&
                name.all { it in 'a'..'z' || it in '0'..'9' || it == '-' || it == '_' || it == '.' }
            return if (simple) name else DomainNames.normalize(name)
        }
    }
}
