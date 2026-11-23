package com.iheb.sentinel

import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.EncodeHintType
import com.google.zxing.LuminanceSource
import com.google.zxing.ReaderException
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.Result
import com.google.zxing.InvertedLuminanceSource
import com.google.zxing.WriterException
import com.google.zxing.common.GlobalHistogramBinarizer
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.multi.GenericMultipleBarcodeReader
import com.google.zxing.multi.qrcode.QRCodeMultiReader
import com.google.zxing.qrcode.QRCodeReader
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel

/**
 * Lecture et création de QR codes avec ZXing (même bibliothèque que la
 * caméra), entièrement sur le téléphone. Fonctions pures, sans Android :
 * testées sur ordinateur avec des images PNG (QrImageDecoderTest).
 */
object QrImageDecoder {

    // Au-delà, la liste n'aurait plus de sens à l'écran.
    const val MAX_CODES = 10

    // Côté le plus long de l'image décodée, en pixels (mémoire limitée).
    const val MAX_SIDE = 2048

    // Image annoncée plus grande que ça : refusée sans être lue.
    const val MAX_PIXELS = 100_000_000L

    // Texte du QR Wi-Fi : un réseau et un mot de passe tiennent largement.
    const val MAX_ENCODE_LENGTH = 512

    private val hints = mapOf(
        DecodeHintType.TRY_HARDER to true,
        DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.QR_CODE),
    )

    /**
     * Tous les QR codes de l'image (pixels ARGB), sans doublon, dans
     * l'ordre trouvé. Liste vide : aucun QR code.
     */
    fun decode(pixels: IntArray, width: Int, height: Int): List<String> {
        if (width <= 0 || height <= 0 || pixels.size < width.toLong() * height) return emptyList()
        val source = RGBLuminanceSource(width, height, pixels)
        val found = LinkedHashSet<String>()
        // Image normale, puis inversée (QR clair sur fond sombre).
        for (luminance in listOf<LuminanceSource>(source, InvertedLuminanceSource(source))) {
            for (bitmap in listOf(
                BinaryBitmap(HybridBinarizer(luminance)),
                BinaryBitmap(GlobalHistogramBinarizer(luminance)),
            )) {
                readAll(bitmap).forEach { if (found.size < MAX_CODES) found.add(it.text) }
            }
            if (found.isNotEmpty()) break
        }
        return found.toList()
    }

    // Plusieurs lecteurs : chacun trouve des cas que l'autre rate.
    private fun readAll(bitmap: BinaryBitmap): List<Result> {
        val results = mutableListOf<Result>()
        try {
            results += QRCodeMultiReader().decodeMultiple(bitmap, hints)
        } catch (e: ReaderException) {
            // Aucun : on essaie les autres lecteurs.
        }
        try {
            results += GenericMultipleBarcodeReader(QRCodeReader()).decodeMultiple(bitmap, hints)
        } catch (e: ReaderException) {
            // Idem.
        }
        return results.filter { it.text != null }
    }

    /** Divise l'image par 2, 4, 8… pour que son grand côté tienne dans [maxSide]. */
    fun sampleSize(width: Int, height: Int, maxSide: Int = MAX_SIDE): Int {
        var sample = 1
        while (maxOf(width, height) / sample > maxSide) sample *= 2
        return sample
    }

    /**
     * Image partagée acceptée : content:// seulement, et jamais un fichier
     * de Sentinel elle-même (une autre app ne doit pas nous faire lire nos
     * propres fichiers privés, ex : documents du coffre).
     */
    fun isAcceptableUri(scheme: String?, authority: String?, ownPackage: String): Boolean {
        if (scheme?.lowercase() != "content" || authority.isNullOrEmpty()) return false
        return authority.split(';').none { it == ownPackage || it.startsWith("$ownPackage.") }
    }

    /** Un QR code à afficher : [size] × [size] cases, true = case noire. */
    class Matrix(val size: Int, val modules: BooleanArray)

    /** Crée le QR code de [text] (UTF-8), sans marge : Dart l'ajoute. */
    fun encode(text: String): Matrix? {
        if (text.isEmpty() || text.length > MAX_ENCODE_LENGTH) return null
        return try {
            val bits = QRCodeWriter().encode(
                text,
                BarcodeFormat.QR_CODE,
                0,
                0,
                mapOf(
                    EncodeHintType.CHARACTER_SET to "UTF-8",
                    EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.M,
                    EncodeHintType.MARGIN to 0,
                ),
            )
            val size = bits.width
            Matrix(size, BooleanArray(size * size) { bits.get(it % size, it / size) })
        } catch (e: WriterException) {
            null
        } catch (e: IllegalArgumentException) {
            null
        }
    }
}
