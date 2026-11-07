package com.iheb.sentinel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Choix du réseau Wi-Fi à analyser, même quand un VPN est actif (SEN-18). */
class WifiNetworkPickTest {

    // Réseaux vus sur l'émulateur Pixel 8 (Android 17), pare-feu actif.
    private val nets = mapOf(
        "vpn" to Transports(wifi = true, vpn = true), // le VPN hérite de WIFI
        "mobile" to Transports(wifi = false, vpn = false),
        "wifi" to Transports(wifi = true, vpn = false),
    )

    private fun pick(active: String?, all: List<String>) =
        pickWifiNetwork(active, all) { nets.getValue(it) }

    @Test
    fun `sans VPN, le reseau par defaut Wi-Fi est garde`() {
        assertEquals("wifi", pick("wifi", listOf("mobile", "wifi")))
    }

    @Test
    fun `VPN par defaut avec transport WIFI, le vrai Wi-Fi est choisi`() {
        assertEquals("wifi", pick("vpn", listOf("vpn", "mobile", "wifi")))
    }

    @Test
    fun `VPN sur donnees mobiles, pas de Wi-Fi`() {
        assertNull(pick("vpn", listOf("vpn", "mobile")))
        assertNull(pick(null, emptyList()))
    }

    @Test
    fun `Wi-Fi sans internet, trouve parmi tous les reseaux`() {
        assertEquals("wifi", pick("mobile", listOf("mobile", "wifi")))
    }
}
