package com.iheb.sentinel

import android.Manifest
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process

// « Accès sensibles » : faits bruts envoyés à Dart (lib/services/sensitive_access.dart).
// Aucune API publique ne donne l'historique caméra / micro / localisation
// des autres apps : on lit les autorisations accordées et les moments
// d'activité (UsageStatsManager). Rien n'est enregistré ici.
class SensitiveAccessReader(private val context: Context) {

    private val pm: PackageManager = context.packageManager

    // Autorisation spéciale « Accès aux données d'utilisation » accordée ?
    fun hasUsageAccess(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
            ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            @Suppress("DEPRECATION")
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName,
            )
        }
        // Mode par défaut : c'est la permission qui décide.
        if (mode == AppOpsManager.MODE_DEFAULT) {
            return context.checkSelfPermission(Manifest.permission.PACKAGE_USAGE_STATS) ==
                PackageManager.PERMISSION_GRANTED
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    // Une Map par app ayant caméra, micro ou localisation accordé.
    fun read(days: Int = 7): List<Map<String, Any?>> {
        val now = System.currentTimeMillis()
        val apps = installedPackages()
            .filter { it.packageName != context.packageName }
            .mapNotNull { info -> sensorsOf(info)?.let { info to it } }
        val events = usageEvents(now - days * DAY_MS, now, apps.map { it.first.packageName }.toSet())
        val icons = AppIcons(pm)

        return apps.mapNotNull { (info, sensors) ->
            val app = info.applicationInfo ?: return@mapNotNull null
            val list = events[info.packageName].orEmpty()
            mapOf(
                "packageName" to info.packageName,
                "label" to pm.getApplicationLabel(app).toString(),
                "icon" to icons.png(app),
                "isSystemApp" to isSystemApp(app),
                "sensors" to sensors.names,
                "backgroundLocation" to sensors.backgroundLocation,
                // Int64List / Int32List côté Dart : léger pour beaucoup d'événements.
                "eventTimes" to LongArray(list.size) { list[it].first },
                "eventKinds" to IntArray(list.size) { list[it].second },
            )
        }
    }

    private class Sensors(val names: List<String>, val backgroundLocation: Boolean)

    // Accès accordés à l'app, null si aucun.
    private fun sensorsOf(info: PackageInfo): Sensors? {
        val granted = grantedPermissions(info)
        val location = Manifest.permission.ACCESS_FINE_LOCATION in granted ||
            Manifest.permission.ACCESS_COARSE_LOCATION in granted
        val names = buildList {
            if (Manifest.permission.CAMERA in granted) add("camera")
            if (Manifest.permission.RECORD_AUDIO in granted) add("microphone")
            if (location) add("location")
        }
        if (names.isEmpty()) return null
        // Avant Android 10, la localisation accordée l'est aussi en arrière-plan.
        val background = location && (
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                Manifest.permission.ACCESS_BACKGROUND_LOCATION in granted
            )
        return Sensors(names, background)
    }

    private fun grantedPermissions(info: PackageInfo): Set<String> {
        val names = info.requestedPermissions ?: return emptySet()
        val flags = info.requestedPermissionsFlags ?: return emptySet()
        return names.filterIndexed { i, _ ->
            i < flags.size && (flags[i] and PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0
        }.toSet()
    }

    private fun installedPackages(): List<PackageInfo> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledPackages(
                PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
        }

    // Événements utiles, par package : (heure, code de UsageEventCodes).
    private fun usageEvents(
        from: Long,
        to: Long,
        packages: Set<String>,
    ): Map<String, List<Pair<Long, Int>>> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyMap()
        val result = HashMap<String, MutableList<Pair<Long, Int>>>()
        val events = usm.queryEvents(from, to) ?: return emptyMap()
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            if (pkg !in packages) continue
            val code = UsageEventCodes.codeOf(event.eventType) ?: continue
            result.getOrPut(pkg) { mutableListOf() }.add(event.timeStamp to code)
        }
        return result
    }

    private fun isSystemApp(app: ApplicationInfo): Boolean {
        val systemFlags = ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP
        return (app.flags and systemFlags) != 0
    }

    private companion object {
        const val DAY_MS = 24L * 60 * 60 * 1000
    }
}

// Traduction des types d'événements Android en codes Dart (UsageEventKind).
// Valeurs fixes de UsageEvents.Event, écrites en clair pour le test JUnit.
object UsageEventCodes {
    const val FOREGROUND = 0
    const val BACKGROUND = 1
    const val SERVICE_START = 2
    const val SERVICE_STOP = 3

    fun codeOf(eventType: Int): Int? = when (eventType) {
        1 -> FOREGROUND // ACTIVITY_RESUMED (ex-MOVE_TO_FOREGROUND)
        2, 23 -> BACKGROUND // ACTIVITY_PAUSED, ACTIVITY_STOPPED
        19 -> SERVICE_START // FOREGROUND_SERVICE_START (Android 10+)
        20 -> SERVICE_STOP // FOREGROUND_SERVICE_STOP (Android 10+)
        else -> null
    }
}
