package com.iheb.sentinel

import android.Manifest
import android.app.NotificationManager
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
import androidx.core.content.IntentCompat
import com.iheb.sentinel.firewall.FirewallChannel
import com.iheb.sentinel.weekly.WeeklyChannel
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

    // Image partagée au lancement (QR code à lire). Seulement son adresse,
    // en mémoire : l'image n'est jamais copiée.
    private var initialSharedImage: Uri? = null

    // Lancement par la tuile du pare-feu, en attente que Dart le demande.
    private var initialOpenFirewall = false

    // Même nom que dans lib/services/notification_permission.dart.
    private val notificationsChannelName = "com.iheb.sentinel/notifications"
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

    // Scanner de QR code (onglet Liens).
    private var qrScanner: QrScanner? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // savedInstanceState != null : l'app est recréée (rotation, retour
        // depuis les apps récentes…) ; le texte a déjà été traité.
        if (savedInstanceState == null && !launchedFromHistory(intent)) {
            initialSharedImage = sharedImageFrom(intent)
            if (initialSharedImage == null) initialSharedText = sharedTextFrom(intent)
            initialOpenFirewall = intent?.action == ACTION_OPEN_FIREWALL
        }
    }

    // App déjà ouverte (singleTop) : Android réutilise cette activité
    // et lui transmet le nouvel Intent ici au lieu de la recréer.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ACTION_OPEN_FIREWALL) {
            shareChannel?.invokeMethod("onOpenFirewall", null)
            return
        }
        val image = sharedImageFrom(intent)
        if (image != null) {
            qrScanner?.decodeImage(image) { shareChannel?.invokeMethod("onSharedImage", it) }
            return
        }
        val text = sharedTextFrom(intent) ?: return
        shareChannel?.invokeMethod("onSharedText", text)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        vaultProtection = VaultProtection(this, flutterEngine.dartExecutor.binaryMessenger)
        wifiChecker = WifiSecurityChecker(this, flutterEngine.dartExecutor.binaryMessenger)
        firewall = FirewallChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        qrScanner = QrScanner(this, flutterEngine.dartExecutor.binaryMessenger)
        // Bilan de la semaine : compteurs seulement.
        WeeklyChannel(this, flutterEngine.dartExecutor.binaryMessenger)

        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
            .apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        // Rendu une seule fois, puis effacé.
                        "getInitialSharedText" -> {
                            result.success(initialSharedText)
                            initialSharedText = null
                        }
                        // Image partagée : décodée maintenant, puis oubliée.
                        "getInitialSharedImage" -> {
                            val uri = initialSharedImage
                            initialSharedImage = null
                            val scanner = qrScanner
                            if (uri == null || scanner == null) {
                                result.success(null)
                            } else {
                                scanner.decodeImage(uri) { result.success(it) }
                            }
                        }
                        // Idem pour la tuile du pare-feu.
                        "getInitialOpenFirewall" -> {
                            result.success(initialOpenFirewall)
                            initialOpenFirewall = false
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

        // Notifications du pare-feu et du bilan de la semaine.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> requestNotificationPermission(result)
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
                    "scanApps" -> inBackground(result, "SCAN_FAILED") {
                        InstalledAppsScanner(applicationContext).scan()
                    }
                    "scanApp" -> {
                        val pkg = call.argument<String>("packageName").orEmpty()
                        inBackground(result, "SCAN_FAILED") {
                            InstalledAppsScanner(applicationContext).scanOne(pkg)
                        }
                    }
                    // Accès sensibles (lib/services/sensitive_access_service.dart).
                    "hasUsageAccess" ->
                        result.success(SensitiveAccessReader(this).hasUsageAccess())
                    "readSensitiveAccess" -> inBackground(result, "READ_FAILED") {
                        SensitiveAccessReader(applicationContext).read()
                    }
                    "openUsageAccessSettings" -> {
                        openUsageAccessSettings()
                        result.success(null)
                    }
                    "openPrivacyDashboard" -> {
                        openPrivacyDashboard()
                        result.success(null)
                    }
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

    // Texte partagé (SEND) ou sélectionné (PROCESS_TEXT), sinon null.
    // L'onglet Liens y cherche le premier lien.
    private fun sharedTextFrom(intent: Intent?): String? {
        if (intent == null) return null
        return incomingText(
            action = intent.action,
            sendText = intent.getCharSequenceExtra(Intent.EXTRA_TEXT),
            processText = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT),
        )
    }

    // Image partagée (SEND, image/*) : son adresse content://, sinon null.
    // Refusée si elle désigne un fichier de Sentinel (QrImageDecoder).
    private fun sharedImageFrom(intent: Intent?): Uri? {
        if (intent?.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("image/") != true) return null
        val uri = IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
            ?: return null
        return uri.takeIf { QrImageDecoder.isAcceptableUri(it.scheme, it.authority, packageName) }
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
            result.success(notificationsAllowed())
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
        if (vaultProtection?.onRequestPermissionsResult(requestCode, grantResults) == true) return
        if (requestCode != REQUEST_NOTIFICATIONS) return
        pendingPermissionResult?.success(notificationsAllowed())
        pendingPermissionResult = null
    }

    // Sentinel peut-il afficher des notifications ?
    private fun notificationsAllowed(): Boolean =
        getSystemService(NotificationManager::class.java).areNotificationsEnabled()

    // Le travail tourne sur un autre thread pour ne pas figer l'écran ;
    // la réponse est renvoyée sur le thread principal, comme l'exige Flutter.
    private fun inBackground(result: MethodChannel.Result, errorCode: String, work: () -> Any?) {
        appsExecutor.execute {
            try {
                val value = work()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error(errorCode, e.message, null) }
            }
        }
    }

    // « Accès aux données d'utilisation » : directement sur Sentinel si le
    // téléphone le permet, sinon la liste des apps.
    private fun openUsageAccessSettings() {
        try {
            startActivity(
                Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    .setData(Uri.parse("package:$packageName")),
            )
        } catch (e: ActivityNotFoundException) {
            openOrFallback(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        } catch (e: SecurityException) {
            openOrFallback(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        }
    }

    // Android 12+ : tableau de bord de confidentialité (historique exact,
    // lu par le système seul). Action non garantie selon le fabricant :
    // sinon, les réglages de confidentialité.
    private fun openPrivacyDashboard() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                startActivity(Intent("android.intent.action.REVIEW_PERMISSION_USAGE"))
                return
            } catch (e: ActivityNotFoundException) {
                // On essaie les réglages ci-dessous.
            } catch (e: SecurityException) {
                // Idem.
            }
        }
        openOrFallback(Intent(Settings.ACTION_PRIVACY_SETTINGS))
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
