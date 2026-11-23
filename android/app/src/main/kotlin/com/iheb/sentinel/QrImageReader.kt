package com.iheb.sentinel

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.IOException

/**
 * Lit les QR codes d'une image choisie (sélecteur de photos) ou partagée
 * avec Sentinel. L'image est lue en mémoire, décodée, puis oubliée :
 * jamais copiée, jamais enregistrée, jamais envoyée, jamais journalisée.
 * À appeler hors du thread principal.
 */
class QrImageReader(private val context: Context) {

    /** Réponse pour Dart : {"codes": [...]} ou {"error": "..."}. */
    fun read(uri: Uri): Map<String, Any> = try {
        mapOf("codes" to decode(uri))
    } catch (e: TooLargeException) {
        mapOf("error" to "TOO_LARGE")
    } catch (e: OutOfMemoryError) {
        mapOf("error" to "TOO_LARGE")
    } catch (e: IOException) {
        mapOf("error" to "FAILED")
    } catch (e: SecurityException) {
        mapOf("error" to "FAILED")
    } catch (e: IllegalArgumentException) {
        mapOf("error" to "FAILED")
    }

    private fun decode(uri: Uri): List<String> {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        open(uri).use { BitmapFactory.decodeStream(it, null, bounds) }
        val width = bounds.outWidth
        val height = bounds.outHeight
        if (width <= 0 || height <= 0) throw IOException("pas une image")
        if (width.toLong() * height > QrImageDecoder.MAX_PIXELS) throw TooLargeException()

        val first = decodeAt(uri, width, height, QrImageDecoder.MAX_SIDE)
        if (first.isNotEmpty() || maxOf(width, height) <= QrImageDecoder.MAX_SIDE) return first
        // Petit QR code dans une grande photo : un essai plus détaillé.
        return decodeAt(uri, width, height, QrImageDecoder.MAX_SIDE * 3 / 2)
    }

    private fun decodeAt(uri: Uri, width: Int, height: Int, maxSide: Int): List<String> {
        val options = BitmapFactory.Options().apply {
            inSampleSize = QrImageDecoder.sampleSize(width, height, maxSide)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val bitmap = open(uri).use { BitmapFactory.decodeStream(it, null, options) }
            ?: throw IOException("image illisible")
        try {
            val pixels = IntArray(bitmap.width * bitmap.height)
            bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
            return QrImageDecoder.decode(pixels, bitmap.width, bitmap.height)
        } finally {
            bitmap.recycle()
        }
    }

    private fun open(uri: Uri) =
        context.contentResolver.openInputStream(uri) ?: throw IOException("flux absent")

    private class TooLargeException : IOException()
}
