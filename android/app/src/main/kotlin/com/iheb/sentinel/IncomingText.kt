package com.iheb.sentinel

/**
 * Action interne : « ouvre l'écran du pare-feu » (tuile des Paramètres
 * rapides). Sans données : une autre app qui l'envoie ouvre seulement cet écran.
 */
const val ACTION_OPEN_FIREWALL = "com.iheb.sentinel.action.OPEN_FIREWALL"

const val ACTION_SEND = "android.intent.action.SEND"
const val ACTION_PROCESS_TEXT = "android.intent.action.PROCESS_TEXT"

// Assez pour un message qui contient un lien ; au-delà, coupé.
const val MAX_SHARED_LENGTH = 5000

/**
 * Texte reçu par MainActivity (exportée), où l'onglet Liens cherchera un lien.
 * - Partage (SEND) et sélection de texte (PROCESS_TEXT) : texte de l'Intent.
 * - Toute autre action (dont les anciennes CHECK_ALERT et OPEN_ALERT) : rien.
 */
fun incomingText(action: String?, sendText: CharSequence?, processText: CharSequence?): String? =
    when (action) {
        ACTION_SEND -> cleanSharedText(sendText)
        ACTION_PROCESS_TEXT -> cleanSharedText(processText)
        else -> null
    }

/** Sans espaces autour, vide → null, coupé si trop long. */
fun cleanSharedText(raw: CharSequence?): String? {
    val text = raw?.toString()?.trim()
    if (text.isNullOrEmpty()) return null
    if (text.length <= MAX_SHARED_LENGTH) return text
    // Coupe sans casser un emoji (fait de deux caractères).
    val end = if (Character.isHighSurrogate(text[MAX_SHARED_LENGTH - 1])) {
        MAX_SHARED_LENGTH - 1
    } else {
        MAX_SHARED_LENGTH
    }
    return text.substring(0, end)
}
