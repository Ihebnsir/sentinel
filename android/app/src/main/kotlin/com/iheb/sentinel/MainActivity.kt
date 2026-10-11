package com.iheb.sentinel

import android.content.ActivityNotFoundException
import android.content.Intent
import android.hardware.biometrics.BiometricManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // Même nom que dans lib/services/device_security_service.dart.
    private val channelName = "com.iheb.sentinel/device_security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSecurityStatus" -> try {
                        result.success(DeviceSecurityChecker(this).getStatus())
                    } catch (e: Exception) {
                        result.error("CHECK_FAILED", e.message, null)
                    }

                    "openSettings" -> {
                        val target = call.argument<String>("target")
                        val intent = settingsIntentFor(target)
                        if (intent == null) {
                            result.error("UNKNOWN_TARGET", "Cible inconnue : $target", null)
                        } else {
                            openOrFallback(intent)
                            result.success(null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // Choisit l'écran des paramètres selon la cible demandée par Dart.
    private fun settingsIntentFor(target: String?): Intent? = when (target) {
        "security" -> Intent(Settings.ACTION_SECURITY_SETTINGS)
        "biometric" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Intent(Settings.ACTION_BIOMETRIC_ENROLL).putExtra(
                Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
                BiometricManager.Authenticators.BIOMETRIC_STRONG,
            )
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }
        "developer" -> Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
        // Action non officielle : certains fabricants ne la gèrent pas.
        "update" -> Intent("android.settings.SYSTEM_UPDATE_SETTINGS")
        else -> null
    }

    // Ouvre l'écran demandé ; s'il n'existe pas, ouvre les paramètres généraux.
    private fun openOrFallback(intent: Intent) {
        try {
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            startActivity(Intent(Settings.ACTION_SETTINGS))
        } catch (e: SecurityException) {
            startActivity(Intent(Settings.ACTION_SETTINGS))
        }
    }
}
