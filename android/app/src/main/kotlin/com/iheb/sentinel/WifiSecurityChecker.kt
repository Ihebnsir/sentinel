package com.iheb.sentinel

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Sécurité du Wi-Fi actuel, sans permission de localisation :
 * type de chiffrement, portail captif et DNS privé.
 * Ne lit jamais le nom (SSID) ni l'adresse (BSSID) du réseau.
 */
class WifiSecurityChecker(private val activity: Activity, messenger: BinaryMessenger) {

    // Même nom que dans lib/services/wifi_service.dart.
    private val channel = MethodChannel(messenger, "com.iheb.sentinel/wifi")

    private val connectivity =
        activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private val mainHandler = Handler(Looper.getMainLooper())

    // Non null pendant l'écoute des changements de réseau.
    private var callback: ConnectivityManager.NetworkCallback? = null

    // Android envoie souvent plusieurs événements d'affilée :
    // on attend un court instant et on n'envoie qu'un seul état à Dart.
    private val notifyDart = Runnable {
        if (callback == null) return@Runnable // écoute arrêtée entre-temps
        channel.invokeMethod("onWifiChanged", safeStatus())
    }

    init {
        channel.setMethodCallHandler(::onMethodCall)
    }

    fun dispose() {
        stopListening()
        channel.setMethodCallHandler(null)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getWifiStatus" -> try {
                result.success(getStatus())
            } catch (e: Exception) {
                result.error("CHECK_FAILED", e.message, null)
            }
            "startListening" -> {
                startListening()
                result.success(null)
            }
            "stopListening" -> {
                stopListening()
                result.success(null)
            }
            "openPrivateDnsSettings" -> {
                openPrivateDnsSettings()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // État envoyé à Dart (Map). « connected » faux : pas de Wi-Fi.
    fun getStatus(): Map<String, Any?> {
        val network = findWifiNetwork()
            ?: return mapOf("connected" to false, "sdkInt" to Build.VERSION.SDK_INT)
        val caps = connectivity.getNetworkCapabilities(network)
        val link = connectivity.getLinkProperties(network)
        return mapOf(
            "connected" to true,
            "security" to securityType(caps),
            "captivePortal" to
                (caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL) == true),
            "privateDnsActive" to privateDnsActive(link),
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    // En cas d'erreur pendant l'écoute, on préfère « inconnu » à un plantage.
    private fun safeStatus(): Map<String, Any?> = try {
        getStatus()
    } catch (e: Exception) {
        mapOf("connected" to true, "security" to "unknown", "sdkInt" to Build.VERSION.SDK_INT)
    }

    // Cherche le réseau Wi-Fi parmi tous les réseaux connectés : avec un VPN
    // ou un Wi-Fi sans internet, le réseau « par défaut » n'est pas le Wi-Fi.
    private fun findWifiNetwork(): Network? {
        val active = connectivity.activeNetwork
        if (active != null && isWifi(active)) return active
        @Suppress("DEPRECATION") // pas de remplaçant sans écoute permanente
        return connectivity.allNetworks.firstOrNull { isWifi(it) }
    }

    private fun isWifi(network: Network): Boolean =
        connectivity.getNetworkCapabilities(network)
            ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true

    // Android 12+ : WifiInfo.getCurrentSecurityType(). Avant, le type de
    // sécurité n'est lisible qu'avec la localisation : « unknown ».
    private fun securityType(caps: NetworkCapabilities?): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return "unknown"
        val info = caps?.transportInfo as? WifiInfo ?: return "unknown"
        return when (info.currentSecurityType) {
            WifiInfo.SECURITY_TYPE_OPEN -> "open"
            WifiInfo.SECURITY_TYPE_OWE -> "owe"
            WifiInfo.SECURITY_TYPE_WEP -> "wep"
            // Android regroupe WPA et WPA2 « Personnel » sous PSK.
            WifiInfo.SECURITY_TYPE_PSK -> "wpa2"
            WifiInfo.SECURITY_TYPE_SAE,
            WifiInfo.SECURITY_TYPE_DPP -> "wpa3"
            WifiInfo.SECURITY_TYPE_EAP,
            WifiInfo.SECURITY_TYPE_EAP_WPA3_ENTERPRISE,
            WifiInfo.SECURITY_TYPE_EAP_WPA3_ENTERPRISE_192_BIT,
            WifiInfo.SECURITY_TYPE_PASSPOINT_R1_R2,
            WifiInfo.SECURITY_TYPE_PASSPOINT_R3,
            WifiInfo.SECURITY_TYPE_OSEN -> "enterprise"
            else -> "unknown" // WAPI (Chine) ou type non reconnu
        }
    }

    // Android 9+ seulement ; null avant (Dart l'affiche comme « inconnu »).
    private fun privateDnsActive(link: LinkProperties?): Boolean? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return null
        return link?.isPrivateDnsActive
    }

    // Écoute les réseaux Wi-Fi (connexion, perte, changement de réglages).
    private fun startListening() {
        if (callback != null) return
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = scheduleNotify()
            override fun onLost(network: Network) = scheduleNotify()
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) =
                scheduleNotify()
            override fun onLinkPropertiesChanged(network: Network, link: LinkProperties) =
                scheduleNotify()
        }
        try {
            connectivity.registerNetworkCallback(request, cb)
            callback = cb
        } catch (e: RuntimeException) {
            // Trop d'écoutes enregistrées (limite Android) : on s'en passe.
        }
    }

    private fun stopListening() {
        val cb = callback ?: return
        callback = null
        mainHandler.removeCallbacks(notifyDart)
        try {
            connectivity.unregisterNetworkCallback(cb)
        } catch (e: IllegalArgumentException) {
            // Déjà désenregistré.
        }
    }

    // Appelé sur un thread Android : on repasse sur le thread principal.
    private fun scheduleNotify() {
        mainHandler.removeCallbacks(notifyDart)
        mainHandler.postDelayed(notifyDart, 400)
    }

    // Pas d'écran « DNS privé » public : on ouvre « Réseau et Internet »
    // (le DNS privé s'y trouve, parfois sous « Avancé »).
    private fun openPrivateDnsSettings() {
        try {
            activity.startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
        } catch (e: ActivityNotFoundException) {
            activity.startActivity(Intent(Settings.ACTION_SETTINGS))
        }
    }
}
