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
 * pas ouverte. Réveil inexact d'Android : aucune permission spéciale.
 */
class ReportCleanupReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val store = store(context)
        store.purgeExpired()
        schedule(context, store)
    }

    companion object {
        private const val DIR = "app_reports"

        fun store(context: Context) = AppReportStore(File(context.filesDir, DIR))

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
            // Une minute de marge : le rapport est bien expiré au réveil.
            val at = next + 60_000L
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            } else {
                alarms.set(AlarmManager.RTC_WAKEUP, at, pending)
            }
        }
    }
}
