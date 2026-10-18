package com.iheb.sentinel.firewall

import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.security.DigestInputStream
import java.security.MessageDigest

/**
 * Les domaines d'une catégorie : noms exacts (« pub.exemple.com ») et noms
 * avec sous-domaines (« *.exemple.com » bloque aussi « a.b.exemple.com »).
 */
class CategoryList(val exact: DomainSet, val wildcard: DomainSet) {

    val size: Int get() = exact.size + wildcard.size

    val memoryBytes: Long get() = exact.memoryBytes + wildcard.memoryBytes

    /** [name] doit être normalisé (minuscules, sans point final). */
    fun matches(name: String): Boolean {
        if (exact.contains(name)) return true
        // name, puis chaque domaine parent : a.b.c → b.c → c.
        var start = 0
        while (true) {
            if (wildcard.contains(name, start)) return true
            val dot = name.indexOf('.', start)
            if (dot < 0) return false
            start = dot + 1
        }
    }

    companion object {
        val EMPTY = CategoryList(DomainSet.EMPTY, DomainSet.EMPTY)

        /**
         * Lit un fichier généré (trié, « *. » pour les sous-domaines) et
         * vérifie son SHA-256. Lance une exception si le fichier est abîmé,
         * mal trié ou ne correspond pas à [expectedSha256].
         */
        fun read(input: InputStream, expectedSha256: String?, sizeHint: Int = 0): CategoryList {
            val digest = MessageDigest.getInstance("SHA-256")
            val exact = DomainSet.Builder(sizeHint)
            val wildcard = DomainSet.Builder(sizeHint / 4)
            BufferedReader(InputStreamReader(DigestInputStream(input, digest), Charsets.US_ASCII))
                .use { reader ->
                    reader.forEachLine { line ->
                        if (line.isEmpty() || line.startsWith("#")) return@forEachLine
                        val wild = line.startsWith("*.")
                        val name = if (wild) line.substring(2) else line
                        require(DomainNames.isValidAscii(name)) { "Entrée invalide" }
                        if (wild) wildcard.add(name) else exact.add(name)
                    }
                }
            if (expectedSha256 != null) {
                val actual = digest.digest().toHex()
                require(actual.equals(expectedSha256, ignoreCase = true)) { "SHA-256 différent" }
            }
            return CategoryList(exact.build(), wildcard.build())
        }

        fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }
    }
}

/**
 * Fusionne les entrées de plusieurs sources (même logique que la fonction
 * construire() de update_lists.py) :
 * 1. retire toute entrée qui bloquerait un domaine protégé ;
 * 2. retire les doublons et les entrées déjà couvertes par un « *. ».
 */
class CategoryBuilder(protectedDomains: Set<String>) {

    private val protectedExact = protectedDomains
    // « *.x » est interdit si x est un domaine protégé ou l'un de ses parents.
    private val forbiddenWildcards = protectedDomains.flatMap(DomainNames::parents).toHashSet()

    // Les noms exacts (les plus nombreux) dans une simple liste, triée et
    // dédoublonnée à la fin : bien moins de mémoire qu'un HashSet.
    private val exact = ArrayList<String>()
    private val wildcard = HashSet<String>()

    var removedProtected = 0
        private set

    fun add(entry: ListEntry) {
        if (entry.includeSubdomains) {
            if (entry.domain in forbiddenWildcards) removedProtected++ else wildcard.add(entry.domain)
        } else {
            if (entry.domain in protectedExact) removedProtected++ else exact.add(entry.domain)
        }
    }

    /** Lignes du fichier final, triées. */
    fun buildLines(): List<String> {
        val keptWildcards = wildcard.filter { name ->
            DomainNames.parents(name).drop(1).none { it in wildcard }
        }.toHashSet()
        exact.sort()
        val lines = ArrayList<String>(keptWildcards.size + exact.size)
        keptWildcards.mapTo(lines) { "*.$it" }
        var previous: String? = null
        for (name in exact) {
            if (name == previous) continue
            previous = name
            if (DomainNames.parents(name).none { it in keptWildcards }) lines.add(name)
        }
        exact.clear()
        lines.sort()
        return lines
    }
}
