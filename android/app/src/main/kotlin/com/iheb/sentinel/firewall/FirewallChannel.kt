package com.iheb.sentinel.firewall

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Pilote le pare-feu DNS depuis Dart : prepare, start, stop, status, les
 * réglages des listes (catégories, liste blanche, mises à jour) et
 * l'analyse d'une application (rapports).
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
        // Rapports de plus de 24 h : supprimés dès l'ouverture de l'app.
        ReportCleanupReceiver.store(activity).purgeExpired()
        ReportCleanupReceiver.schedule(activity)
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
                    // SEN-10 : transport vers Quad9, accord pour le DNS en clair.
                    "upstream" to SentinelVpnService.upstream.id,
                    "plainDnsAllowed" to SentinelVpnService.plainDns.isAllowedFor(
                        UnderlyingNetworks.currentKey(activity),
                    ),
                    // SEN-11 : DNS privé en mode strict (incompatible avec le pare-feu).
                    "strictPrivateDns" to UnderlyingNetworks.strictPrivateDnsServer(activity),
                    "analysis" to SentinelVpnService.analysis?.let { session ->
                        mapOf(
                            "packageName" to session.packageName,
                            "appLabel" to session.appLabel,
                            "startedAt" to session.startedAt,
                            "endsAt" to session.endsAt,
                            "domains" to session.recorder.size,
                        )
                    },
                ),
            )
            "setPlainDnsAllowed" -> {
                if (call.argument<Boolean>("allowed") == true) {
                    SentinelVpnService.plainDns.allow(UnderlyingNetworks.currentKey(activity))
                } else {
                    SentinelVpnService.plainDns.revoke()
                }
                result.success(null)
            }
            "startAnalysis" -> startAnalysis(call, result)
            "stopAnalysis" -> {
                if (SentinelVpnService.analysis != null) sendToService(SentinelVpnService.ACTION_STOP_ANALYSIS)
                result.success(null)
            }
            "reports" -> result.success(ReportCleanupReceiver.store(activity).list())
            "deleteReport" -> {
                val store = ReportCleanupReceiver.store(activity)
                store.delete(call.argument<String>("id").orEmpty())
                ReportCleanupReceiver.schedule(activity, store)
                result.success(null)
            }
            "openApp" -> openApp(call.argument<String>("packageName").orEmpty(), result)
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
        sendToService(SentinelVpnService.ACTION_STOP)
    }

    // Le service tourne déjà (premier plan) : startService suffit.
    private fun sendToService(action: String, extras: Intent.() -> Unit = {}) {
        activity.startService(
            Intent(activity, SentinelVpnService::class.java).setAction(action).apply(extras),
        )
    }

    // Vérifications ici pour répondre une erreur claire à Dart ; le service
    // les refait (il peut aussi être appelé par la notification).
    private fun startAnalysis(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName").orEmpty()
        val minutes = call.argument<Int>("minutes") ?: 0
        when {
            !SentinelVpnService.isRunning -> result.error("NOT_RUNNING", null, null)
            SentinelVpnService.analysis != null -> result.error("ALREADY_RUNNING", null, null)
            minutes !in AnalysisSession.ALLOWED_MINUTES -> result.error("BAD_DURATION", null, null)
            packageName.isEmpty() || packageName == activity.packageName ||
                !isInstalled(packageName) -> result.error("UNKNOWN_APP", null, null)
            else -> {
                sendToService(SentinelVpnService.ACTION_START_ANALYSIS) {
                    putExtra(SentinelVpnService.EXTRA_PACKAGE, packageName)
                    putExtra(SentinelVpnService.EXTRA_MINUTES, minutes)
                }
                result.success(null)
            }
        }
    }

    private fun isInstalled(packageName: String): Boolean = try {
        activity.packageManager.getApplicationInfo(packageName, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    // Ouvre l'app analysée, pour l'utiliser pendant l'analyse.
    private fun openApp(packageName: String, result: MethodChannel.Result) {
        val intent = activity.packageManager.getLaunchIntentForPackage(packageName)
        if (intent == null) {
            result.success(false)
            return
        }
        try {
            activity.startActivity(intent)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.success(false)
        }
    }

    companion object {
        private const val REQUEST_VPN = 2
    }
}
