package com.iheb.sentinel.firewall

import com.iheb.sentinel.firewall.CategoryList.Companion.toHex
import java.io.BufferedReader
import java.io.File
import java.io.FileOutputStream
import java.io.FilterInputStream
import java.io.IOException
import java.io.InputStream
import java.io.InputStreamReader
import java.net.URL
import java.security.MessageDigest
import javax.net.ssl.HttpsURLConnection

/** Ouvre une adresse en lecture (remplacé par un faux dans les tests). */
fun interface Fetcher {
    fun open(url: String): InputStream
}

/**
 * Met à jour les listes dans le dossier privé de l'app.
 *
 * Sécurité :
 * - les adresses viennent du manifeste DES ASSETS (signé avec l'APK),
 *   jamais d'un fichier téléchargé ;
 * - HTTPS uniquement, taille maximale par source ;
 * - chaque source doit ressembler à la précédente (au moins la moitié des
 *   entrées, au plus 5 fois plus, moins de 10 % de lignes invalides) ;
 * - les domaines protégés sont retirés ;
 * - écriture atomique : nouveaux fichiers d'abord, puis le manifeste
 *   d'un coup. En cas d'échec, l'ancienne version reste en place.
 * Aucune donnée de l'utilisateur n'est envoyée : de simples GET sans
 * paramètres ni cookies.
 */
class BlocklistUpdater(
    private val dir: File,
    private val bundled: BlocklistManifest,
    private val protectedDomains: Set<String>,
    private val fetcher: Fetcher = HttpsFetcher,
    private val clock: () -> Long = System::currentTimeMillis,
) {

    class Result(val updated: Set<BlockCategory>, val failed: Set<BlockCategory>) {
        val success: Boolean get() = failed.isEmpty() && updated.isNotEmpty()
    }

    /** Le manifeste privé, ou null s'il n'existe pas ou est illisible. */
    fun readLocalManifest(): BlocklistManifest? {
        val file = File(dir, MANIFEST)
        if (!file.isFile) return null
        return try {
            BlocklistManifest.parse(file.readText(Charsets.UTF_8))
        } catch (e: Exception) {
            null
        }
    }

    fun update(categories: Set<BlockCategory>): Result {
        if (!dir.isDirectory && !dir.mkdirs()) return Result(emptySet(), categories)
        val now = clock()
        val previous = readLocalManifest()
        val files = previous?.categories?.toMutableMap() ?: mutableMapOf()
        val updated = mutableSetOf<BlockCategory>()
        val failed = mutableSetOf<BlockCategory>()

        for (category in categories) {
            val result = try {
                downloadCategory(category, now)
            } catch (e: Exception) {
                null // réseau, taille, format, cohérence… : on garde l'ancienne
            }
            if (result == null) {
                failed.add(category)
            } else {
                files[category] = result
                updated.add(category)
            }
        }

        if (updated.isNotEmpty()) {
            try {
                writeAtomically(File(dir, MANIFEST)) { out ->
                    out.write(BlocklistManifest(now, files, emptyList()).toJson().toByteArray())
                }
            } catch (e: IOException) {
                // Le manifeste n'a pas changé : les anciens fichiers restent valables.
                deleteUnreferenced(previous?.categories?.values?.map { it.file }.orEmpty())
                return Result(emptySet(), categories)
            }
        }
        deleteUnreferenced(files.values.map { it.file })
        return Result(updated, failed)
    }

    private fun downloadCategory(category: BlockCategory, now: Long): CategoryFile? {
        val sources = bundled.sources.filter { it.category == category }
        if (sources.isEmpty()) return null
        val builder = CategoryBuilder(protectedDomains)
        for (source in sources) {
            var count = 0
            var invalid = 0
            fetcher.open(source.updateUrl).use { raw ->
                val limited = LimitedInputStream(raw, MAX_SOURCE_BYTES)
                val reader = BufferedReader(InputStreamReader(limited, Charsets.UTF_8))
                val sink = ArrayList<ListEntry>(1)
                reader.forEachLine { line ->
                    if (!ListParser.parseLine(line, source.format, source.subdomains, sink)) invalid++
                    for (entry in sink) builder.add(entry)
                    count += sink.size
                    sink.clear()
                }
            }
            if (!isConsistent(count, invalid, source.parsed)) return null
        }
        val lines = builder.buildLines()
        if (lines.isEmpty() || lines.size > MAX_CATEGORY_ENTRIES) return null

        val name = "${category.id}-$now.txt"
        val digest = MessageDigest.getInstance("SHA-256")
        writeAtomically(File(dir, name)) { out ->
            val buffered = out.buffered()
            for (line in lines) {
                val bytes = (line + "\n").toByteArray(Charsets.US_ASCII)
                digest.update(bytes)
                buffered.write(bytes)
            }
            buffered.flush()
        }
        return CategoryFile(category, name, lines.size, digest.digest().toHex())
    }

    private fun deleteUnreferenced(keep: Collection<String>) {
        dir.listFiles()?.forEach { file ->
            if (file.name != MANIFEST && file.name !in keep) file.delete()
        }
    }

    companion object {
        const val MANIFEST = "manifest.json"
        const val MAX_SOURCE_BYTES = 32L * 1024 * 1024
        const val MAX_CATEGORY_ENTRIES = 2_000_000
        const val MAX_INVALID_RATIO = 0.10

        /** La nouvelle version ressemble-t-elle à celle de référence ? */
        fun isConsistent(count: Int, invalid: Int, reference: Int): Boolean {
            if (count == 0) return false
            if (invalid.toDouble() / (count + invalid) > MAX_INVALID_RATIO) return false
            if (reference > 0 && count < reference / 2) return false // liste vidée ou tronquée
            if (reference > 0 && count > reference.toLong() * 5) return false // liste gonflée
            return true
        }

        /**
         * Écrit dans un fichier temporaire, force l'écriture sur le disque,
         * puis renomme : le fichier final est soit l'ancien, soit le
         * nouveau complet, jamais à moitié écrit.
         */
        fun writeAtomically(target: File, write: (FileOutputStream) -> Unit) {
            val temp = File(target.parentFile, target.name + ".tmp")
            try {
                FileOutputStream(temp).use { out ->
                    write(out)
                    out.flush()
                    out.fd.sync()
                }
                // Sur Android (Linux), renameTo remplace atomiquement. La
                // seconde tentative ne sert que sous Windows (tests JVM).
                if (!temp.renameTo(target)) {
                    target.delete()
                    if (!temp.renameTo(target)) throw IOException("Renommage impossible")
                }
            } finally {
                temp.delete()
            }
        }
    }
}

