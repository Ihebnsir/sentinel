package com.iheb.sentinel.weekly

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import com.iheb.sentinel.AppLanguage
import com.iheb.sentinel.R

/**
 * Notification « Votre bilan de la semaine est prêt ». Texte neutre, sans
 * aucun chiffre : rien de sensible sur l'écran verrouillé.
 */
object WeeklyReportNotifier {
    private const val CHANNEL_ID = "weekly_report"
    private const val NOTIFICATION_ID = 0x5E7702
    private const val BLUE = 0xFF1F5FA8.toInt() // AppColors.bleu

    /** Faux si les notifications de Sentinel sont coupées. */
    fun show(context: Context): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        if (!manager.areNotificationsEnabled()) return false
        val texts = AppLanguage.localized(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                texts.getString(R.string.weekly_channel_name),
                NotificationManager.IMPORTANCE_LOW, // sans son ni bandeau
            ).apply { description = texts.getString(R.string.weekly_channel_description) }
            manager.createNotificationChannel(channel)
        }

        // Ouvre simplement Sentinel (rien n'est transmis).
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val tap = launch?.let {
            PendingIntent.getActivity(context, NOTIFICATION_ID, it, PendingIntent.FLAG_IMMUTABLE)
        }
        val text = texts.getString(R.string.weekly_notification_text)

        val publicVersion = builder(context)
            .setSmallIcon(R.drawable.ic_stat_arch)
            .setColor(BLUE)
            .setContentTitle("Sentinel")
            .setContentText(text)
            .build()

        val notification = builder(context)
            .setSmallIcon(R.drawable.ic_stat_arch)
            .setColor(BLUE)
            .setContentTitle(texts.getString(R.string.weekly_notification_title))
            .setContentText(text)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .setAutoCancel(true)
            .apply { tap?.let { setContentIntent(it) } }
            .build()
        manager.notify(NOTIFICATION_ID, notification)
        return true
    }

    @Suppress("DEPRECATION")
    private fun builder(context: Context): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context).setPriority(Notification.PRIORITY_LOW)
        }
}
