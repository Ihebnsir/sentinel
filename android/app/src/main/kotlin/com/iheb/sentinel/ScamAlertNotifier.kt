package com.iheb.sentinel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/** Affiche l'alerte « Arnaque probable » de Sentinel. */
object ScamAlertNotifier {
    private const val CHANNEL_ID = "scam_alerts"
    private const val RED = 0xFFC2263A.toInt() // AppColors.rommen

    /**
     * [text] n'est pas affiché : il sert seulement, au tap, à pré-remplir
     * l'onglet Messages (il reste en mémoire, dans l'alerte, jusqu'au tap).
     */
    fun show(context: Context, id: Int, title: String, reason: String, text: String) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return
        createChannel(context, manager)

        // SEN-06 : relais non exporté, qui transmet le texte à MainActivity
        // par la mémoire (alertInbox), jamais par un Intent forgeable.
        val intent = Intent(context, AlertRelayActivity::class.java)
            .putExtra(Intent.EXTRA_TEXT, text)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val tap = PendingIntent.getActivity(
            context,
            id, // un code par alerte, sinon les textes se mélangent
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        // Écran verrouillé : version neutre, sans la raison.
        val publicVersion = builder(context)
            .setSmallIcon(R.drawable.ic_stat_arch)
            .setColor(RED)
            .setContentTitle("Sentinel")
            .setContentText("Arnaque probable détectée")
            .build()

        val notification = builder(context)
            .setSmallIcon(R.drawable.ic_stat_arch)
            .setColor(RED)
            .setContentTitle(title)
            .setContentText(reason)
            .setStyle(Notification.BigTextStyle().bigText(reason))
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()

        manager.notify(id, notification)
    }

    private fun createChannel(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Alertes arnaques",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Prévient quand un message reçu ressemble à une arnaque."
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
        // Sécurité : sinon Android ajoute tout seul un bouton « Ouvrir le
        // lien » (action intelligente) qui ouvrirait le site de l'arnaque.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setAllowSystemGeneratedContextualActions(false)
        }
        return builder
    }
}
