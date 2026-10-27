package com.iheb.sentinel.firewall

/** Ce que fait un appui sur la tuile « Pare-feu Sentinel ». */
enum class TileAction {
    START,

    STOP,

    /** Ouvrir l'app sur l'écran du pare-feu (rien ne peut se faire d'ici). */
    OPEN_APP,
}

/** Petite ligne sous le nom de la tuile (Android 10+). */
enum class TileSubtitle {
    ON,
    OFF,

    /** Autorisation VPN jamais donnée (ou prise par un autre VPN). */
    NEEDS_PERMISSION,

    /** SEN-11 : DNS privé strict, le pare-feu ne verrait aucune requête. */
    STRICT_DNS,
}

/** État affiché : tuile allumée ou non, et sa petite ligne. */
data class TileDisplay(val active: Boolean, val subtitle: TileSubtitle)

/**
 * Règles de la tuile, sans Android (testées en JUnit).
 * [vpnAllowed] : VpnService.prepare() a renvoyé null.
 * [strictPrivateDns] : un serveur DNS privé strict est réglé (SEN-11).
 */
object FirewallTilePolicy {

    fun onClick(running: Boolean, vpnAllowed: Boolean, strictPrivateDns: Boolean): TileAction =
        when {
            // Couper marche toujours, même avec un DNS privé strict.
            running -> TileAction.STOP
            // Seule l'app peut afficher la demande d'autorisation d'Android.
            !vpnAllowed -> TileAction.OPEN_APP
            // Démarrer filtrerait du vide : l'app explique quoi régler.
            strictPrivateDns -> TileAction.OPEN_APP
            else -> TileAction.START
        }

    fun display(running: Boolean, vpnAllowed: Boolean, strictPrivateDns: Boolean): TileDisplay =
        when {
            running -> TileDisplay(active = true, subtitle = TileSubtitle.ON)
            !vpnAllowed -> TileDisplay(active = false, subtitle = TileSubtitle.NEEDS_PERMISSION)
            strictPrivateDns -> TileDisplay(active = false, subtitle = TileSubtitle.STRICT_DNS)
            else -> TileDisplay(active = false, subtitle = TileSubtitle.OFF)
        }
}
