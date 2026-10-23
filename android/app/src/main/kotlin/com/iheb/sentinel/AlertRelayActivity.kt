package com.iheb.sentinel

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Relais des alertes « Arnaque probable » (SEN-06).
 * Non exportée (exported="false") : seule la notification de Sentinel peut
 * l'ouvrir, avec son PendingIntent immuable. Elle confie le texte à
 * [alertInbox] puis ouvre MainActivity avec ACTION_OPEN_ALERT, sans texte.
 * Une autre app qui envoie ACTION_OPEN_ALERT trouve donc la boîte vide.
 */
class AlertRelayActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        alertInbox.put(cleanMessageText(intent?.getCharSequenceExtra(Intent.EXTRA_TEXT)))
        startActivity(
            Intent(this, MainActivity::class.java)
                .setAction(ACTION_OPEN_ALERT)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        )
        finish()
    }
}
