package com.iheb.sentinel

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import androidx.annotation.RequiresApi
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.Executors

/**
 * Documents du coffre : photo (appareil photo d'Android), image ou PDF
 * choisi avec le sélecteur (aucune permission de stockage), aperçu des
 * PDF et partage. Tout reste en mémoire et retourne chiffré par Dart.
 * Seule exception : la photo, que l'appareil photo écrit dans
 * cache/vault_capture ; elle est lue puis effacée aussitôt (et ce dossier
 * est vidé à chaque démarrage). Rien n'est journalisé.
 */
class VaultMedia(private val activity: Activity) {

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    // Une seule demande à la fois.
    private var pending: MethodChannel.Result? = null
    private var pendingMaxBytes = 0

    // PDF ouvert pour l'aperçu (un seul à la fois, utilisé sur io).
    private var pdf: PdfRenderer? = null
    private var pdfFd: ParcelFileDescriptor? = null

    private val captureDir get() = File(activity.cacheDir, "vault_capture")

    init {
        io.execute { clearCaptureDir() } // photo restée après un arrêt brutal
    }

    fun dispose() {
        finish { it.success(null) }
        io.execute {
            closePdf()
            clearCaptureDir()
        }
        io.shutdown()
        VaultShareProvider.clear()
    }

    // -----------------------------------------------------------------
    // Photo
    // -----------------------------------------------------------------

    fun capture(maxBytes: Int, result: MethodChannel.Result) {
        if (!activity.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
            return result.error("NO_CAMERA", null, null)
        }
        finish { it.success(null) }
        pending = result
        pendingMaxBytes = maxBytes
        // Caméra déclarée dans le manifeste (QR) : Android exige alors
        // l'autorisation, même pour l'appareil photo d'une autre app.
        if (activity.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            launchCamera()
        } else {
            activity.requestPermissions(arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA)
        }
    }

    private fun captureUri(): Uri {
        val dir = captureDir.apply { mkdirs() }
        val photo = File(dir, "photo.jpg")
        photo.delete()
        return FileProvider.getUriForFile(activity, "${activity.packageName}.vaultcapture", photo)
    }

    private fun launchCamera() {
        try {
            val uri = captureUri()
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                .putExtra(MediaStore.EXTRA_OUTPUT, uri)
                .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            intent.clipData = ClipData.newRawUri("", uri)
            activity.startActivityForResult(intent, REQUEST_CAPTURE)
        } catch (e: ActivityNotFoundException) {
            finish { it.error("NO_CAMERA", null, null) }
        } catch (e: IllegalArgumentException) {
            finish { it.error("ECHEC", null, null) }
        }
    }

