package com.iheb.sentinel

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.iheb.sentinel.firewall.FirewallChannel
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

    // Même nom que dans lib/services/share_service.dart.
    private val shareChannelName = "com.iheb.sentinel/share"
    private var shareChannel: MethodChannel? = null

    // Texte reçu au lancement, en attente que Dart le demande.
    private var initialSharedText: String? = null

    // Même nom que dans lib/services/protection_service.dart.
    private val protectionChannelName = "com.iheb.sentinel/protection"
    // Langue choisie dans Réglages (lib/services/language_store.dart).
    private val languageChannelName = "com.iheb.sentinel/language"

    // Réponse à renvoyer à Dart quand l'utilisateur a répondu à la demande
    // d'autorisation des notifications.
    private var pendingPermissionResult: MethodChannel.Result? = null

    // Protections du coffre (écran sécurisé, presse-papiers, écran éteint).
    private var vaultProtection: VaultProtection? = null

    // Sécurité du Wi-Fi actuel et écoute des changements de réseau.
    private var wifiChecker: WifiSecurityChecker? = null

    // Pare-feu DNS (VpnService).
    private var firewall: FirewallChannel? = null

    // Scanner de QR code (onglet Messages).
    private var qrScanner: QrScanner? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // savedInstanceState != null : l'app est recréée (rotation, retour
        // depuis les apps récentes…) ; le texte a déjà été traité.
        if (savedInstanceState == null && !launchedFromHistory(intent)) {
            initialSharedText = sharedTextFrom(intent)
        }
    }

    // App déjà ouverte (singleTop) : Android réutilise cette activité
    // et lui transmet le nouvel Intent ici au lieu de la recréer.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = sharedTextFrom(intent) ?: return
        shareChannel?.invokeMethod("onSharedText", text)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        vaultProtection = VaultProtection(this, flutterEngine.dartExecutor.binaryMessenger)
        wifiChecker = WifiSecurityChecker(this, flutterEngine.dartExecutor.binaryMessenger)
        firewall = FirewallChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        qrScanner = QrScanner(this, flutterEngine.dartExecutor.binaryMessenger)

        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
            .apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        // Rendu une seule fois, puis effacé.
                        "getInitialSharedText" -> {
                            result.success(initialSharedText)
                            initialSharedText = null
                        }
                        else -> result.notImplemented()
                    }
                }
            }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, protectionChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> result.success(ProtectionSettings.status(this))
                    "setEnabled" -> {
                        ProtectionSettings.setEnabled(this, call.argument<Boolean>("enabled") == true)
                        result.success(null)
                    }
                    "openListenerSettings" -> {
                        openListenerSettings()
                        result.success(null)
                    }
                    "openNotificationSettings" -> {
                        openOrFallback(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                        )
                        result.success(null)
                    }
                    "requestNotificationPermission" -> requestNotificationPermission(result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, languageChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setLanguage" -> {
                        AppLanguage.choose(this, call.argument<String>("language"))
                        result.success(null)
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
                    "openWebPage" -> openWebPage(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        vaultProtection?.dispose()
        vaultProtection = null
        wifiChecker?.dispose()
        wifiChecker = null
        firewall?.dispose()
        firewall = null
        qrScanner?.dispose()
        qrScanner = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // Réponse de l'écran de consentement VPN, du sélecteur de fichiers
    // ou du scanner de QR code.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (firewall?.onActivityResult(requestCode, resultCode) == true) return
        if (qrScanner?.onActivityResult(requestCode, resultCode, data) == true) return
        if (vaultProtection?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        appsExecutor.shutdown()
        super.onDestroy()
    }

    // Texte partagé (SEND), sélectionné (PROCESS_TEXT) ou venant d'une
    // alerte Sentinel (OPEN_ALERT, via AlertRelayActivity), sinon null.
    // MainActivity est exportée : le texte d'une alerte ne vient jamais de
    // l'Intent, seulement de alertInbox (SEN-06).
    private fun sharedTextFrom(intent: Intent?): String? {
        if (intent == null) return null
        return incomingText(
            action = intent.action,
            sendText = intent.getCharSequenceExtra(Intent.EXTRA_TEXT),
            processText = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT),
            inbox = alertInbox,
        )
    }

    private fun launchedFromHistory(intent: Intent?): Boolean =
        (intent?.flags ?: 0) and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0

    companion object {
        private const val REQUEST_NOTIFICATIONS = 1
    }

    // Android 13+ : demande l'autorisation d'afficher des notifications.
    // Avant Android 13, elle est accordée d'office (sauf si l'utilisateur
    // les a coupées dans les réglages).
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(ProtectionSettings.notificationsAllowed(this))
            return
        }
        pendingPermissionResult?.success(false) // demande précédente sans réponse
        pendingPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (qrScanner?.onRequestPermissionsResult(requestCode, grantResults) == true) return
        if (requestCode != REQUEST_NOTIFICATIONS) return
        pendingPermissionResult?.success(ProtectionSettings.notificationsAllowed(this))
        pendingPermissionResult = null
    }

    // Android 11+ : ouvre directement l'interrupteur de Sentinel ;
    // sinon (ou si le fabricant ne le gère pas) la liste des apps.
    private fun openListenerSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                startActivity(
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                        Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                        ProtectionSettings.listenerComponent(this).flattenToString(),
                    ),
                )
                return
            } catch (e: ActivityNotFoundException) {
                // On essaie la liste ci-dessous.
            }
        }
        openOrFallback(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
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

    // Ouvre une page d'aide dans le navigateur (https uniquement).
    private fun openWebPage(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url == null || !url.startsWith("https://")) {
            result.error("BAD_URL", "Adresse refusée", null)
            return
        }
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            result.success(null)
        } catch (e: ActivityNotFoundException) {
            result.error("NO_ACTIVITY", e.message, null)
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
