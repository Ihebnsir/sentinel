package com.iheb.sentinel.firewall

import java.io.BufferedReader

/** Formats de listes reconnus. */
enum class ListFormat(val id: String) {
    /** « 0.0.0.0 domaine » (fichier hosts). */
    HOSTS("hosts"),

    /** Un domaine par ligne ; « *.domaine » inclut les sous-domaines. */
    DOMAINS("domains"),

    /** « ||domaine^ » (syntaxe Adblock) : toujours avec les sous-domaines. */
    ADBLOCK("adblock");

    companion object {
        fun fromId(id: String): ListFormat? = entries.firstOrNull { it.id == id }
    }
}

/** Une entrée de liste : un domaine, avec ou sans ses sous-domaines. */
data class ListEntry(val domain: String, val includeSubdomains: Boolean)

/** Résultat de l'analyse d'une liste entière. */
class ParseResult(val entries: List<ListEntry>, val invalidLines: Int) {
    /** Part des lignes utiles qui étaient invalides (0.0 à 1.0). */
    val invalidRatio: Double
        get() {
            val total = entries.size + invalidLines
            return if (total == 0) 0.0 else invalidLines.toDouble() / total
        }
}

/** Lit les listes de blocage (même logique que tools/blocklists/update_lists.py). */
object ListParser {

    private val HOSTS_IPS = setOf(
        "0.0.0.0", "127.0.0.1", "::", "::1", "0:0:0:0:0:0:0:0", "0:0:0:0:0:0:0:1",
    )

    // Noms locaux des fichiers hosts : ni utiles ni « invalides ».
    private val LOCAL_HOSTS = setOf(
        "localhost", "broadcasthost", "local", "ip6-localhost", "ip6-loopback",
    )

    private val ADBLOCK_RULE = Regex("""^\|\|([^\^$/|*]+)\^(\${'$'}important)?$""")

    fun parse(reader: BufferedReader, format: ListFormat, plainSubdomains: Boolean): ParseResult {
        val entries = ArrayList<ListEntry>()
        var invalid = 0
        reader.forEachLine { line ->
            if (!parseLine(line, format, plainSubdomains, entries)) invalid++
        }
        return ParseResult(entries, invalid)
    }

    /**
     * Ajoute à [out] les entrées de [line]. Renvoie false si la ligne est
     * invalide (les commentaires et règles non DNS ne le sont pas).
     */
    fun parseLine(
        line: String,
        format: ListFormat,
        plainSubdomains: Boolean,
        out: MutableList<ListEntry>,
    ): Boolean {
        val trimmed = line.trim()
        if (format == ListFormat.ADBLOCK) {
            if (trimmed.isEmpty() || trimmed[0] in "!#[") return true
            // Règle cosmétique, exception, chemin… : ignorée, pas invalide.
            val match = ADBLOCK_RULE.matchEntire(trimmed) ?: return true
            val name = DomainNames.normalize(match.groupValues[1]) ?: return false
            out.add(ListEntry(name, includeSubdomains = true))
            return true
        }

        val content = trimmed.substringBefore('#').trim()
        if (content.isEmpty()) return true
        val parts = content.split(Regex("\\s+"))
        val names = if (format == ListFormat.HOSTS) {
            if (parts.size < 2 || parts[0] !in HOSTS_IPS) return false
            parts.drop(1)
        } else {
            if (parts.size != 1) return false
            parts
        }
        var valid = true
        for (raw in names) {
            val wildcard = raw.startsWith("*.")
            val name = DomainNames.normalize(if (wildcard) raw.substring(2) else raw)
            if (name == null) {
                if (raw !in LOCAL_HOSTS) valid = false
                continue
            }
            out.add(ListEntry(name, plainSubdomains || wildcard))
        }
        return valid
    }
}
