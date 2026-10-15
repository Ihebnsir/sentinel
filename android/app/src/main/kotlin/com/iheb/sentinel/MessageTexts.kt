package com.iheb.sentinel

// Un SMS fait rarement plus de quelques centaines de caractères.
const val MAX_MESSAGE_LENGTH = 5000

/** Nettoie un texte reçu : sans espaces autour, vide → null, coupé si trop long. */
fun cleanMessageText(raw: CharSequence?): String? {
    val text = raw?.toString()?.trim()
    if (text.isNullOrEmpty()) return null
    if (text.length <= MAX_MESSAGE_LENGTH) return text
    // Coupe sans casser un emoji (fait de deux caractères).
    val end = if (Character.isHighSurrogate(text[MAX_MESSAGE_LENGTH - 1])) {
        MAX_MESSAGE_LENGTH - 1
    } else {
        MAX_MESSAGE_LENGTH
    }
    return text.substring(0, end)
}
