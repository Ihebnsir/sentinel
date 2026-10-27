package com.iheb.sentinel.firewall

import org.junit.Assert.assertEquals
import org.junit.Test

/** Tuile des Paramètres rapides : que faire d'un appui, quoi afficher. */
class FirewallTilePolicyTest {

    private fun click(running: Boolean, vpnAllowed: Boolean = true, strict: Boolean = false) =
        FirewallTilePolicy.onClick(running, vpnAllowed, strict)

    private fun display(running: Boolean, vpnAllowed: Boolean = true, strict: Boolean = false) =
        FirewallTilePolicy.display(running, vpnAllowed, strict)

    @Test
    fun `pare-feu coupe et tout est pret - appui = demarrer`() {
        assertEquals(TileAction.START, click(running = false))
    }

    @Test
    fun `pare-feu actif - appui = arreter`() {
        assertEquals(TileAction.STOP, click(running = true))
    }

    @Test
    fun `autorisation VPN jamais donnee - ouvrir l'app, pas d'echec silencieux`() {
        assertEquals(TileAction.OPEN_APP, click(running = false, vpnAllowed = false))
    }

    @Test
    fun `SEN-11 DNS prive strict - ouvrir l'app au lieu de demarrer`() {
        assertEquals(TileAction.OPEN_APP, click(running = false, strict = true))
        assertEquals(TileAction.OPEN_APP, click(running = false, vpnAllowed = false, strict = true))
    }

    @Test
    fun `couper marche toujours, meme avec DNS strict ou autorisation retiree`() {
        assertEquals(TileAction.STOP, click(running = true, strict = true))
        assertEquals(TileAction.STOP, click(running = true, vpnAllowed = false))
    }

    @Test
    fun `affichage - allumee seulement quand le pare-feu filtre`() {
        assertEquals(TileDisplay(true, TileSubtitle.ON), display(running = true))
        assertEquals(TileDisplay(true, TileSubtitle.ON), display(running = true, strict = true))
        assertEquals(TileDisplay(false, TileSubtitle.OFF), display(running = false))
    }

    @Test
    fun `affichage - la petite ligne dit pourquoi l'app va s'ouvrir`() {
        assertEquals(
            TileDisplay(false, TileSubtitle.NEEDS_PERMISSION),
            display(running = false, vpnAllowed = false),
        )
        assertEquals(TileDisplay(false, TileSubtitle.STRICT_DNS), display(running = false, strict = true))
        // Les deux : l'autorisation d'abord (c'est la première étape dans l'app).
        assertEquals(
            TileDisplay(false, TileSubtitle.NEEDS_PERMISSION),
            display(running = false, vpnAllowed = false, strict = true),
        )
    }

    @Test
    fun `l'affichage annonce toujours ce que fera l'appui`() {
        for (running in listOf(true, false)) {
            for (allowed in listOf(true, false)) {
                for (strict in listOf(true, false)) {
                    val action = click(running, allowed, strict)
                    val shown = display(running, allowed, strict)
                    val expected = when (shown.subtitle) {
                        TileSubtitle.ON -> TileAction.STOP
                        TileSubtitle.OFF -> TileAction.START
                        TileSubtitle.NEEDS_PERMISSION, TileSubtitle.STRICT_DNS -> TileAction.OPEN_APP
                    }
                    assertEquals("$running/$allowed/$strict", expected, action)
                }
            }
        }
    }
}