/** Lance une IOException dès que plus de [max] octets ont été lus. */
class LimitedInputStream(input: InputStream, private val max: Long) : FilterInputStream(input) {
    private var count = 0L

    override fun read(): Int {
        val b = super.read()
        if (b >= 0) check(1)
        return b
    }

    override fun read(b: ByteArray, off: Int, len: Int): Int {
        val n = super.read(b, off, len)
        if (n > 0) check(n.toLong())
        return n
    }

    private fun check(n: Long) {
        count += n
        if (count > max) throw IOException("Fichier trop gros")
    }
}

/** Téléchargement HTTPS simple : pas de cookies, pas de paramètres. */
object HttpsFetcher : Fetcher {
    override fun open(url: String): InputStream {
        require(url.startsWith("https://")) { "HTTPS obligatoire" }
        val connection = URL(url).openConnection() as HttpsURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 30_000
        connection.useCaches = false
        // Les redirections HTTPS → HTTP ne sont jamais suivies par Java.
        connection.instanceFollowRedirects = true
        connection.setRequestProperty("User-Agent", "Sentinel")
        try {
            val code = connection.responseCode
            if (code != HttpsURLConnection.HTTP_OK) throw IOException("HTTP $code")
            if (connection.contentLengthLong > BlocklistUpdater.MAX_SOURCE_BYTES) {
                throw IOException("Fichier trop gros")
            }
            return object : FilterInputStream(connection.inputStream) {
                override fun close() {
                    try {
                        super.close()
                    } finally {
                        connection.disconnect()
                    }
                }
            }
        } catch (e: Exception) {
            connection.disconnect()
            throw e
        }
    }
}
