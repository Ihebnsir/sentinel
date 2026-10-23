package com.iheb.sentinel.firewall

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.io.File

/**
 * Supprime les rapports d'analyse expirés (24 h), même si l'app n'est
 * pas ouverte (SEN-14). Réveil exact si Android l'autorise
 * (SCHEDULE_EXACT_ALARM), sinon inexact. Dans tous les cas, un rapport
 * expiré n'est jamais relu (AppReportStore.list), et les alarmes perdues
 * au redémarrage sont reprogrammées par BootReceiver.
 */
class ReportCleanupReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val store = store(context)
        store.purgeExpired()
        schedule(context, store)
    }

    companion object {
        private const val DIR = "app_reports"

        fun store(context: Context) = AppReportStore(
            File(context.filesDir, DIR),
            AesGcmReportCipher(ReportKeystore::key),
        )

        /** Programme le prochain nettoyage (ou l'annule s'il n'y a plus de rapport). */
        fun schedule(context: Context, store: AppReportStore = store(context)) {
            val alarms = context.getSystemService(AlarmManager::class.java) ?: return
            val pending = PendingIntent.getBroadcast(
                context,
                0,
                Intent(context, ReportCleanupReceiver::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val next = store.nextExpiry()
            if (next == null) {
                alarms.cancel(pending)
                return
            }
            // Une seconde de marge : le rapport est bien expiré au réveil.
            val at = next + 1_000L
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarms.canScheduleExactAlarms() ->
                    alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
                    alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                // Avant Android 12 : alarme exacte sans permission.
                else -> alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            }
        }
    }
}
