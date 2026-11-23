package com.iheb.sentinel

import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.util.zip.CRC32
import java.util.zip.Deflater
import java.util.zip.Inflater
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.sin

/**
 * Image en mémoire (pixels ARGB) et lecture / écriture PNG en Kotlin pur.
 * Les tests unitaires Android n'ont ni java.awt ni ImageIO (android.jar).
 */
class Raster(val width: Int, val height: Int, val pixels: IntArray = IntArray(width * height)) {

    fun fillRect(x: Int, y: Int, w: Int, h: Int, color: Int) {
        for (yy in maxOf(0, y) until minOf(height, y + h)) {
            for (xx in maxOf(0, x) until minOf(width, x + w)) pixels[yy * width + xx] = color
        }
    }

    fun fill(color: Int) = fillRect(0, 0, width, height, color)

    /** Copie [source] à la position ([x], [y]). */
    fun draw(source: Raster, x: Int, y: Int) {
        for (sy in 0 until source.height) for (sx in 0 until source.width) {
            val tx = x + sx
            val ty = y + sy
            if (tx in 0 until width && ty in 0 until height) {
                pixels[ty * width + tx] = source.pixels[sy * source.width + sx]
            }
        }
    }

    /** Même image tournée de [degrees] autour du centre (bilinéaire). */
    fun rotated(degrees: Double, background: Int): Raster {
        val out = Raster(width, height)
        val a = Math.toRadians(degrees)
        val cx = width / 2.0
        val cy = height / 2.0
        for (y in 0 until height) for (x in 0 until width) {
            // Point d'origine du pixel (rotation inverse).
            val dx = x - cx
            val dy = y - cy
            val sx = cos(a) * dx + sin(a) * dy + cx
            val sy = -sin(a) * dx + cos(a) * dy + cy
            out.pixels[y * width + x] = sample(sx, sy, background)
        }
        return out
    }

    private fun sample(x: Double, y: Double, background: Int): Int {
        val x0 = floor(x).toInt()
        val y0 = floor(y).toInt()
        if (x0 < 0 || y0 < 0 || x0 + 1 >= width || y0 + 1 >= height) return background
        val fx = x - x0
        val fy = y - y0
        var result = 0xFF shl 24
        for (shift in intArrayOf(16, 8, 0)) {
            fun c(px: Int, py: Int) = (pixels[py * width + px] shr shift) and 0xFF
            val top = c(x0, y0) * (1 - fx) + c(x0 + 1, y0) * fx
            val bottom = c(x0, y0 + 1) * (1 - fx) + c(x0 + 1, y0 + 1) * fx
            result = result or ((top * (1 - fy) + bottom * fy).toInt() shl shift)
        }
        return result
    }

    /** Un pixel sur [sample] (comme inSampleSize d'Android). */
    fun downsample(sample: Int): Raster {
        val out = Raster(width / sample, height / sample)
        for (y in 0 until out.height) for (x in 0 until out.width) {
            out.pixels[y * out.width + x] = pixels[y * sample * width + x * sample]
        }
        return out
    }

    companion object {
        fun rgb(r: Int, g: Int, b: Int) = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
        val BLACK = rgb(0, 0, 0)
        val WHITE = rgb(255, 255, 255)
    }
}

/** PNG 8 bits RGB (écriture) ; RGB ou RGBA non entrelacé (lecture). */
object Png {
    private val signature = byteArrayOf(-119, 80, 78, 71, 13, 10, 26, 10)

    fun write(image: Raster, file: File) {
        val raw = ByteArrayOutputStream()
        for (y in 0 until image.height) {
            raw.write(0) // filtre « aucun »
            for (x in 0 until image.width) {
                val p = image.pixels[y * image.width + x]
                raw.write(p shr 16 and 0xFF)
                raw.write(p shr 8 and 0xFF)
                raw.write(p and 0xFF)
            }
        }
        val out = DataOutputStream(file.outputStream().buffered())
        out.use {
            it.write(signature)
            val header = ByteArrayOutputStream().also { h ->
                DataOutputStream(h).apply {
                    writeInt(image.width)
                    writeInt(image.height)
                    write(byteArrayOf(8, 2, 0, 0, 0))
                }
            }.toByteArray()
            chunk(it, "IHDR", header)
            chunk(it, "IDAT", deflate(raw.toByteArray()))
            chunk(it, "IEND", ByteArray(0))
        }
    }

