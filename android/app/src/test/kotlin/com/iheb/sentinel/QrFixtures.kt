package com.iheb.sentinel

import com.iheb.sentinel.Raster.Companion.BLACK
import com.iheb.sentinel.Raster.Companion.WHITE
import com.iheb.sentinel.Raster.Companion.rgb
import java.io.File
import java.util.Random
import org.junit.Assume.assumeTrue
import org.junit.Test

/**
 * Images de test (src/test/resources/qr/NOM.png), dessinées avec ZXing :
 * capture d'écran imitée, deux QR codes, QR inversé, penché, grande photo.
 * Déjà commitées. Pour les refaire (après un changement ici), lancer
 * testDebugUnitTest avec la variable SENTINEL_REGEN_QR_FIXTURES=1 et le
 * filtre --tests com.iheb.sentinel.QrFixtures (voir docs/NOTES_AUTONOMES.md).
 */
class QrFixtures {

    companion object {
        const val WA_ME = "https://wa.me/21698123456?text=Bonjour"
        const val TELEGRAM = "https://t.me/sentinel_tn"
        const val WIFI = "WIFI:T:WPA;S:Maison;P:motdepasse123;;"
        const val ARABIC = "ابعثلي الكود https://wa.me/21698123456"
        const val MARKET = "market://details?id=com.whatsapp"
        const val APK = "https://exemple.tn/WhatsApp-Gold.apk"
        const val VCARD = "BEGIN:VCARD\nVERSION:3.0\nFN:Service client BIAT\nTEL:+21698000111\nEND:VCARD"

        val dir = File("src/test/resources/qr")

        /** Le QR code de [text], [module] pixels par case, marge de 4 cases. */
        fun qr(text: String, module: Int, dark: Int = BLACK, light: Int = WHITE): Raster {
            val matrix = QrImageDecoder.encode(text)!!
            val quiet = 4
            val side = (matrix.size + 2 * quiet) * module
            val image = Raster(side, side)
            image.fill(light)
            for (y in 0 until matrix.size) for (x in 0 until matrix.size) {
                if (matrix.modules[y * matrix.size + x]) {
                    image.fillRect((x + quiet) * module, (y + quiet) * module, module, module, dark)
                }
            }
            return image
        }
    }

    @Test
    fun regenerate() {
        assumeTrue(System.getenv("SENTINEL_REGEN_QR_FIXTURES") != null)
        dir.mkdirs()
        val random = Random(42)

        save("wa_me.png", qr(WA_ME, 8))

        // Capture d'écran d'une discussion : bulles, lignes de texte, QR reçu.
        save("screenshot_chat.png", Raster(1080, 1920).apply {
            fill(rgb(0xEC, 0xE5, 0xDD))
            for (i in 0 until 9) {
                val x = if (i % 2 == 0) 40 else 380
                fillRect(x, 80 + i * 190, 660, 150, if (i % 2 == 0) WHITE else rgb(0xD9, 0xFD, 0xD3))
                for (line in 0 until 3) {
                    fillRect(x + 30, 110 + i * 190 + line * 35, 400 + random.nextInt(180), 14, rgb(0x55, 0x55, 0x55))
                }
            }
            fillRect(200, 900, 700, 760, WHITE)
            draw(qr(VCARD, 6), 260, 960)
        })

        // Deux QR codes côte à côte (affiche).
        save("two_codes.png", Raster(1400, 700).apply {
            fill(WHITE)
            draw(qr(TELEGRAM, 8), 40, 60)
            draw(qr(WIFI, 8), 760, 60)
        })

        save("arabic.png", qr(ARABIC, 7))

        // QR clair sur fond sombre (mode nuit d'une app).
        save("inverted.png", qr(MARKET, 8, dark = rgb(0xF0, 0xF0, 0xF0), light = rgb(0x12, 0x12, 0x12)))

        // QR un peu penché, photo d'affiche.
        val paper = rgb(0xFA, 0xF7, 0xF0)
        save("rotated.png", Raster(900, 900).apply {
            fill(paper)
            draw(qr(APK, 8), 150, 150)
        }.rotated(12.0, paper))

        // Grande photo (4000 × 3000) : QR lu après réduction par 2.
        save("large_photo.png", Raster(4000, 3000).apply {
            fill(rgb(0x80, 0x90, 0xA0))
            for (i in 0 until 40) fillRect(random.nextInt(3800), random.nextInt(2800), 200, 120, rgb(0x60, 0x70, 0x80))
            draw(qr(WA_ME, 10), 2600, 1700)
        })

        // Aucun QR code : formes et bruit.
        save("no_qr.png", Raster(800, 600).apply {
            fill(WHITE)
            for (i in 0 until 300) {
                fillRect(
                    random.nextInt(780), random.nextInt(580), 4 + random.nextInt(30), 4 + random.nextInt(30),
                    rgb(random.nextInt(256), random.nextInt(256), random.nextInt(256)),
                )
            }
        })
    }

    private fun save(name: String, image: Raster) = Png.write(image, File(dir, name))
}
