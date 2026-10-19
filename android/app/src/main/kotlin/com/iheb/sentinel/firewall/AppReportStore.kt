package com.iheb.sentinel.firewall

import java.io.File
import java.io.IOException

/**
 * Rapports d'analyse dans le stockage privé de l'app (exclu des
 * sauvegardes Android : allowBackup="false"). Chaque rapport est supprimé
 * 24 h après la fin de l'analyse. Jamais envoyé nulle part.
 * Sans Android : testable avec JUnit (dossier et horloge injectés).
 */
class AppReportStore(
    private val dir: File,
    private val clock: () -> Long = System::currentTimeMillis,
) {

    /** Enregistre le rapport [json] (fin d'analyse [endedAt]). */
    fun save(id: String, endedAt: Long, json: String) {
        require(ID.matches(id)) { "Identifiant refusé" }
        if (!dir.isDirectory && !dir.mkdirs()) throw IOException("Dossier impossible à créer")
        purgeExpired()
        // Nom = « fin d'analyse - identifiant » : l'expiration se lit sans ouvrir le fichier.
        val file = File(dir, "$endedAt-$id$SUFFIX")
        val tmp = File(dir, file.name + ".tmp")
        tmp.writeText(json, Charsets.UTF_8)
        if (!tmp.renameTo(file)) {
            tmp.delete()
            throw IOException("Écriture impossible")
        }
        // Au plus MAX_REPORTS : les plus anciens partent d'abord.
        val all = reportFiles().sortedByDescending { it.endedAt }
        all.drop(MAX_REPORTS).forEach { it.file.delete() }
    }

    /** Rapports encore valides (JSON), les plus récents d'abord. */
    fun list(): List<String> {
        purgeExpired()
        return reportFiles()
            .sortedByDescending { it.endedAt }
            .mapNotNull { entry ->
                try {
                    entry.file.readText(Charsets.UTF_8)
                } catch (e: IOException) {
                    null
                }
            }
    }

    fun delete(id: String) {
        if (!ID.matches(id)) return // pas de « ../ »
        reportFiles().filter { it.id == id }.forEach { it.file.delete() }
    }

    /** Supprime les rapports de plus de 24 h (et les fichiers inconnus). */
    fun purgeExpired() {
        val now = clock()
        val files = dir.listFiles() ?: return
        for (file in files) {
            val entry = parseName(file)
            if (entry == null || isExpired(entry.endedAt, now)) file.delete()
        }
    }

    /** Prochaine expiration (ms), ou null s'il n'y a aucun rapport. */
    fun nextExpiry(): Long? = reportFiles().minOfOrNull { it.endedAt + MAX_AGE_MS }

    private class Entry(val file: File, val endedAt: Long, val id: String)

    private fun reportFiles(): List<Entry> =
        dir.listFiles()?.mapNotNull(::parseName).orEmpty()

    private fun parseName(file: File): Entry? {
        val match = NAME.matchEntire(file.name) ?: return null
        val endedAt = match.groupValues[1].toLongOrNull() ?: return null
        return Entry(file, endedAt, match.groupValues[2])
    }

    companion object {
        const val MAX_AGE_MS = 24 * 60 * 60 * 1000L
        const val MAX_REPORTS = 10
        private const val SUFFIX = ".json"
        private val ID = Regex("^[0-9]{1,19}$")
        private val NAME = Regex("^([0-9]{1,19})-([0-9]{1,19})\\.json$")

        /** Vrai si un rapport terminé à [endedAt] doit être supprimé à [now]. */
        fun isExpired(endedAt: Long, now: Long): Boolean =
            now - endedAt >= MAX_AGE_MS || endedAt > now + MAX_AGE_MS // horloge reculée
    }
}
