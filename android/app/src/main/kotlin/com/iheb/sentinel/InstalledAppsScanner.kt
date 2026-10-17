package com.iheb.sentinel

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.provider.Settings
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import javax.security.auth.x500.X500Principal

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
        val launchers = packagesWithLauncherIcon()

        return installedPackages()
            .filter { it.packageName != context.packageName }
            .mapNotNull { info ->
                // Une app illisible est ignorée, le reste du scan continue.
                try {
                    describe(info, accessibility, listeners, admins, launchers)
                } catch (e: Exception) {
                    null
                }
            }
    }

    // Toutes les apps, avec leurs permissions et leurs certificats de signature.
    private fun installedPackages(): List<PackageInfo> {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_PERMISSIONS or PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_PERMISSIONS or PackageManager.GET_SIGNATURES
        }
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
        launchers: Set<String>,
    ): Map<String, Any?>? {
        val app = info.applicationInfo ?: return null
        val packageName = info.packageName
        val requested = info.requestedPermissions.orEmpty()
        val certs = signingCerts(info)

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
            "signingCerts" to certs.map { it.toMap() },
            // Seuls les certificats actuels comptent (pas l'historique).
            "debugCert" to certs.any { it.current && it.isTestKey() },
            "hasLauncherIcon" to (packageName in launchers),
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

    // Un certificat de signature : empreintes et propriétaire déclaré.
    private class SigningCert(
        val sha256: String,
        val sha1: String, // format des indicateurs de stalkerware
        val subjectCn: String?,
        val subjectO: String?,
        val subjectFields: Map<String, String>,
        val current: Boolean, // faux : ancien certificat (rotation de clé)
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "sha256" to sha256,
            "sha1" to sha1,
            "subjectCn" to subjectCn,
            "subjectO" to subjectO,
            "current" to current,
        )

        // Clé de debug d'Android Studio, ou clés de test publiques d'AOSP
        // (n'importe qui peut signer avec : elles ne prouvent rien).
        // TODO(à vérifier) : comparer aussi les empreintes SHA-256 des clés
        // AOSP (build/target/product/security/*.x509.pem), calculées avec
        // tools/signatures/extract_cert.py.
        fun isTestKey(): Boolean {
            if (subjectCn == "Android Debug") return true
            val aosp = mapOf(
                "CN" to "Android", "OU" to "Android", "O" to "Android",
                "L" to "Mountain View", "ST" to "California", "C" to "US",
            )
            return aosp.all { (key, value) -> subjectFields[key] == value }
        }
    }

    // Certificats actuels en premier, puis les anciens (Android 9+).
    private fun signingCerts(info: PackageInfo): List<SigningCert> = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signing = info.signingInfo
            if (signing == null) {
                emptyList()
            } else {
                val current = signing.apkContentsSigners.orEmpty().toList()
                // L'historique n'a de sens qu'avec un seul signataire.
                val past = if (signing.hasMultipleSigners()) {
                    emptyList()
                } else {
                    signing.signingCertificateHistory.orEmpty().filter { it !in current }
                }
                current.mapNotNull { parseCert(it, true) } +
                    past.mapNotNull { parseCert(it, false) }
            }
        } else {
            @Suppress("DEPRECATION")
            info.signatures.orEmpty().mapNotNull { parseCert(it, true) }
        }
    } catch (e: Exception) {
        emptyList()
    }

    // Lit le certificat X.509 contenu dans la signature.
    private fun parseCert(signature: Signature, current: Boolean): SigningCert? = try {
        val bytes = signature.toByteArray()
        val cert = CertificateFactory.getInstance("X.509")
            .generateCertificate(ByteArrayInputStream(bytes)) as X509Certificate
        val fields = subjectFields(cert.subjectX500Principal)
        SigningCert(
            sha256 = hexDigest("SHA-256", bytes),
            sha1 = hexDigest("SHA-1", bytes),
            subjectCn = fields["CN"],
            subjectO = fields["O"],
            subjectFields = fields,
            current = current,
        )
    } catch (e: Exception) {
        null
    }

    // Empreinte en hexadécimal majuscule, sans séparateur.
    private fun hexDigest(algorithm: String, bytes: ByteArray): String =
        MessageDigest.getInstance(algorithm).digest(bytes)
            .joinToString("") { "%02X".format(it) }

    // « CN=Android Debug,O=Android,C=US » → {CN: Android Debug, O: Android…}.
    // Gère les virgules échappées (« \, ») ; la première valeur de chaque clé gagne.
    private fun subjectFields(principal: X500Principal): Map<String, String> {
        val name = principal.getName(X500Principal.RFC2253)
        val fields = mutableMapOf<String, String>()
        val part = StringBuilder()
        var escaped = false

        fun flush() {
            val text = part.toString()
            part.clear()
            val eq = text.indexOf('=')
            if (eq <= 0) return
            val key = text.substring(0, eq).trim().uppercase()
            fields.putIfAbsent(key, text.substring(eq + 1).trim())
        }

        for (c in name) {
            when {
                escaped -> { part.append(c); escaped = false }
                c == '\\' -> escaped = true
                c == ',' || c == '+' -> flush()
                else -> part.append(c)
            }
        }
        flush()
        return fields
    }

    // Packages ayant au moins une icône visible dans le lanceur.
    // Une app peut désactiver son activité « MAIN/LAUNCHER » après
    // installation pour cacher son icône : on lit l'état réel de chaque
    // composant avec getComponentEnabledSetting.
    private fun packagesWithLauncherIcon(): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val flags = PackageManager.MATCH_DISABLED_COMPONENTS
        val activities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(flags.toLong()))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, flags)
        }
        return activities
            .mapNotNull { it.activityInfo }
            .filter { activity ->
                try {
                    val component = ComponentName(activity.packageName, activity.name)
                    when (pm.getComponentEnabledSetting(component)) {
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                        // Valeur par défaut : celle du manifeste.
                        PackageManager.COMPONENT_ENABLED_STATE_DEFAULT ->
                            activity.enabled && activity.applicationInfo.enabled
                        else -> false // désactivée après installation
                    }
                } catch (e: Exception) {
                    false
                }
            }
            .map { it.packageName }
            .toSet()
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
