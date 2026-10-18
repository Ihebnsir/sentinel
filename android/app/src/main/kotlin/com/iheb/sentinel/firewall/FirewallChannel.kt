package com.iheb.sentinel.firewall

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.VpnService
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Pilote le pare-feu DNS depuis Dart : prepare, start, stop, status. */
class FirewallChannel(private val activity: Activity, messenger: BinaryMessenger) {

    // Même nom que dans lib/services/firewall_service.dart.
    private val channel = MethodChannel(messenger, "com.iheb.sentinel/firewall")

    // Réponse en attente du choix de l'utilisateur sur l'écran VPN d'Android.
    private var pendingPrepare: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(::onMethodCall)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pendingPrepare?.success(false)
        pendingPrepare = null
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepare" -> prepare(result)
            "start" -> {
                start()
                result.success(null)
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            "status" -> result.success(
                mapOf(
                    "active" to SentinelVpnService.isRunning,
                    "totalQueries" to SentinelVpnService.totalQueries.get(),
                    "blockedQueries" to SentinelVpnService.blockedQueries.get(),
                ),
            )
            else -> result.notImplemented()
        }
    }

    // null : autorisation déjà accordée. Sinon, Android affiche son écran
    // de consentement « Demande de connexion ».
    private fun prepare(result: MethodChannel.Result) {
        val intent = VpnService.prepare(activity)
        if (intent == null) {
            result.success(true)
            return
        }
        pendingPrepare?.success(false) // demande précédente sans réponse
        pendingPrepare = result
        try {
            activity.startActivityForResult(intent, REQUEST_VPN)
        } catch (e: ActivityNotFoundException) {
            pendingPrepare = null
            result.error("NO_VPN_DIALOG", e.message, null)
        }
    }

    /** Appelé par MainActivity ; vrai si le résultat était pour nous. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_VPN) return false
        pendingPrepare?.success(resultCode == Activity.RESULT_OK)
        pendingPrepare = null
        return true
    }

    private fun start() {
        val intent = Intent(activity, SentinelVpnService::class.java)
            .setAction(SentinelVpnService.ACTION_START)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.startForegroundService(intent)
        } else {
            activity.startService(intent)
        }
    }

    private fun stop() {
        if (!SentinelVpnService.isRunning) return
        activity.startService(
            Intent(activity, SentinelVpnService::class.java)
                .setAction(SentinelVpnService.ACTION_STOP),
        )
    }

    companion object {
        private const val REQUEST_VPN = 2
    }
}
