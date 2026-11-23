package com.iheb.sentinel

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.journeyapps.barcodescanner.ScanIntentResult
import com.journeyapps.barcodescanner.ScanOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Scanner de QR code (onglet Liens), avec ZXing (zxing-android-embedded) :
 * tout est décodé sur le téléphone, sans réseau. La caméra n'est demandée
 * qu'au moment du scan, après l'explication affichée par Dart.
 * Le contenu scanné n'est jamais journalisé ni ouvert automatiquement.
 * Lit aussi les QR codes d'une image choisie avec le sélecteur de photos
 * d'Android (aucune permission de stockage) et crée le QR code de
 * « Partager mon Wi-Fi ».
 */
class QrScanner(private val activity: Activity, messenger: BinaryMessenger) {

    // Même nom que dans lib/services/qr/qr_scanner_service.dart.
    private val channel = MethodChannel(messenger, "com.iheb.sentinel/qr")

    // Un seul scan à la fois.
    private var pending: MethodChannel.Result? = null
    private var pendingPrompt = ""

    // Une seule image à la fois ; décodage hors du thread principal.
    private var pendingImage: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val photoPicker = ActivityResultContracts.PickVisualMedia()

    init {
        channel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pending?.success(null)
        pending = null
        pendingImage?.success(null)
        pendingImage = null
        io.shutdown()
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasCameraPermission" -> result.success(hasCameraPermission())
            "scan" -> scan(call.argument<String>("prompt") ?: "", result)
            "pickImage" -> pickImage(result)
            "encodeQr" -> {
                val matrix = QrImageDecoder.encode(call.argument<String>("text") ?: "")
                    ?: return result.error("ENCODE_FAILED", null, null)
                val modules = ByteArray(matrix.modules.size) { if (matrix.modules[it]) 1 else 0 }
                result.success(mapOf("size" to matrix.size, "modules" to modules))
            }
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

    // Sélecteur de photos d'Android (Android 11+ via les mises à jour
    // système, ou module Google Play) ; sinon le sélecteur de documents
    // (ACTION_OPEN_DOCUMENT). Aucune permission de stockage dans les deux cas.
    private fun pickImage(result: MethodChannel.Result) {
        if (pendingImage != null) return result.error("BUSY", null, null)
        val request = PickVisualMediaRequest.Builder()
            .setMediaType(ActivityResultContracts.PickVisualMedia.ImageOnly)
            .build()
        try {
            activity.startActivityForResult(photoPicker.createIntent(activity, request), REQUEST_PICK_IMAGE)
            pendingImage = result
        } catch (e: ActivityNotFoundException) {
            result.error("NO_PICKER", null, null)
        }
    }

    private fun onImagePicked(resultCode: Int, data: Intent?) {
        val result = pendingImage ?: return
        pendingImage = null
        val uri = photoPicker.parseResult(resultCode, data) ?: return result.success(null)
        decodeImage(uri) { result.success(it) }
    }

    /** Décode [uri] hors du thread principal ; réponse sur le thread principal. */
    fun decodeImage(uri: Uri, answer: (Map<String, Any>) -> Unit) {
        io.execute {
            val decoded = QrImageReader(activity.applicationContext).read(uri)
            main.post { answer(decoded) }
        }
    }

    /** true si la réponse était pour nous. null : scan annulé. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_PICK_IMAGE) {
            onImagePicked(resultCode, data)
            return true
        }
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
        // Différents des autres demandes (1 à 4 : MainActivity,
        // FirewallChannel, VaultDocuments ; 7 à 9 : VaultMedia).
        private const val REQUEST_SCAN = 5
        private const val REQUEST_CAMERA = 6
        private const val REQUEST_PICK_IMAGE = 10
    }
}
