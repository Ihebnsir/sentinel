package com.iheb.sentinel

import kotlin.math.max
import kotlin.math.min

/**
 * Règles des documents du coffre, sans dépendance Android (testées sur JVM).
 */
object VaultMediaPolicy {

    /** Plus grand côté d'une image recompressée (assez pour lire un papier). */
    const val MAX_SIDE = 2560

    /** Une image plus lourde est recompressée (et perd ses métadonnées). */
    const val SHRINK_ABOVE = 2 * 1024 * 1024

    /** Lecture maximale d'une image avant recompression. */
    const val RAW_IMAGE_LIMIT = 40 * 1024 * 1024

    /** Largeur maximale d'une page de PDF rendue. */
    const val MAX_PDF_WIDTH = 2000

    private val keptTypes = setOf("image/jpeg", "image/png", "image/webp")

    /** L'image peut-elle être gardée telle quelle ? */
    fun keepsOriginal(mime: String?, size: Int, width: Int, height: Int): Boolean =
        mime in keptTypes && size <= SHRINK_ABOVE && max(width, height) <= MAX_SIDE

    /** Puissance de 2 pour décoder sans dépasser 2 × maxSide (mémoire). */
    fun sampleSize(width: Int, height: Int, maxSide: Int = MAX_SIDE): Int {
        var sample = 1
        while (max(width, height) / (sample * 2) >= maxSide) sample *= 2
        return sample
    }

    /** Échelle finale pour que le plus grand côté tienne dans maxSide. */
    fun fitScale(width: Int, height: Int, maxSide: Int = MAX_SIDE): Float {
        val side = max(width, height)
        return if (side <= maxSide) 1f else maxSide.toFloat() / side
    }

    /** Commence par « %PDF- ». */
    fun isPdf(bytes: ByteArray): Boolean {
        val magic = "%PDF-".toByteArray(Charsets.US_ASCII)
        if (bytes.size < magic.size) return false
        return magic.indices.all { bytes[it] == magic[it] }
    }

    /** Largeur de rendu d'une page de PDF, bornée. */
    fun pdfWidth(requested: Int): Int = min(max(requested, 200), MAX_PDF_WIDTH)

    /** Extension du nom proposé au partage (jamais le titre : discret). */
    fun shareName(mime: String): String = "sentinel-document." + when (mime) {
        "application/pdf" -> "pdf"
        "image/png" -> "png"
        "image/webp" -> "webp"
        else -> "jpg"
    }
}
