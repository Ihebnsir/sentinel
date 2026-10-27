package com.iheb.sentinel.firewall

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.iheb.sentinel.ACTION_OPEN_FIREWALL
import com.iheb.sentinel.AppLanguage
import com.iheb.sentinel.MainActivity
import com.iheb.sentinel.R

/**
 * Tuile « Pare-feu Sentinel » des Paramètres rapides : allumée quand le
 * VPN filtre, un appui l'active ou le coupe. Si rien ne peut se faire
 * d'ici (autorisation VPN, DNS privé strict), ouvre l'écran du pare-feu.
 */
class FirewallTileService : TileService() {

    companion object {
        // Tuile visible en ce moment (panneau ouvert), sinon null.
        @Volatile
        private var listening: FirewallTileService? = null

        private val mainHandler = Handler(Looper.getMainLooper())

        /** Appelé par SentinelVpnService quand le filtrage démarre ou s'arrête. */
        fun refresh(context: Context) {
            mainHandler.post {
                val tile = listening
                if (tile != null) {
                    tile.refreshTile()
                    return@post
                }
                // Panneau fermé : Android rafraîchira à la prochaine ouverture.
                try {
                    requestListeningState(
                        context,
                        ComponentName(context, FirewallTileService::class.java),
                    )
                } catch (e: RuntimeException) {
                    // Tuile pas ajoutée, ou refus du système : sans gravité.
                }
            }
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        listening = this
        refreshTile()
    }

    override fun onStopListening() {
        if (listening === this) listening = null
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()
        // Écran verrouillé : on demande d'abord le déverrouillage, pour
        // qu'un inconnu ne puisse pas couper la protection.
        if (isLocked) unlockAndRun(::toggle) else toggle()
    }

    private fun toggle() {
        val action = FirewallTilePolicy.onClick(
            running = SentinelVpnService.isRunning,
            vpnAllowed = vpnAllowed(),
            strictPrivateDns = strictPrivateDns(),
        )
        when (action) {
            TileAction.STOP -> sendToService(SentinelVpnService.ACTION_STOP)
            TileAction.START -> if (!startFirewall()) openFirewallScreen()
            TileAction.OPEN_APP -> openFirewallScreen()
        }
        refreshTile()
    }

    private fun vpnAllowed(): Boolean = try {
        VpnService.prepare(this) == null
    } catch (e: RuntimeException) {
        false
    }

    private fun strictPrivateDns(): Boolean =
        UnderlyingNetworks.strictPrivateDnsServer(this) != null

    // Faux si Android refuse de démarrer le service depuis la tuile.
    private fun startFirewall(): Boolean {
        val intent = Intent(this, SentinelVpnService::class.java)
            .setAction(SentinelVpnService.ACTION_START)
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            true
        } catch (e: IllegalStateException) {
            // Android 12+ : ForegroundServiceStartNotAllowedException en hérite.
            false
        } catch (e: SecurityException) {
            false
        }
    }

    // Le service tourne déjà au premier plan : startService suffit.
    private fun sendToService(action: String) {
        try {
            startService(Intent(this, SentinelVpnService::class.java).setAction(action))
        } catch (e: IllegalStateException) {
            openFirewallScreen()
        }
    }

    // Ferme le panneau et ouvre l'app sur l'écran du pare-feu.
    private fun openFirewallScreen() {
        val intent = Intent(this, MainActivity::class.java)
            .setAction(ACTION_OPEN_FIREWALL)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ : seule la version avec PendingIntent est permise.
            startActivityAndCollapse(
                PendingIntent.getActivity(
                    this,
                    0,
                    intent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    private fun refreshTile() {
        val tile = qsTile ?: return
        val display = FirewallTilePolicy.display(
            running = SentinelVpnService.isRunning,
            vpnAllowed = vpnAllowed(),
            strictPrivateDns = strictPrivateDns(),
        )
        // Textes dans la langue choisie dans Réglages.
        val texts = AppLanguage.localized(this)
        tile.state = if (display.active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.icon = Icon.createWithResource(this, R.drawable.ic_stat_arch)
        tile.label = texts.getString(R.string.tile_label)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = texts.getString(
                when (display.subtitle) {
                    TileSubtitle.ON -> R.string.tile_on
                    TileSubtitle.OFF -> R.string.tile_off
                    TileSubtitle.NEEDS_PERMISSION -> R.string.tile_needs_permission
                    TileSubtitle.STRICT_DNS -> R.string.tile_strict_dns
                },
            )
        }
        tile.updateTile()
    }
}
