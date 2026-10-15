package com.iheb.sentinel

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.PersistableBundle
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Protections du coffre : écran sécurisé, copie sensible, et alerte à
 * Dart quand l'écran s'éteint (pour verrouiller tout de suite).
 * Ne journalise jamais le texte copié.
 */
class VaultProtection(private val activity: Activity, messenger: BinaryMessenger) {

    // Même nom que dans lib/services/vault/vault_platform.dart.
    private val channel = MethodChannel(messenger, "com.iheb.sentinel/vault")

    // ACTION_SCREEN_OFF ne peut être reçue que par un récepteur
    // enregistré dans le code (pas dans le manifeste).
    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_OFF) {
                channel.invokeMethod("onScreenOff", null)
            }
        }
    }

    init {
        channel.setMethodCallHandler(::onMethodCall)
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(screenOffReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            activity.registerReceiver(screenOffReceiver, filter)
        }
    }

    fun dispose() {
        activity.unregisterReceiver(screenOffReceiver)
        channel.setMethodCallHandler(null)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setSecure" -> {
                setSecure(call.argument<Boolean>("secure") == true)
                result.success(null)
            }
            "copySensitive" -> {
                copySensitive(call.argument<String>("text") ?: "")
                result.success(null)
            }
            "clearClipboard" -> {
                clearClipboard()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // FLAG_SECURE : écran noir sur les captures et dans les apps récentes.
    private fun setSecure(secure: Boolean) {
        if (secure) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private val clipboard: ClipboardManager
        get() = activity.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    // Android 13+ : contenu « sensible », masqué dans l'aperçu de copie.
    // Avant 13, la même clé (en texte) est respectée par certains claviers.
    private fun copySensitive(text: String) {
        val clip = ClipData.newPlainText("Sentinel", text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val key = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ClipDescription.EXTRA_IS_SENSITIVE
            } else {
                "android.content.extra.IS_SENSITIVE"
            }
            clip.description.extras = PersistableBundle().apply { putBoolean(key, true) }
        }
        clipboard.setPrimaryClip(clip)
    }

    private fun clearClipboard() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            clipboard.clearPrimaryClip()
        } else {
            clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
        }
    }
}
