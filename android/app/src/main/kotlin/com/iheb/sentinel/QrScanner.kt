package com.iheb.sentinel

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import com.journeyapps.barcodescanner.ScanIntentResult
import com.journeyapps.barcodescanner.ScanOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Scanner de QR code (onglet Messages), avec ZXing (zxing-android-embedded) :
 * tout est décodé sur le téléphone, sans réseau. La caméra n'est demandée
 * qu'au moment du scan, après l'explication affichée par Dart.
 * Le contenu scanné n'est jamais journalisé ni ouvert automatiquement.
 */
class QrScanner(private val activity: Activity, messenger: BinaryMessenger) {

    // Même nom que dans lib/services/qr/qr_scanner_service.dart.
    private val channel = MethodChannel(messenger, "com.iheb.sentinel/qr")

    // Un seul scan à la fois.
    private var pending: MethodChannel.Result? = null
    private var pendingPrompt = ""

    init {
        channel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pending?.success(null)
        pending = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasCameraPermission" -> result.success(hasCameraPermission())
            "scan" -> scan(call.argument<String>("prompt") ?: "", result)
            "openLink" -> {
                val url = call.argument<String>("url")
                if (!QrActions.isWebLink(url)) return refuse(result)
                start(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addCategory(Intent.CATEGORY_BROWSABLE), result)
            }
            // Ouvre le composeur : rien n'est appelé sans l'utilisateur.
            "dial" -> {
                val number = call.argument<String>("number")
                if (!QrActions.isDialable(number)) return refuse(result)
                start(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", number, null)), result)
            }
            // Ouvre l'app SMS avec le texte : rien n'est envoyé sans l'utilisateur.
            "composeSms" -> {
                val number = call.argument<String>("number")
                if (!QrActions.isDialable(number)) return refuse(result)
                val intent = Intent(Intent.ACTION_SENDTO, Uri.fromParts("smsto", number, null))
                    .putExtra("sms_body", call.argument<String>("body") ?: "")
                start(intent, result)
            }
            "openPayment" -> {
                val uri = call.argument<String>("uri")
                if (!QrActions.isPaymentUri(uri)) return refuse(result)
                start(Intent(Intent.ACTION_VIEW, Uri.parse(uri)).addCategory(Intent.CATEGORY_BROWSABLE), result)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasCameraPermission() =
        activity.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    private fun scan(prompt: String, result: MethodChannel.Result) {
        if (pending != null) return result.error("BUSY", null, null)
        if (!activity.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
            return result.error("NO_CAMERA", null, null)
        }
        pending = result
        pendingPrompt = prompt
        if (hasCameraPermission()) {
            launchScanner()
        } else {
            activity.requestPermissions(arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA)
        }
    }

    private fun launchScanner() {
        val intent = ScanOptions()
            .setDesiredBarcodeFormats(ScanOptions.QR_CODE)
            .setPrompt(pendingPrompt)
            .setBeepEnabled(false)
            .setBarcodeImageEnabled(false) // aucune photo enregistrée
            .setOrientationLocked(false)
            .createScanIntent(activity)
        try {
            activity.startActivityForResult(intent, REQUEST_SCAN)
        } catch (e: ActivityNotFoundException) {
            finish { it.error("NO_CAMERA", null, null) }
        }
    }

    /** true si la réponse était pour nous. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CAMERA) return false
        if (pending == null) return true
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            launchScanner()
        } else {
            // Refus définitif (« Ne plus demander ») : seuls les réglages
            // d'Android peuvent rendre l'accès.
            val blocked = !activity.shouldShowRequestPermissionRationale(Manifest.permission.CAMERA)
            finish { it.error(if (blocked) "PERMISSION_BLOCKED" else "PERMISSION_DENIED", null, null) }
        }
        return true
    }

    /** true si la réponse était pour nous. null : scan annulé. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_SCAN) return false
        val contents = ScanIntentResult.parseActivityResult(resultCode, data).contents
        finish { it.success(contents) }
        return true
    }

    private fun finish(answer: (MethodChannel.Result) -> Unit) {
        val result = pending ?: return
        pending = null
        answer(result)
    }

    private fun refuse(result: MethodChannel.Result) = result.error("NOT_ALLOWED", null, null)

    private fun start(intent: Intent, result: MethodChannel.Result) {
        try {
            activity.startActivity(intent)
            result.success(null)
        } catch (e: ActivityNotFoundException) {
            result.error("NO_APP", null, null)
        } catch (e: SecurityException) {
            result.error("NO_APP", null, null)
        }
    }

    companion object {
        // Différents des autres demandes (1 à 4, voir MainActivity,
        // FirewallChannel et VaultDocuments).
        private const val REQUEST_SCAN = 5
        private const val REQUEST_CAMERA = 6
    }
}
