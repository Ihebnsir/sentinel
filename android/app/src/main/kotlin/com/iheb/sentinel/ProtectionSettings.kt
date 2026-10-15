package com.iheb.sentinel

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService

/**
 * L'option « Protection automatique » et l'état réel des autorisations.
 * Seul un oui/non est enregistré : jamais le contenu d'un message.
 */
object ProtectionSettings {
    private const val PREFS = "sentinel_protection"
    private const val KEY_ENABLED = "auto_protection_enabled"

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_ENABLED, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, enabled)
            .apply()
        if (enabled) {
            // Le service s'était détaché (option coupée) : on demande à
            // Android de le reconnecter.
            try {
                NotificationListenerService.requestRebind(listenerComponent(context))
            } catch (e: Exception) {
                // Accès pas encore accordé : rien à reconnecter.
            }
        } else {
            // Libère la mémoire du moteur Flutter d'arrière-plan.
            BackgroundAnalyzer.shutdown()
        }
    }

    fun listenerComponent(context: Context) =
        ComponentName(context, SentinelNotificationListener::class.java)

    /** L'utilisateur a-t-il accordé l'accès aux notifications à Sentinel ? */
    fun hasListenerAccess(context: Context): Boolean {
        val component = listenerComponent(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            val manager = context.getSystemService(NotificationManager::class.java)
            return manager.isNotificationListenerAccessGranted(component)
        }
        // Avant Android 8.1 : la liste est stockée dans les paramètres.
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == component }
    }

    /** Sentinel peut-il afficher des notifications (alertes) ? */
    fun notificationsAllowed(context: Context): Boolean =
        context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()

    /** L'état envoyé à Dart (lib/services/protection_service.dart). */
    fun status(context: Context): Map<String, Boolean> = mapOf(
        "listenerAccess" to hasListenerAccess(context),
        "notificationsAllowed" to notificationsAllowed(context),
        "enabled" to isEnabled(context),
    )
}
