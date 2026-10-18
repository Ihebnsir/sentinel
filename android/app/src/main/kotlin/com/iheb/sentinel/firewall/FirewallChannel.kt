package com.iheb.sentinel.firewall

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Pilote le pare-feu DNS depuis Dart : prepare, start, stop, status, et
 * les réglages des listes (catégories, liste blanche, mises à jour).
 */
class FirewallChannel(private val activity: Activity, messenger: BinaryMessenger) {

    // Même nom que dans lib/services/firewall_service.dart.
    private val channel = MethodChannel(messenger, "com.iheb.sentinel/firewall")

    // Réponse en attente du choix de l'utilisateur sur l'écran VPN d'Android.
    private var pendingPrepare: MethodChannel.Result? = null

    private val settings = FirewallSettings(activity)
    private val mainHandler = Handler(Looper.getMainLooper())

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
                    "blockedByCategory" to FirewallEngine.blockedByCategory
                        .mapKeys { it.key.id }
                        .mapValues { it.value.get() },
                    "listsLoading" to FirewallEngine.loading,
                ),
            )
            "config" -> result.success(config())
            "setCategoryEnabled" -> {
                val category = BlockCategory.fromId(call.argument<String>("id"))
                if (category == null) {
                    result.error("UNKNOWN_CATEGORY", null, null)
                    return
                }
                settings.setEnabled(category, call.argument<Boolean>("enabled") == true)
                FirewallEngine.refresh(activity) // sans redémarrer le VPN
                result.success(config())
            }
            "addAllowed" -> {
                val domain = settings.addAllowed(call.argument<String>("domain").orEmpty())
                if (domain == null) {
                    result.error("INVALID_DOMAIN", null, null)
                    return
                }
                FirewallEngine.refresh(activity)
                result.success(domain)
            }
            "removeAllowed" -> {
                settings.removeAllowed(call.argument<String>("domain").orEmpty())
                FirewallEngine.refresh(activity)
                result.success(null)
            }
            "setAutoUpdate" -> {
                settings.autoUpdate = call.argument<Boolean>("enabled") == true
                result.success(null)
            }
            // Le téléchargement tourne en arrière-plan ; réponse sur le
            // thread principal, comme l'exige Flutter.
            "updateNow" -> FirewallEngine.updateNow(activity) { ok ->
                mainHandler.post { result.success(ok) }
            }
            else -> result.notImplemented()
        }
    }

    // Tout ce que l'écran affiche, hors compteurs. Aucun domaine visité.
    private fun config(): Map<String, Any?> {
        val counts = FirewallEngine.entryCounts(activity)
        val sources = FirewallEngine.bundledManifest(activity)?.sources.orEmpty()
        return mapOf(
            "categories" to BlockCategory.entries.map { category ->
                mapOf(
                    "id" to category.id,
                    "name" to category.label,
                    "enabled" to settings.isEnabled(category),
                    "domains" to (counts[category] ?: 0),
                    "sources" to sources.filter { it.category == category }.map(::shortName).distinct(),
                )
            },
            "allowlist" to settings.allowlist().sorted(),
            "autoUpdate" to settings.autoUpdate,
            "lastUpdate" to settings.lastUpdateSuccess.takeIf { it > 0 },
            "lastUpdateFailed" to settings.lastUpdateFailed,
            "updating" to FirewallEngine.updating,
            "sources" to sources.distinctBy { it.homepage }.map { source ->
                mapOf(
                    "name" to shortName(source),
                    "license" to source.license,
                    "licenseUrl" to source.licenseUrl,
                    "homepage" to source.homepage,
                    "attribution" to source.attribution,
                )
            },
        )
    }

    // « ShadowWhisperer – Malware » → « ShadowWhisperer ».
    private fun shortName(source: BlocklistSource): String =
        source.name.substringBefore(" – ").substringBefore(" (")

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
