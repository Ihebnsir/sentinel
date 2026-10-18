package com.iheb.sentinel.firewall

import org.json.JSONArray
import org.json.JSONObject
import java.text.ParseException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Un fichier de catégorie décrit dans le manifeste. */
data class CategoryFile(
    val category: BlockCategory,
    val file: String,
    val entries: Int,
    val sha256: String,
)

/** Une source amont (pour la mise à jour et l'écran « Sources et licences »). */
data class BlocklistSource(
    val id: String,
    val name: String,
    val category: BlockCategory,
    val format: ListFormat,
    val subdomains: Boolean,
    val updateUrl: String,
    /** Entrées valides lors de la génération : sert de référence de cohérence. */
    val parsed: Int,
    val license: String,
    val licenseUrl: String,
    val homepage: String,
    val attribution: String,
)

/**
 * manifest.json : celui des assets (généré par update_lists.py) ou celui
 * du dossier privé (écrit par BlocklistUpdater, sans les sources).
 */
class BlocklistManifest(
    /** Date de génération, en millisecondes depuis 1970. */
    val generatedAt: Long,
    val categories: Map<BlockCategory, CategoryFile>,
    val sources: List<BlocklistSource>,
) {

    fun toJson(): String {
        val cats = JSONArray()
        for (file in categories.values) {
            cats.put(
                JSONObject()
                    .put("id", file.category.id)
                    .put("file", file.file)
                    .put("entries", file.entries)
                    .put("sha256", file.sha256),
            )
        }
        return JSONObject()
            .put("formatVersion", FORMAT_VERSION)
            .put("generatedAt", formatDate(generatedAt))
            .put("categories", cats)
            .toString(1)
    }

    companion object {
        const val FORMAT_VERSION = 1
        private val SHA256 = Regex("^[0-9a-f]{64}$")
        private val FILE_NAME = Regex("^[a-z0-9-]+\\.txt$")

        /** Lance une exception (JSONException, IllegalArgumentException) si invalide. */
        fun parse(json: String): BlocklistManifest {
            val root = JSONObject(json)
            require(root.getInt("formatVersion") == FORMAT_VERSION) { "Version inconnue" }
            val generatedAt = parseDate(root.getString("generatedAt"))

            val categories = mutableMapOf<BlockCategory, CategoryFile>()
            val cats = root.getJSONArray("categories")
            for (i in 0 until cats.length()) {
                val item = cats.getJSONObject(i)
                val category = BlockCategory.fromId(item.getString("id")) ?: continue
                val file = item.getString("file")
                val sha = item.getString("sha256").lowercase(Locale.ROOT)
                // Pas de « ../ » : le fichier reste dans le dossier des listes.
                require(FILE_NAME.matches(file)) { "Nom de fichier refusé" }
                require(SHA256.matches(sha)) { "SHA-256 invalide" }
                val entries = item.getInt("entries")
                require(entries >= 0) { "Nombre invalide" }
                categories[category] = CategoryFile(category, file, entries, sha)
            }

            val sources = mutableListOf<BlocklistSource>()
            val array = root.optJSONArray("sources") ?: JSONArray()
            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)
                val updateUrl = item.getString("updateUrl")
                require(updateUrl.startsWith("https://")) { "Adresse non HTTPS" }
                sources.add(
                    BlocklistSource(
                        id = item.getString("id"),
                        name = item.getString("name"),
                        category = BlockCategory.fromId(item.getString("category"))
                            ?: throw IllegalArgumentException("Catégorie inconnue"),
                        format = ListFormat.fromId(item.getString("format"))
                            ?: throw IllegalArgumentException("Format inconnu"),
                        subdomains = item.getBoolean("subdomains"),
                        updateUrl = updateUrl,
                        parsed = item.getInt("parsed"),
                        license = item.getString("license"),
                        licenseUrl = item.getString("licenseUrl"),
                        homepage = item.getString("homepage"),
                        attribution = item.getString("attribution"),
                    ),
                )
            }
            return BlocklistManifest(generatedAt, categories, sources)
        }

        private fun dateFormat() = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.ROOT)
            .apply { timeZone = TimeZone.getTimeZone("UTC") }

        fun parseDate(text: String): Long = try {
            dateFormat().parse(text)?.time ?: throw IllegalArgumentException("Date invalide")
        } catch (e: ParseException) {
            throw IllegalArgumentException("Date invalide", e)
        }

        fun formatDate(millis: Long): String = dateFormat().format(Date(millis))
    }
}
