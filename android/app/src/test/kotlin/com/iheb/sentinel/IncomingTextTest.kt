package com.iheb.sentinel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** SEN-06 : seul Sentinel peut faire analyser un texte « d'alerte ». */
class IncomingTextTest {

    private val oldCheckAlert = "com.iheb.sentinel.action.CHECK_ALERT"

    @Test
    fun `ancienne action CHECK_ALERT envoyee par une autre app - ignoree`() {
        val inbox = AlertInbox()
        assertNull(incomingText(oldCheckAlert, "Aucun risque.", null, inbox))
    }

    @Test
    fun `OPEN_ALERT forge - le texte joint est ignore, boite vide`() {
        val inbox = AlertInbox()
        assertNull(incomingText(ACTION_OPEN_ALERT, "Texte forgé", "autre", inbox))
    }

    @Test
    fun `OPEN_ALERT apres le relais - texte de l'alerte, une seule fois`() {
        val inbox = AlertInbox()
        inbox.put("Votre colis est bloqué")
        assertEquals("Votre colis est bloqué", incomingText(ACTION_OPEN_ALERT, "forgé", null, inbox))
        assertNull(incomingText(ACTION_OPEN_ALERT, null, null, inbox)) // déjà lu
    }

    @Test
    fun `partage et selection de texte - inchanges`() {
        val inbox = AlertInbox()
        assertEquals("Bonjour", incomingText(ACTION_SEND, "  Bonjour  ", null, inbox))
        assertEquals("Lien", incomingText(ACTION_PROCESS_TEXT, null, "Lien", inbox))
        assertNull(incomingText(ACTION_SEND, "   ", null, inbox))
        val long = "a".repeat(MAX_MESSAGE_LENGTH + 10)
        assertEquals(MAX_MESSAGE_LENGTH, incomingText(ACTION_SEND, long, null, inbox)!!.length)
    }

    @Test
    fun `le partage ne vide pas une alerte en attente`() {
        val inbox = AlertInbox()
        inbox.put("alerte")
        incomingText(ACTION_SEND, "partage", null, inbox)
        assertEquals("alerte", inbox.take())
    }

    @Test
    fun `action inconnue - rien`() {
        assertNull(incomingText(null, "x", "y", AlertInbox()))
        assertNull(incomingText("android.intent.action.VIEW", "x", null, AlertInbox()))
    }
}
