package com.iheb.sentinel.firewall

/**
 * Ensemble de domaines compact : tous les noms collés dans un seul tableau
 * d'octets trié, plus la position de chacun. Recherche dichotomique.
 *
 * Pourquoi pas un HashSet<String> ? Pour 430 000 domaines, un HashSet
 * coûte environ 110 octets par nom (objet String + tableau + nœud de
 * table), contre environ 30 ici (les lettres + 4 octets de position).
 * Chiffres mesurés : voir DomainSetBenchmarkTest et docs/ARCHITECTURE.md.
 */
class DomainSet private constructor(
    private val data: ByteArray,
    private val offsets: IntArray, // offsets[i]..offsets[i+1] = nom n° i
) {
    val size: Int get() = offsets.size - 1

    /** Mémoire utilisée par les deux tableaux, en octets. */
    val memoryBytes: Long get() = data.size.toLong() + offsets.size * 4L

    /** Vrai si [name] (à partir de l'indice [start]) est dans l'ensemble. */
    fun contains(name: String, start: Int = 0): Boolean {
        var low = 0
        var high = size - 1
        while (low <= high) {
            val mid = (low + high) ushr 1
            val cmp = compareAt(mid, name, start)
            when {
                cmp < 0 -> low = mid + 1
                cmp > 0 -> high = mid - 1
                else -> return true
            }
        }
        return false
    }

    // Compare le nom n° [index] à name[start..] sans créer de String.
    private fun compareAt(index: Int, name: String, start: Int): Int {
        var i = offsets[index]
        val end = offsets[index + 1]
        var j = start
        while (i < end && j < name.length) {
            val diff = (data[i].toInt() and 0xFF) - name[j].code
            if (diff != 0) return diff
            i++
            j++
        }
        return (end - i) - (name.length - j)
    }

    /** Construit l'ensemble à partir de noms ASCII déjà triés et uniques. */
    class Builder(expectedBytes: Int = 1024) {
        private var data = ByteArray(maxOf(expectedBytes, 16))
        private var length = 0
        private var offsets = IntArray(1024)
        private var count = 0
        private var lastStart = -1

        /** Lance IllegalArgumentException si l'ordre n'est pas respecté. */
        fun add(name: String) {
            require(name.isNotEmpty()) { "Nom vide" }
            ensureData(name.length)
            val start = length
            for (c in name) {
                require(c.code in 1..127) { "Nom non ASCII" }
                data[length++] = c.code.toByte()
            }
            if (lastStart >= 0) {
                require(compareBytes(lastStart, start, start, length) < 0) {
                    "Liste non triée ou avec doublons"
                }
            }
            if (count + 2 > offsets.size) offsets = offsets.copyOf(offsets.size * 2)
            offsets[count++] = start
            lastStart = start
        }

        fun build(): DomainSet {
            val finalOffsets = offsets.copyOf(count + 1)
            finalOffsets[count] = length
            return DomainSet(data.copyOf(length), finalOffsets)
        }

        private fun ensureData(extra: Int) {
            if (length + extra <= data.size) return
            data = data.copyOf(maxOf(data.size * 2, length + extra))
        }

        private fun compareBytes(aStart: Int, aEnd: Int, bStart: Int, bEnd: Int): Int {
            var i = aStart
            var j = bStart
            while (i < aEnd && j < bEnd) {
                val diff = (data[i].toInt() and 0xFF) - (data[j].toInt() and 0xFF)
                if (diff != 0) return diff
                i++
                j++
            }
            return (aEnd - i) - (bEnd - j)
        }
    }

    companion object {
        val EMPTY: DomainSet = Builder().build()

        /** Pour les petites listes (liste blanche, tests) : trie et dédoublonne. */
        fun of(names: Collection<String>): DomainSet {
            val builder = Builder()
            names.toSortedSet().forEach(builder::add)
            return builder.build()
        }
    }
}
