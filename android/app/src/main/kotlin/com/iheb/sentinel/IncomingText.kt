package com.iheb.sentinel

/**
 * Texte d'une alerte Sentinel, en attente que MainActivity le lise (SEN-06).
 * Seule AlertRelayActivity (non exportée) le remplit : une autre app ne peut
 * donc rien y mettre. Mémoire du processus uniquement, lu une seule fois.
 */
class AlertInbox {
    @Volatile
    private var pending: String? = null

    fun put(text: String?) {
        pending = text
    }

    /** Rend le texte en attente et l'efface. */
    @Synchronized
    fun take(): String? = pending.also { pending = null }
}

/** La boîte unique de l'app. */
val alertInbox = AlertInbox()

/** Action interne : « ouvre l'onglet Messages avec l'alerte en attente ». Sans texte. */
const val ACTION_OPEN_ALERT = "com.iheb.sentinel.action.OPEN_ALERT"

const val ACTION_SEND = "android.intent.action.SEND"
const val ACTION_PROCESS_TEXT = "android.intent.action.PROCESS_TEXT"

/**
 * Texte à analyser selon l'Intent reçu par MainActivity (exportée).
 * - Partage (SEND) et sélection de texte (PROCESS_TEXT) : texte de l'Intent.
 * - OPEN_ALERT : uniquement le texte confié par AlertRelayActivity ; un
 *   éventuel texte joint à l'Intent est ignoré.
 * - Toute autre action (dont l'ancienne CHECK_ALERT) : rien.
 */
fun incomingText(
    action: String?,
    sendText: CharSequence?,
    processText: CharSequence?,
    inbox: AlertInbox,
): String? = when (action) {
    ACTION_SEND -> cleanMessageText(sendText)
    ACTION_PROCESS_TEXT -> cleanMessageText(processText)
    ACTION_OPEN_ALERT -> inbox.take()
    else -> null
}
