package com.iheb.sentinel.firewall

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.iheb.sentinel.MainActivity
import com.iheb.sentinel.R

/**
 * Alerte « Site dangereux bloqué » (Malware et hameçonnage) ou « Site
 * imitant <marque> bloqué » (Imitations de marques).
 * Même principes que ScamAlertNotifier : domaine neutralisé (site[.]xyz),
 * masqué sur l'écran verrouillé, aucune action proposée par Android.
 */
object FirewallAlertNotifier {
    private const val CHANNEL_ID = "firewall_alerts"
    private const val RED = 0xFFC2263A.toInt() // AppColors.rommen

    // Plage d'identifiants propre au pare-feu (une alerte par domaine).
    private const val ID_BASE = 3000
    private const val ID_RANGE = 1000

    /** [brand] : nom de la marque imitée, ou null pour un site de la liste Malware. */
    fun show(context: Context, domain: String, brand: String? = null) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return
        createChannel(manager)

        val title = if (brand == null) "Site dangereux bloqué" else "Site imitant $brand bloqué"
        val text = if (brand == null) {
            "Sentinel a empêché une connexion vers ${DomainNames.defang(domain)}, " +
                "un site connu pour du hameçonnage ou des logiciels malveillants."
        } else {
            "Sentinel a empêché une connexion vers ${DomainNames.defang(domain)}, " +
                "qui imite $brand sans être son site officiel."
        }

        // Ouvre simplement l'app : le domaine n'est transmis à personne.
        val tap = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE,
        )

        // Écran verrouillé : version neutre, sans le domaine.
        val publicVersion = builder(context)
            .setSmallIcon(R.drawable.ic_stat_arch)
            .setColor(RED)
            .setContentTitle("Sentinel")
            .setContentText("Site dangereux bloqué")
            .build()

        val notification = builder(context)
            .setSmallIcon(R.drawable.ic_stat_arch)
            .setColor(RED)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setCategory(Notification.CATEGORY_STATUS)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()

        manager.notify(ID_BASE + Math.floorMod(domain.hashCode(), ID_RANGE), notification)
    }

    private fun createChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Alertes pare-feu",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Prévient quand le pare-feu bloque un site dangereux."
        }
        manager.createNotificationChannel(channel) // sans effet s'il existe déjà
    }

    @Suppress("DEPRECATION")
    private fun builder(context: Context): Notification.Builder {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
        }
        // Sinon Android pourrait ajouter un bouton « Ouvrir le lien ».
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setAllowSystemGeneratedContextualActions(false)
        }
        return builder
    }
}
