package com.iheb.sentinel.firewall

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Android efface les alarmes au redémarrage et à la mise à jour de l'app :
 * on purge les rapports expirés et on reprogramme le nettoyage (SEN-14).
 * Exporté pour recevoir ces diffusions, que seul le système peut envoyer
 * (broadcasts protégés). Toute autre action est ignorée.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in ACTIONS) return
        val store = ReportCleanupReceiver.store(context)
        store.purgeExpired()
        ReportCleanupReceiver.schedule(context, store)
    }

    companion object {
        val ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
        )
    }
}
