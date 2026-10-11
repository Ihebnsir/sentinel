package com.iheb.sentinel

import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.hardware.biometrics.BiometricManager
import android.os.Build
import android.provider.Settings
import java.io.File

// Lit l'état de sécurité du téléphone, sans internet ni permission dangereuse.
class DeviceSecurityChecker(private val context: Context) {

    // Chemins classiques où se trouve le binaire « su » sur un téléphone rooté.
    private val suPaths = listOf(
        "/system/bin/su",
        "/system/xbin/su",
        "/sbin/su",
        "/su/bin/su",
        "/system/sd/xbin/su",
        "/data/local/su",
        "/data/local/bin/su",
        "/data/local/xbin/su",
        "/system/app/Superuser.apk",
    )

    // Rassemble toutes les vérifications dans une Map envoyée à Dart.
    fun getStatus(): Map<String, Any> = mapOf(
        "screenLock" to isScreenLockSet(),
        "biometricEnrolled" to isStrongBiometricEnrolled(),
        "rooted" to isProbablyRooted(),
        "developerOptions" to isGlobalSettingOn(Settings.Global.DEVELOPMENT_SETTINGS_ENABLED),
        "usbDebugging" to isGlobalSettingOn(Settings.Global.ADB_ENABLED),
        "encrypted" to isStorageEncrypted(),
        "androidVersion" to Build.VERSION.RELEASE,
        "sdkInt" to Build.VERSION.SDK_INT,
        "securityPatch" to Build.VERSION.SECURITY_PATCH,
    )

    // Code PIN, schéma ou mot de passe configuré.
    private fun isScreenLockSet(): Boolean {
        val keyguard = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return keyguard.isDeviceSecure
    }

    // Empreinte ou visage « fort » enregistré (API 29 minimum).
    private fun isStrongBiometricEnrolled(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val manager = context.getSystemService(BiometricManager::class.java) ?: return false
        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        } else {
            // Android 10 : pas de choix du niveau, on prend la vérification simple.
            @Suppress("DEPRECATION")
            manager.canAuthenticate()
        }
        return result == BiometricManager.BIOMETRIC_SUCCESS
    }

    // Heuristique simple : binaire su présent ou système signé avec des clés de test.
    private fun isProbablyRooted(): Boolean {
        val testKeys = Build.TAGS?.contains("test-keys") == true
        val suFound = suPaths.any { path ->
            try {
                File(path).exists()
            } catch (e: SecurityException) {
                false
            }
        }
        return testKeys || suFound
    }

    // Un réglage global vaut 1 quand il est activé.
    private fun isGlobalSettingOn(name: String): Boolean =
        Settings.Global.getInt(context.contentResolver, name, 0) == 1

    // Chiffrement du stockage (actif sur presque tous les téléphones récents).
    private fun isStorageEncrypted(): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return when (dpm.storageEncryptionStatus) {
            DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE,
            DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_DEFAULT_KEY,
            DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_PER_USER -> true
            else -> false
        }
    }
}
