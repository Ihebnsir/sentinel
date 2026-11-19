package com.iheb.sentinel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Texte reçu d'une autre app, pour l'onglet Liens. */
class IncomingTextTest {

    @Test
    fun `partage et selection de texte`() {
        assertEquals("https://biat.com.tn", incomingText(ACTION_SEND, "  https://biat.com.tn  ", null))
        assertEquals("Lien", incomingText(ACTION_PROCESS_TEXT, null, "Lien"))
        assertNull(incomingText(ACTION_SEND, "   ", null))
        assertNull(incomingText(ACTION_PROCESS_TEXT, null, null))
    }

    @Test
    fun `texte trop long - coupe sans casser un emoji`() {
        val long = "a".repeat(MAX_SHARED_LENGTH + 10)
        assertEquals(MAX_SHARED_LENGTH, incomingText(ACTION_SEND, long, null)!!.length)
        val emoji = "a".repeat(MAX_SHARED_LENGTH - 1) + "😀"
        assertEquals(MAX_SHARED_LENGTH - 1, cleanSharedText(emoji)!!.length)
    }

    @Test
    fun `anciennes actions d'alerte et action inconnue - rien`() {
        assertNull(incomingText("com.iheb.sentinel.action.CHECK_ALERT", "x", null))
        assertNull(incomingText("com.iheb.sentinel.action.OPEN_ALERT", "x", "y"))
        assertNull(incomingText(null, "x", "y"))
        assertNull(incomingText("android.intent.action.VIEW", "x", null))
    }
}
