package com.iheb.sentinel

import android.content.ActivityNotFoundException
import android.content.Intent
import android.hardware.biometrics.BiometricManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    // Même nom que dans lib/services/device_security_service.dart.
    private val channelName = "com.iheb.sentinel/device_security"

    // Même nom que dans lib/services/apps_scanner_service.dart.
    private val appsChannelName = "com.iheb.sentinel/apps"

    // Un thread d'arrière-plan pour le scan, et l'accès au thread principal.
    private val appsExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanApps" -> scanAppsInBackground(result)
                    "openAppSettings" -> openForPackage(call, result) { uri ->
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri)
                    }
                    "uninstallApp" -> openForPackage(call, result) { uri ->
                        Intent(Intent.ACTION_DELETE, uri)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        appsExecutor.shutdown()
        super.onDestroy()
    }

    // Le scan tourne sur un autre thread pour ne pas figer l'écran ;
    // la réponse est renvoyée sur le thread principal, comme l'exige Flutter.
    private fun scanAppsInBackground(result: MethodChannel.Result) {
        appsExecutor.execute {
            try {
                val apps = InstalledAppsScanner(applicationContext).scan()
                mainHandler.post { result.success(apps) }
            } catch (e: Exception) {
                mainHandler.post { result.error("SCAN_FAILED", e.message, null) }
            }
        }
    }

    // Lit l'argument « packageName » et ouvre l'écran Android correspondant.
    private fun openForPackage(
        call: MethodCall,
        result: MethodChannel.Result,
        intentFor: (Uri) -> Intent,
    ) {
        val packageName = call.argument<String>("packageName")
        if (packageName.isNullOrBlank()) {
            result.error("MISSING_PACKAGE", "Nom de package manquant", null)
            return
        }
        try {
            startActivity(intentFor(Uri.parse("package:$packageName")))
            result.success(null)
        } catch (e: ActivityNotFoundException) {
            result.error("NO_ACTIVITY", e.message, null)
        } catch (e: SecurityException) {
            result.error("NOT_ALLOWED", e.message, null)
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
