package com.iheb.sentinel

/**
 * Ce que Sentinel accepte d'ouvrir après un scan de QR code.
 * Seconde vérification, après celle de Dart (lib/services/qr/qr_safety.dart) :
 * tout le reste (javascript:, intent:, file:, codes USSD…) est refusé.
 * Fonctions pures, testées sans téléphone (QrActionsTest).
 */
object QrActions {

    // Applications de paiement acceptées (même liste que qr_content.dart).
    val paymentSchemes = setOf(
        "bitcoin", "bitcoincash", "litecoin", "ethereum", "monero", "lightning", "upi",
    )

    // L'arobase (user@site) reste permis : Dart l'a déjà signalé (Suspect).
    private val webLink = Regex("""^(?i)https?://[^\s/?#]+[^\s]*$""")

    // Chiffres, +, espaces, tirets, points, parenthèses. Jamais * ni # :
    // ce sont des codes USSD (ex : effacer le téléphone, renvoi d'appel).
    private val phoneNumber = Regex("""^\+?[0-9 ().-]{3,30}$""")

    fun isWebLink(url: String?): Boolean = url != null && webLink.matches(url)

    fun isDialable(number: String?): Boolean =
        number != null && phoneNumber.matches(number) && number.count { it.isDigit() } >= 3

    fun isPaymentUri(uri: String?): Boolean {
        if (uri == null || uri.any { it.isWhitespace() }) return false
        val scheme = uri.substringBefore(':', "").lowercase()
        return scheme in paymentSchemes && uri.length > scheme.length + 1
    }
}
