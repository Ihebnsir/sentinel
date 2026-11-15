package com.iheb.sentinel

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.FileNotFoundException
import java.io.IOException
import java.security.SecureRandom

/**
 * Partage d'un document du coffre SANS fichier en clair : l'app choisie
 * lit les octets gardés en mémoire, à travers un tube (pipe).
 * Non exporté : seule l'app à qui Android a accordé l'URI (partage
 * explicite de l'utilisateur) peut lire. Effacé au verrouillage du coffre.
 */
class VaultShareProvider : ContentProvider() {

    private class Shared(val token: String, val data: ByteArray, val mime: String, val name: String)

    companion object {
        @Volatile
        private var shared: Shared? = null

        private val random = SecureRandom()

        fun authority(context: Context) = "${context.packageName}.vaultshare"

        /** Met le document à disposition et renvoie son URI (jeton neuf). */
        fun offer(context: Context, data: ByteArray, mime: String): Uri {
            clear()
            val token = ByteArray(16).also(random::nextBytes).joinToString("") { "%02x".format(it) }
            val name = VaultMediaPolicy.shareName(mime)
            shared = Shared(token, data, mime, name)
            return Uri.Builder()
                .scheme("content")
                .authority(authority(context))
                .appendPath(token)
                .appendPath(name)
                .build()
        }

        /** Oublie le document partagé (octets remis à zéro). */
        fun clear() {
            shared?.data?.fill(0)
            shared = null
        }
    }

    private fun match(uri: Uri): Shared? {
        val current = shared ?: return null
        return if (uri.pathSegments.firstOrNull() == current.token) current else null
    }

    override fun onCreate() = true

    override fun getType(uri: Uri): String? = match(uri)?.mime

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? {
        val doc = match(uri) ?: return null
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cursor = MatrixCursor(columns)
        cursor.addRow(
            columns.map {
                when (it) {
                    OpenableColumns.DISPLAY_NAME -> doc.name
                    OpenableColumns.SIZE -> doc.data.size.toLong()
                    else -> null
                }
            },
        )
        return cursor
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("lecture seule")
        val doc = match(uri) ?: throw FileNotFoundException()
        val (read, write) = ParcelFileDescriptor.createPipe()
        // Écrit dans le tube depuis la mémoire ; rien sur le disque.
        Thread {
            try {
                ParcelFileDescriptor.AutoCloseOutputStream(write).use { it.write(doc.data) }
            } catch (e: IOException) {
                // L'app a fermé le tube avant la fin : rien à faire.
            }
        }.start()
        return read
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = 0

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
}
