package com.iheb.sentinel.firewall

/** Catégories de listes, dans l'ordre de priorité (même ordre que update_lists.py). */
enum class BlockCategory(
    val id: String,
    val label: String,
    val defaultEnabled: Boolean,
    /** Une notification est-elle affichée quand elle bloque un domaine ? */
    val alerts: Boolean,
) {
    MALWARE("malware", "Malware et hameçonnage", defaultEnabled = true, alerts = true),
    TRACKERS("trackers", "Traqueurs", defaultEnabled = true, alerts = false),
    ADS("ads", "Publicités", defaultEnabled = false, alerts = false);

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
) {

    /**
     * La catégorie qui bloque [name], ou null s'il est autorisé.
     * La liste blanche passe avant tout.
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
        return null
    }

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
