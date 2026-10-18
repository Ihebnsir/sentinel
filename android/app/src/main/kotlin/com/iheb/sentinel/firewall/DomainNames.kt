package com.iheb.sentinel.firewall

import java.net.IDN
import java.util.Locale

/** Normalisation et validation des noms de domaine (même règles que update_lists.py). */
object DomainNames {

    private const val MAX_LENGTH = 253
    private const val MAX_LABEL = 63
    private val LOCAL_NAMES = setOf("localhost.localdomain", "local.localdomain")

    /**
     * Minuscules, punycode (« café.fr » → « xn--caf-dma.fr »), sans point
     * final. null si ce n'est pas un nom de domaine valide (IP, un seul
     * label, caractère interdit…).
     */
    fun normalize(raw: String): String? {
        var name = raw.trim().trimEnd('.').lowercase(Locale.ROOT)
        if (name.isEmpty()) return null
        if (name.any { it.code > 127 }) {
            name = try {
                // IDNA 2003, comme le codec « idna » de Python.
                IDN.toASCII(name, IDN.ALLOW_UNASSIGNED).lowercase(Locale.ROOT)
            } catch (e: IllegalArgumentException) {
                return null
            }
        }
        return if (isValidAscii(name)) name else null
    }

    /**
     * Vrai si [name] est déjà normalisé et valide : au moins deux labels de
     * 1 à 63 caractères (lettres, chiffres, « _ », « - » sauf au début et à
     * la fin), dernier label pas entièrement numérique (sinon c'est une IP).
     * Une seule passe, sans créer d'objets : appelée pour chaque ligne lue.
     */
    fun isValidAscii(name: String): Boolean {
        if (name.isEmpty() || name.length > MAX_LENGTH || name in LOCAL_NAMES) return false
        var labelStart = 0
        var labels = 0
        var allDigits = true
        for (i in 0..name.length) {
            val c = if (i < name.length) name[i] else '.'
            if (c == '.') {
                val length = i - labelStart
                if (length == 0 || length > MAX_LABEL) return false
                if (name[labelStart] == '-' || name[i - 1] == '-') return false
                labels++
                if (i < name.length) allDigits = true
                labelStart = i + 1
                continue
            }
            val ok = c in 'a'..'z' || c in '0'..'9' || c == '-' || c == '_'
            if (!ok) return false
            if (c !in '0'..'9') allDigits = false
        }
        return labels >= 2 && !allDigits
    }

    /** « a.b.c » → [a.b.c, b.c, c]. */
    fun parents(name: String): List<String> {
        val result = mutableListOf(name)
        var dot = name.indexOf('.')
        while (dot >= 0) {
            result.add(name.substring(dot + 1))
            dot = name.indexOf('.', dot + 1)
        }
        return result
    }

    /** « site.xyz » → « site[.]xyz » : Android n'en fait pas un lien cliquable. */
    fun defang(name: String): String = name.replace(".", "[.]")
}
