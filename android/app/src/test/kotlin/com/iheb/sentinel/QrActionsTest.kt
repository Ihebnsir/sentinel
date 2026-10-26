package com.iheb.sentinel

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Ce que Sentinel accepte d'ouvrir après un scan de QR code. */
class QrActionsTest {

    @Test
    fun `liens web http et https seulement`() {
        assertTrue(QrActions.isWebLink("https://www.exemple.tn/page?a=1"))
        assertTrue(QrActions.isWebLink("HTTP://exemple.com"))
        for (url in listOf(
            null, "", "javascript:alert(1)", "intent://x#Intent;end", "file:///sdcard/a",
            "https://", "https://exemple.com/a b", "ftp://exemple.com",
            "https:/exemple.com", "https://\nexemple.com",
        )) {
            assertFalse(url, QrActions.isWebLink(url))
        }
    }

    @Test
    fun `numeros normaux acceptes, codes USSD refuses`() {
        assertTrue(QrActions.isDialable("+216 71 123 456"))
        assertTrue(QrActions.isDialable("(01) 23-45.67"))
        assertTrue(QrActions.isDialable("85000")) // numéro court SMS
        for (number in listOf(null, "", "12", "*#06#", "*2767*3855#", "#31#0612", "71 12 abc")) {
            assertFalse(number, QrActions.isDialable(number))
        }
    }

    @Test
    fun `paiements reconnus seulement`() {
        assertTrue(QrActions.isPaymentUri("bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.01"))
        assertTrue(QrActions.isPaymentUri("upi://pay?pa=nom@banque&am=10"))
        for (uri in listOf(null, "", "bitcoin:", "paypal:x", "https://pay.exemple", "ethereum:0x1 2")) {
            assertFalse(uri, QrActions.isPaymentUri(uri))
        }
    }
}
