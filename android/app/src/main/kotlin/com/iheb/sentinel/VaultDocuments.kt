package com.iheb.sentinel

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.Executors

/**
 * Sauvegarde chiffrée du coffre : enregistrer / ouvrir un fichier avec le
 * sélecteur d'Android (Storage Access Framework). L'utilisateur choisit
 * l'emplacement ; l'app n'a besoin d'aucune permission de stockage.
 * Le contenu est déjà chiffré par Dart ; jamais journalisé.
 */
class VaultDocuments(private val activity: Activity) {

    // Lecture et écriture hors du thread principal (Drive, carte SD…).
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    // Une seule demande à la fois.
    private var pending: MethodChannel.Result? = null
    private var pendingData: ByteArray? = null
    private var pendingMaxBytes = 0

    fun dispose() {
        finish { it.success(null) }
        io.shutdown()
    }

    fun save(name: String, data: ByteArray, result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            // Pas de type MIME pour .sentinel : octets bruts.
            .setType("application/octet-stream")
            .putExtra(Intent.EXTRA_TITLE, name)
        if (start(intent, REQUEST_SAVE, result)) pendingData = data
    }

    fun open(maxBytes: Int, result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
        if (start(intent, REQUEST_OPEN, result)) pendingMaxBytes = maxBytes
    }

    /** true si la réponse était pour nous. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_OPEN) return false
        val result = pending ?: return true
        val bytes = pendingData
        val maxBytes = pendingMaxBytes
        pending = null
        pendingData = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            // Annulé par l'utilisateur.
            result.success(if (requestCode == REQUEST_SAVE) false else null)
            return true
        }
        io.execute {
            try {
                if (requestCode == REQUEST_SAVE) {
                    write(uri, bytes ?: ByteArray(0))
                    main.post { result.success(true) }
                } else {
                    val read = read(uri, maxBytes)
                    main.post { result.success(read) }
                }
            } catch (e: TooLargeException) {
                main.post { result.error("TROP_GROS", null, null) }
            } catch (e: IOException) {
                main.post { result.error("ECHEC", null, null) }
            } catch (e: SecurityException) {
                main.post { result.error("ECHEC", null, null) }
            } catch (e: IllegalArgumentException) {
                main.post { result.error("ECHEC", null, null) }
            }
        }
        return true
    }

    private fun start(intent: Intent, requestCode: Int, result: MethodChannel.Result): Boolean {
        finish { it.success(null) } // demande précédente sans réponse
        return try {
            pending = result
            activity.startActivityForResult(intent, requestCode)
            true
        } catch (e: ActivityNotFoundException) {
            pending = null
            result.error("INDISPONIBLE", null, null)
            false
        }
    }

    private fun finish(answer: (MethodChannel.Result) -> Unit) {
        val result = pending ?: return
        pending = null
        pendingData = null
        answer(result)
    }

    // "wt" : remplace le contenu si l'utilisateur choisit un fichier existant.
    private fun write(uri: Uri, bytes: ByteArray) {
        val stream = activity.contentResolver.openOutputStream(uri, "wt")
            ?: throw IOException("flux absent")
        stream.use { it.write(bytes) }
    }

    // Lit au plus maxBytes octets : un énorme fichier ne remplit pas la mémoire.
    private fun read(uri: Uri, maxBytes: Int): ByteArray {
        val stream = activity.contentResolver.openInputStream(uri)
            ?: throw IOException("flux absent")
        stream.use { input ->
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                if (out.size() + n > maxBytes) throw TooLargeException()
                out.write(buffer, 0, n)
            }
            return out.toByteArray()
        }
    }

    private class TooLargeException : IOException()

    companion object {
        // 1 : notifications (MainActivity), 2 : VPN (FirewallChannel).
        private const val REQUEST_SAVE = 3
        private const val REQUEST_OPEN = 4
    }
}
