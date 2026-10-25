package com.iheb.sentinel.firewall

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.iheb.sentinel.AppLanguage
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
        // Textes dans la langue choisie dans Réglages.
        val texts = AppLanguage.localized(context)
        createChannel(texts, manager)

        val defanged = DomainNames.defang(domain)
        val title = if (brand == null) {
            texts.getString(R.string.firewall_alert_title)
        } else {
            texts.getString(R.string.firewall_alert_title_brand, brand)
        }
        val text = if (brand == null) {
            texts.getString(R.string.firewall_alert_text, defanged)
        } else {
            texts.getString(R.string.firewall_alert_text_brand, defanged, brand)
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
            .setContentText(texts.getString(R.string.firewall_alert_title))
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

    private fun createChannel(texts: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            texts.getString(R.string.firewall_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = texts.getString(R.string.firewall_channel_description)
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