    /** true si la réponse était pour nous. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CAMERA) return false
        if (pending == null) return true
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            launchCamera()
        } else {
            val blocked = !activity.shouldShowRequestPermissionRationale(Manifest.permission.CAMERA)
            finish { it.error(if (blocked) "PERMISSION_BLOCKED" else "PERMISSION_DENIED", null, null) }
        }
        return true
    }

    // -----------------------------------------------------------------
    // Sélecteur (image ou PDF)
    // -----------------------------------------------------------------

    fun pick(maxBytes: Int, result: MethodChannel.Result) {
        finish { it.success(null) }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
            .putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "application/pdf"))
        try {
            pending = result
            pendingMaxBytes = maxBytes
            activity.startActivityForResult(intent, REQUEST_PICK)
        } catch (e: ActivityNotFoundException) {
            finish { it.error("INDISPONIBLE", null, null) }
        }
    }

    /** true si la réponse était pour nous. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CAPTURE && requestCode != REQUEST_PICK) return false
        val result = pending
        pending = null
        val maxBytes = pendingMaxBytes
        val uri = data?.data
        if (result == null || resultCode != Activity.RESULT_OK || (requestCode == REQUEST_PICK && uri == null)) {
            io.execute { clearCaptureDir() }
            result?.success(null) // annulé
            return true
        }
        io.execute {
            val answer: Any? = try {
                if (requestCode == REQUEST_CAPTURE) {
                    val photo = File(captureDir, "photo.jpg")
                    val bytes = photo.inputStream().use { readLimited(it, VaultMediaPolicy.RAW_IMAGE_LIMIT) }
                    mapOf("data" to shrinkImage(bytes, maxBytes), "name" to null)
                } else {
                    readPicked(uri!!, maxBytes)
                }
            } catch (e: TooLargeException) {
                "TROP_GROS"
            } catch (e: UnsupportedTypeException) {
                "TYPE"
            } catch (e: IOException) {
                "ECHEC"
            } catch (e: SecurityException) {
                "ECHEC"
            } catch (e: IllegalArgumentException) {
                "ECHEC"
            } catch (e: OutOfMemoryError) {
                "TROP_GROS"
            } finally {
                clearCaptureDir() // la photo en clair ne reste jamais
            }
            main.post {
                if (answer is String) result.error(answer, null, null) else result.success(answer)
            }
        }
        return true
    }

    private fun readPicked(uri: Uri, maxBytes: Int): Map<String, Any?> {
        val resolver = activity.contentResolver
        val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        }
        val stream = resolver.openInputStream(uri) ?: throw IOException("flux absent")
        val bytes = stream.use { readLimited(it, VaultMediaPolicy.RAW_IMAGE_LIMIT) }
        val data = if (VaultMediaPolicy.isPdf(bytes)) {
            if (bytes.size > maxBytes) throw TooLargeException()
            bytes
        } else {
            shrinkImage(bytes, maxBytes)
        }
        return mapOf("data" to data, "name" to name)
    }

    // Lit au plus limit octets : un énorme fichier ne remplit pas la mémoire.
    private fun readLimited(input: InputStream, limit: Int): ByteArray {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val n = input.read(buffer)
            if (n < 0) break
            if (out.size() + n > limit) throw TooLargeException()
            out.write(buffer, 0, n)
        }
        return out.toByteArray()
    }

    // -----------------------------------------------------------------
    // Recompression des images
    // -----------------------------------------------------------------

    // Image gardée telle quelle si légère ; sinon réduite (2560 px), tournée
    // selon l'EXIF et réenregistrée en JPEG (métadonnées, dont GPS, perdues).
    private fun shrinkImage(bytes: ByteArray, maxBytes: Int): ByteArray {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        val width = bounds.outWidth
        val height = bounds.outHeight
        if (width <= 0 || height <= 0) throw UnsupportedTypeException()
        if (VaultMediaPolicy.keepsOriginal(bounds.outMimeType, bytes.size, width, height)) return bytes

        val options = BitmapFactory.Options().apply {
            inSampleSize = VaultMediaPolicy.sampleSize(width, height)
        }
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
            ?: throw UnsupportedTypeException()
        val matrix = Matrix()
        val scale = VaultMediaPolicy.fitScale(decoded.width, decoded.height)
        matrix.postScale(scale, scale)
        matrix.postRotate(exifRotation(bytes).toFloat())
        val turned = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        if (turned !== decoded) decoded.recycle()

        // Fond blanc : la transparence d'un PNG deviendrait noire en JPEG.
        val flat = Bitmap.createBitmap(turned.width, turned.height, Bitmap.Config.ARGB_8888)
        Canvas(flat).apply {
            drawColor(Color.WHITE)
            drawBitmap(turned, 0f, 0f, null)
        }
        turned.recycle()
        try {
            for (quality in intArrayOf(85, 70, 55)) {
                val out = ByteArrayOutputStream()
                flat.compress(Bitmap.CompressFormat.JPEG, quality, out)
                if (out.size() <= maxBytes) return out.toByteArray()
            }
        } finally {
            flat.recycle()
        }
        throw TooLargeException()
    }

    private fun exifRotation(bytes: ByteArray): Int = try {
        when (ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        )) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90
            ExifInterface.ORIENTATION_ROTATE_180 -> 180
            ExifInterface.ORIENTATION_ROTATE_270 -> 270
            else -> 0
        }
    } catch (e: IOException) {
        0
    }

    // -----------------------------------------------------------------
    // Aperçu des PDF (en mémoire : memfd, Android 11+)
    // -----------------------------------------------------------------

    fun pdfOpen(data: ByteArray, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            // Avant Android 11, PdfRenderer exigerait un vrai fichier.
            return result.error("INDISPONIBLE", null, null)
        }
        io.execute {
            val answer: Any = try {
                closePdf()
                val fd = memoryFile(data)
                pdfFd = fd
                val renderer = PdfRenderer(fd)
                pdf = renderer
                renderer.pageCount
            } catch (e: IOException) {
                closePdf()
                "ECHEC"
            } catch (e: SecurityException) {
                closePdf() // PDF protégé par mot de passe
                "ECHEC"
            } catch (e: ErrnoException) {
                closePdf()
                "ECHEC"
            }
            main.post { if (answer is String) result.error(answer, null, null) else result.success(answer) }
        }
    }

    fun pdfPage(index: Int, width: Int, result: MethodChannel.Result) {
        io.execute {
            val answer: Any = try {
                val renderer = pdf ?: throw IOException("aucun PDF")
                if (index !in 0 until renderer.pageCount) throw IOException("page")
                renderer.openPage(index).use { page ->
                    val w = VaultMediaPolicy.pdfWidth(width)
                    val h = (w.toLong() * page.height / maxOf(page.width, 1)).toInt().coerceIn(1, w * 4)
                    val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                    bitmap.eraseColor(Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    val out = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                    bitmap.recycle()
                    out.toByteArray()
                }
            } catch (e: IOException) {
                "ECHEC"
            } catch (e: IllegalStateException) {
                "ECHEC"
            } catch (e: OutOfMemoryError) {
                "ECHEC"
            }
            main.post { if (answer is String) result.error(answer, null, null) else result.success(answer) }
        }
    }

    fun pdfClose() {
        io.execute { closePdf() }
    }

    private fun closePdf() {
        try {
            pdf?.close()
        } catch (e: IllegalStateException) {
            // déjà fermé
        }
        pdf = null
        try {
            pdfFd?.close()
        } catch (e: IOException) {
            // déjà fermé
        }
        pdfFd = null
    }

    // Fichier anonyme en mémoire (memfd) : lisible comme un fichier par
    // PdfRenderer, sans jamais toucher le disque.
    @RequiresApi(Build.VERSION_CODES.R)
    private fun memoryFile(data: ByteArray): ParcelFileDescriptor {
        val fd = Os.memfd_create("sentinel-document", 0)
        try {
            var offset = 0
            while (offset < data.size) {
                offset += Os.write(fd, data, offset, data.size - offset)
            }
            Os.lseek(fd, 0, OsConstants.SEEK_SET)
            return ParcelFileDescriptor.dup(fd)
        } finally {
            Os.close(fd)
        }
    }

    // -----------------------------------------------------------------
    // Partage (choisi par l'utilisateur, après avertissement)
    // -----------------------------------------------------------------

    fun share(data: ByteArray, mime: String, result: MethodChannel.Result) {
        val uri = VaultShareProvider.offer(activity, data, mime)
        val send = Intent(Intent.ACTION_SEND)
            .setType(mime)
            .putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        send.clipData = ClipData.newRawUri("", uri)
        try {
            activity.startActivity(Intent.createChooser(send, null))
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            VaultShareProvider.clear()
            result.error("INDISPONIBLE", null, null)
        }
    }

    fun clearShared() = VaultShareProvider.clear()

    // -----------------------------------------------------------------

    private fun clearCaptureDir() {
        captureDir.listFiles()?.forEach { it.delete() }
    }

    private fun finish(answer: (MethodChannel.Result) -> Unit) {
        val result = pending ?: return
        pending = null
        answer(result)
    }

    private class TooLargeException : IOException()
    private class UnsupportedTypeException : Exception()

    companion object {
        // Différents des autres demandes (1 à 6 : MainActivity,
        // FirewallChannel, VaultDocuments, QrScanner).
        private const val REQUEST_CAPTURE = 7
        private const val REQUEST_PICK = 8
        private const val REQUEST_CAMERA = 9
    }
}
