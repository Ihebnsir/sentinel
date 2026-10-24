package com.iheb.sentinel.firewall

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
import android.os.Build

/**
 * « Autoriser le DNS non chiffré sur ce réseau » (SEN-10), désactivé par
 * défaut. L'accord vaut pour un réseau précis : s'il change (autre Wi-Fi,
 * données mobiles), il tombe tout seul. Mémoire seulement : perdu à l'arrêt.
 */
class PlainDnsPermission {
    @Volatile
    private var allowedFor: String? = null

    fun allow(networkKey: String?) {
        allowedFor = networkKey
    }

    fun revoke() {
        allowedFor = null
    }

    fun isAllowedFor(networkKey: String?): Boolean =
        networkKey != null && networkKey == allowedFor
}

/** Les réseaux réels sous le VPN (Wi-Fi, données mobiles…). */
object UnderlyingNetworks {

    private fun connectivity(context: Context) =
        context.getSystemService(ConnectivityManager::class.java)

    // Réseaux avec Internet qui ne sont pas un VPN.
    @Suppress("DEPRECATION") // allNetworks : aucune alternative avant Android 12
    private fun physical(context: Context): List<Pair<Long, LinkProperties?>> {
        val manager = connectivity(context) ?: return emptyList()
        return manager.allNetworks.mapNotNull { network ->
            val caps = manager.getNetworkCapabilities(network) ?: return@mapNotNull null
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return@mapNotNull null
            if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) return@mapNotNull null
            network.networkHandle to manager.getLinkProperties(network)
        }
    }

    /** Identifiant du réseau actuel ; null si aucun réseau. */
    fun currentKey(context: Context): String? =
        physical(context).map { it.first }.sorted().joinToString(",").ifEmpty { null }

    /**
     * Nom du serveur DNS privé en mode strict (« Nom d'hôte du fournisseur »),
     * ou null (désactivé ou Automatique). Android 9+ (SEN-11).
     */
    fun strictPrivateDnsServer(context: Context): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return null
        return strictServer(physical(context).map { it.second?.privateDnsServerName })
    }

    /** Règle pure (JUnit) : un nom non vide = mode strict. */
    fun strictServer(serverNames: List<String?>): String? =
        serverNames.firstOrNull { !it.isNullOrBlank() }
}
