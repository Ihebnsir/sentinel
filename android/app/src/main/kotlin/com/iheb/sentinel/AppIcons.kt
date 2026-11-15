package com.iheb.sentinel

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import java.io.ByteArrayOutputStream

// Icônes d'apps envoyées à Dart (scanner d'apps, accès sensibles).
class AppIcons(private val pm: PackageManager) {

    // Taille des icônes envoyées à Dart, en pixels.
    private val iconSize = 96

    // Dessine l'icône dans une image 96x96 puis la compresse en PNG.
    fun png(app: ApplicationInfo): ByteArray? = try {
        val bitmap = Bitmap.createBitmap(iconSize, iconSize, Bitmap.Config.ARGB_8888)
        // mutate() : on modifie une copie, pas l'icône partagée par le système.
        val drawable = pm.getApplicationIcon(app).mutate()
        drawable.setBounds(0, 0, iconSize, iconSize)
        drawable.draw(Canvas(bitmap))
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        bitmap.recycle()
        out.toByteArray()
    } catch (e: Exception) {
        null
    }
}
