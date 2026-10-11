package com.iheb.sentinel

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.provider.Settings
import java.io.ByteArrayOutputStream

// Liste les applications installées et leurs accès sensibles.
// Peut prendre plusieurs secondes : à appeler hors du thread principal.
class InstalledAppsScanner(private val context: Context) {

    private val pm: PackageManager = context.packageManager

    // Taille des icônes envoyées à Dart, en pixels.
    private val iconSize = 96

    // Une Map par application, sauf Sentinel elle-même.
    fun scan(): List<Map<String, Any?>> {
        // Ces réglages sont lus une seule fois pour toutes les apps.
        val accessibility = enabledPackages(Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        val listeners = enabledPackages("enabled_notification_listeners")
        val admins = activeAdminPackages()

        return installedPackages()
            .filter { it.packageName != context.packageName }
            .mapNotNull { info ->
                // Une app illisible est ignorée, le reste du scan continue.
                try {
                    describe(info, accessibility, listeners, admins)
                } catch (e: Exception) {
                    null
                }
            }
    }

    // Toutes les apps, avec leurs permissions demandées.
    private fun installedPackages(): List<PackageInfo> {
        val flags = PackageManager.GET_PERMISSIONS
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(flags.toLong()))
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledPackages(flags)
        }
    }

    private fun describe(
        info: PackageInfo,
        accessibility: Set<String>,
        listeners: Set<String>,
        admins: Set<String>,
    ): Map<String, Any?>? {
        val app = info.applicationInfo ?: return null
        val packageName = info.packageName
        val requested = info.requestedPermissions.orEmpty()

        return mapOf(
            "packageName" to packageName,
            "label" to pm.getApplicationLabel(app).toString(),
            "icon" to iconPng(app),
            "isSystemApp" to isSystemApp(app),
            "installerPackage" to installerOf(packageName),
            "versionName" to info.versionName,
            "firstInstallTime" to info.firstInstallTime,
            "lastUpdateTime" to info.lastUpdateTime,
            "targetSdk" to app.targetSdkVersion,
            "grantedPermissions" to grantedPermissions(info),
            "requestsOverlay" to requested.contains(Manifest.permission.SYSTEM_ALERT_WINDOW),
            "accessibilityServiceEnabled" to (packageName in accessibility),
            "notificationListenerEnabled" to (packageName in listeners),
            "isDeviceAdmin" to (packageName in admins),
        )
    }

    // Préinstallée par le fabricant (même si mise à jour depuis).
    private fun isSystemApp(app: ApplicationInfo): Boolean {
        val systemFlags = ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP
        return (app.flags and systemFlags) != 0
    }

    // L'app qui a installé ce package (ex : com.android.vending = Play Store).
    private fun installerOf(packageName: String): String? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            pm.getInstallSourceInfo(packageName).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            pm.getInstallerPackageName(packageName)
        }
    } catch (e: Exception) {
        null
    }

    // Seulement les permissions demandées ET accordées par l'utilisateur.
    private fun grantedPermissions(info: PackageInfo): List<String> {
        val names = info.requestedPermissions ?: return emptyList()
        val flags = info.requestedPermissionsFlags ?: return emptyList()
        return names.filterIndexed { i, _ ->
            i < flags.size && (flags[i] and PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0
        }
    }

    // Dessine l'icône dans une image 96x96 puis la compresse en PNG.
    private fun iconPng(app: ApplicationInfo): ByteArray? = try {
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

    // Les réglages listent des composants « package/classe » séparés par « : ».
    private fun enabledPackages(settingName: String): Set<String> = try {
        Settings.Secure.getString(context.contentResolver, settingName)
            .orEmpty()
            .split(':')
            .mapNotNull { ComponentName.unflattenFromString(it)?.packageName }
            .toSet()
    } catch (e: SecurityException) {
        // Certaines versions d'Android peuvent refuser la lecture.
        emptySet()
    }

    // Apps déclarées « administrateur de l'appareil ».
    private fun activeAdminPackages(): Set<String> {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
        return dpm?.activeAdmins.orEmpty().map { it.packageName }.toSet()
    }
}