    private fun deflate(data: ByteArray): ByteArray {
        val deflater = Deflater(Deflater.BEST_COMPRESSION)
        deflater.setInput(data)
        deflater.finish()
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(65536)
        while (!deflater.finished()) out.write(buffer, 0, deflater.deflate(buffer))
        deflater.end()
        return out.toByteArray()
    }

    private fun chunk(out: DataOutputStream, type: String, data: ByteArray) {
        val typeBytes = type.toByteArray(Charsets.US_ASCII)
        out.writeInt(data.size)
        out.write(typeBytes)
        out.write(data)
        val crc = CRC32().apply {
            update(typeBytes)
            update(data)
        }
        out.writeInt(crc.value.toInt())
    }

    fun read(file: File): Raster {
        val input = DataInputStream(file.inputStream().buffered())
        input.use {
            val sig = ByteArray(8).also { s -> it.readFully(s) }
            require(sig.contentEquals(signature)) { "pas un PNG" }
            var width = 0
            var height = 0
            var channels = 3
            val idat = ByteArrayOutputStream()
            while (true) {
                val length = it.readInt()
                val type = ByteArray(4).also { t -> it.readFully(t) }.toString(Charsets.US_ASCII)
                val data = ByteArray(length).also { d -> it.readFully(d) }
                it.readInt() // CRC
                when (type) {
                    "IHDR" -> {
                        val h = DataInputStream(data.inputStream())
                        width = h.readInt()
                        height = h.readInt()
                        require(h.readUnsignedByte() == 8) { "8 bits seulement" }
                        channels = when (h.readUnsignedByte()) {
                            2 -> 3
                            6 -> 4
                            else -> error("RGB ou RGBA seulement")
                        }
                    }
                    "IDAT" -> idat.write(data)
                    "IEND" -> break
                }
            }
            return decode(inflate(idat.toByteArray()), width, height, channels)
        }
    }

    private fun inflate(data: ByteArray): ByteArray {
        val inflater = Inflater()
        inflater.setInput(data)
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(65536)
        while (!inflater.finished()) {
            val n = inflater.inflate(buffer)
            if (n == 0 && (inflater.needsInput() || inflater.needsDictionary())) break
            out.write(buffer, 0, n)
        }
        inflater.end()
        return out.toByteArray()
    }

    // Filtres PNG : aucun, Sub, Up, Average, Paeth.
    private fun decode(data: ByteArray, width: Int, height: Int, channels: Int): Raster {
        val stride = width * channels
        val previous = IntArray(stride)
        val current = IntArray(stride)
        val image = Raster(width, height)
        var offset = 0
        for (y in 0 until height) {
            val filter = data[offset++].toInt() and 0xFF
            for (i in 0 until stride) {
                val raw = data[offset++].toInt() and 0xFF
                val left = if (i >= channels) current[i - channels] else 0
                val up = previous[i]
                val upLeft = if (i >= channels) previous[i - channels] else 0
                current[i] = (raw + when (filter) {
                    1 -> left
                    2 -> up
                    3 -> (left + up) / 2
                    4 -> paeth(left, up, upLeft)
                    else -> 0
                }) and 0xFF
            }
            for (x in 0 until width) {
                val i = x * channels
                image.pixels[y * width + x] = Raster.rgb(current[i], current[i + 1], current[i + 2])
            }
            current.copyInto(previous)
        }
        return image
    }

    private fun paeth(a: Int, b: Int, c: Int): Int {
        val p = a + b - c
        val pa = kotlin.math.abs(p - a)
        val pb = kotlin.math.abs(p - b)
        val pc = kotlin.math.abs(p - c)
        return if (pa <= pb && pa <= pc) a else if (pb <= pc) b else c
    }
}
