package com.iheb.sentinel

import android.app.Notification
import android.os.Bundle
import android.provider.Telephony
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Reçoit les notifications du téléphone (si l'utilisateur l'a autorisé)
 * et fait analyser celles des applications de messagerie.
 *
 * Règle d'or : le texte d'un message n'est JAMAIS écrit dans les logs
 * ni enregistré. Il ne vit qu'en mémoire, le temps de l'analyse.
 */
class SentinelNotificationListener : NotificationListenerService() {

    // Empreintes (hash) des derniers messages analysés, pas leur texte.
    private val recentHashes = ArrayDeque<Int>()

    override fun onListenerConnected() {
        super.onListenerConnected()
        // Option coupée : on demande à Android de ne plus rien nous envoyer.
        if (!ProtectionSettings.isEnabled(this)) requestUnbind()
    }

    override fun onListenerDisconnected() {
        BackgroundAnalyzer.shutdown()
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!ProtectionSettings.isEnabled(this)) {
            requestUnbind()
            return
        }
        val packageName = sbn.packageName
        if (packageName == this.packageName) return // nos propres alertes
        val isSms = isSmsApp(packageName)
        if (!isSms && packageName !in CHAT_APPS) return

        val notification = sbn.notification ?: return
        // Résumés de groupe (« 3 nouveaux messages ») et notifications permanentes.
        if (sbn.isOngoing) return
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        val text = messageTextOf(notification) ?: return
        val hash = (packageName + '\u0000' + text).hashCode()
        if (hash in recentHashes) return // déjà analysé (notification mise à jour)
        recentHashes.addLast(hash)
        if (recentHashes.size > MAX_RECENT) recentHashes.removeFirst()

        val arguments = mapOf(
            "text" to text,
            "packageName" to packageName,
            "isSms" to isSms,
        )
        BackgroundAnalyzer.analyze(this, arguments) { result ->
            // Pas d'alerte pour « Suspect » : on évite la fatigue des alertes.
            if (result?.verdict == "arnaque") {
                ScamAlertNotifier.show(
                    applicationContext,
                    id = hash,
                    title = result.alertTitle,
                    reason = result.mainReason,
                    text = text,
                )
            }
        }
    }

    private fun isSmsApp(packageName: String): Boolean =
        packageName in SMS_APPS ||
            packageName == Telephony.Sms.getDefaultSmsPackage(this)

    // MessagingStyle (dernier message), sinon texte long, sinon texte court.
    private fun messageTextOf(notification: Notification): String? {
        val extras = notification.extras ?: return null
        @Suppress("DEPRECATION")
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        val last = messages?.lastOrNull() as? Bundle
        if (last != null) {
            // Sans expéditeur, c'est l'utilisateur qui a écrit (réponse rapide).
            val fromMe = last.getCharSequence("sender") == null &&
                !last.containsKey("sender_person")
            if (fromMe) return null
            return cleanMessageText(last.getCharSequence("text"))
        }
        return cleanMessageText(
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT),
        )
    }

    companion object {
        private const val MAX_RECENT = 50

        // Applications SMS connues (en plus de l'app SMS par défaut).
        private val SMS_APPS = setOf(
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging",
        )

        // Messageries « chat » ; le nom affiché est choisi côté Dart.
        private val CHAT_APPS = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",
            "com.facebook.orca",
            "org.telegram.messenger",
            "com.viber.voip",
        )
    }
}
