package com.iheb.sentinel.firewall

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import com.iheb.sentinel.MainActivity
import com.iheb.sentinel.R
import java.io.FileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

/**
 * Pare-feu DNS local. Le VPN ne capte QUE les paquets envoyés au serveur
 * DNS virtuel : le reste du trafic ne passe jamais par Sentinel.
 * Aucun domaine demandé n'est journalisé : seuls des compteurs existent.
 */
class SentinelVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.iheb.sentinel.firewall.START"
        const val ACTION_STOP = "com.iheb.sentinel.firewall.STOP"

        // Adresses privées, jamais utilisées sur Internet.
        private const val TUN_ADDRESS_V4 = "10.111.222.1"
        private const val DNS_ADDRESS_V4 = "10.111.222.2"
        private const val TUN_ADDRESS_V6 = "fdc5:3a71:9e04::1" // ULA (fc00::/7)
        private const val DNS_ADDRESS_V6 = "fdc5:3a71:9e04::2"

        // Quad9, puis son adresse de secours.
        private val UPSTREAMS = listOf("9.9.9.9", "149.112.112.112")
        private const val UPSTREAM_TIMEOUT_MS = 2000
        private const val MTU = 1500
        private const val IP_UDP_HEADERS = 48 // IPv6 (40) + UDP (8), le pire cas

        private const val CHANNEL_ID = "dns_firewall"
        private const val NOTIFICATION_ID = 2001

        /** Vrai tant que le filtrage tourne. Lu par FirewallChannel. */
        @Volatile
        var isRunning = false
            private set

        // Compteurs en mémoire, remis à zéro à chaque démarrage.
        val totalQueries = AtomicLong()
        val blockedQueries = AtomicLong()
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private var tun: ParcelFileDescriptor? = null
    private var tunOutput: FileOutputStream? = null
    private val outputLock = Any()

    // Tube pour réveiller la boucle : fermer stopWrite la fait sortir de poll().
    private var stopRead: FileDescriptor? = null
    private var stopWrite: FileDescriptor? = null

    private var readerThread: Thread? = null

    @Volatile
    private var forwarders: ThreadPoolExecutor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopFirewall()
            return START_NOT_STICKY
        }
        // ACTION_START, ou relance par Android (intent null, VPN permanent).
        startFirewall()
        return START_STICKY
    }

    // Un autre VPN a pris la place, ou l'utilisateur a coupé dans les réglages.
    override fun onRevoke() {
        stopFirewall()
    }

    override fun onDestroy() {
        stopFirewall()
        super.onDestroy()
    }

    private fun startFirewall() {
        // Android exige startForeground() peu après le démarrage du service.
        showForegroundNotification()
        if (isRunning) return

        val pfd = try {
            establishTun()
        } catch (e: Exception) {
            null // adresse refusée, VPN non autorisé…
        }
        if (pfd == null) {
            stopFirewall() // pas d'autorisation VPN (prepare non accepté)
            return
        }
        val pipe = try {
            Os.pipe()
        } catch (e: ErrnoException) {
            pfd.close()
            stopFirewall()
            return
        }

        tun = pfd
        tunOutput = FileOutputStream(pfd.fileDescriptor)
        stopRead = pipe[0]
        stopWrite = pipe[1]
        totalQueries.set(0)
        blockedQueries.set(0)

        // 4 transferts en parallèle au plus ; file pleine : requête ignorée
        // (le téléphone réessaiera de lui-même).
        forwarders = ThreadPoolExecutor(
            4, 4, 30, TimeUnit.SECONDS,
            ArrayBlockingQueue(64),
            ThreadPoolExecutor.DiscardPolicy(),
        ).apply { allowCoreThreadTimeOut(true) }

        // Les listes se chargent en arrière-plan (FirewallEngine) : le VPN
        // démarre tout de suite et filtre dès qu'elles sont prêtes.
        val filter = DnsFilter { name -> FirewallEngine.policy.check(name) }
        readerThread = Thread({ readLoop(pfd.fileDescriptor, pipe[0], filter) }, "sentinel-dns")
            .apply { start() }
        isRunning = true
        FirewallEngine.onVpnStarted(this)
    }

    private fun establishTun(): ParcelFileDescriptor? {
        val builder = Builder()
            .setSession("Sentinel")
            .setMtu(MTU)
            .addAddress(TUN_ADDRESS_V4, 32)
            .addDnsServer(DNS_ADDRESS_V4)
            .addRoute(DNS_ADDRESS_V4, 32) // uniquement le DNS virtuel
            .addAddress(TUN_ADDRESS_V6, 128)
            .addDnsServer(DNS_ADDRESS_V6)
            .addRoute(DNS_ADDRESS_V6, 128)
            .setConfigureIntent(openAppIntent())
        // Pas d'addDisallowedApplication : nos propres requêtes vers Quad9
        // sont exclues une par une avec protect() (voir forward()).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Le VPN suit le réseau réel (Wi-Fi gratuit, données facturées…).
            builder.setMetered(false)
        }
        return builder.establish() // null si l'autorisation VPN manque
    }

    /** Boucle du thread dédié : lit les paquets du TUN jusqu'à l'arrêt. */
    private fun readLoop(tunFd: FileDescriptor, stopFd: FileDescriptor, filter: DnsFilter) {
        val input = FileInputStream(tunFd)
        val buffer = ByteArray(Short.MAX_VALUE.toInt())
        val tunPoll = StructPollfd().apply {
            fd = tunFd
            events = OsConstants.POLLIN.toShort()
        }
        val stopPoll = StructPollfd().apply {
            fd = stopFd
            events = OsConstants.POLLIN.toShort()
        }
        val polls = arrayOf(tunPoll, stopPoll)
        try {
            while (true) {
                tunPoll.revents = 0
                stopPoll.revents = 0
                try {
                    Os.poll(polls, -1) // attend un paquet ou l'arrêt
                } catch (e: ErrnoException) {
                    if (e.errno == OsConstants.EINTR) continue
                    throw e
                }
                if (stopPoll.revents.toInt() != 0) return // arrêt demandé
                val events = tunPoll.revents.toInt()
                if (events and (OsConstants.POLLERR or OsConstants.POLLHUP) != 0) break
                if (events and OsConstants.POLLIN == 0) continue
                val length = try {
                    input.read(buffer)
                } catch (e: IOException) {
                    continue // rien à lire finalement
                }
                if (length > 0) handlePacket(filter, buffer, length)
            }
        } catch (e: Exception) {
            // Erreur inattendue : on arrête proprement plutôt que planter.
        }
        // TUN fermé ou en erreur : arrêt complet, sur le thread principal
        // (sauf si une nouvelle session a démarré entre-temps).
        val thisThread = Thread.currentThread()
        mainHandler.post { if (readerThread === thisThread) stopFirewall() }
    }

    private fun handlePacket(filter: DnsFilter, buffer: ByteArray, length: Int) {
        when (val decision = try {
            filter.decide(buffer, length)
        } catch (e: Exception) {
            FilterDecision.Ignore // paquet mal formé : ignoré sans planter
        }) {
            is FilterDecision.Ignore -> Unit
            is FilterDecision.Blocked -> {
                totalQueries.incrementAndGet()
                blockedQueries.incrementAndGet()
                FirewallEngine.blockedByCategory[decision.category]?.incrementAndGet()
                writeToTun(decision.packet)
                maybeAlert(decision)
            }
            is FilterDecision.Forward -> {
                totalQueries.incrementAndGet()
                forwarders?.execute { forward(filter, decision) }
            }
        }
    }

    // Malware et hameçonnage seulement, une fois par domaine et par heure.
    // Le nom passe en mémoire jusqu'à la notification, sans être enregistré.
    private fun maybeAlert(decision: FilterDecision.Blocked) {
        if (!decision.category.alerts) return
        if (!FirewallEngine.alertLimiter.tryAcquire(decision.name)) return
        val name = decision.name
        mainHandler.post { FirewallAlertNotifier.show(this, name) }
    }

    /** Envoie la requête à Quad9 et réécrit sa réponse dans le TUN. */
    private fun forward(filter: DnsFilter, decision: FilterDecision.Forward) {
        val request = decision.udp.payload
        for (upstream in UPSTREAMS) {
            val response = askUpstream(upstream, request, decision.query) ?: continue
            // Trop grande pour un seul paquet : échec plutôt qu'un paquet perdu.
            val message = if (response.size + IP_UDP_HEADERS > MTU) {
                DnsPacket.buildEmptyResponse(request, decision.query, DnsPacket.RCODE_SERVFAIL)
            } else {
                response
            }
            writeToTun(filter.replyTo(decision.udp, message))
            return
        }
        // Aucune réponse : pas de paquet, le téléphone réessaiera.
    }

    private fun askUpstream(upstream: String, request: ByteArray, query: DnsQuery): ByteArray? {
        try {
            DatagramSocket().use { socket ->
                // protect() : ce socket sort par le vrai réseau, sans repasser
                // dans le VPN (sinon la requête tournerait en boucle).
                if (!protect(socket)) return null
                socket.soTimeout = UPSTREAM_TIMEOUT_MS
                // Adresse écrite en chiffres : aucune résolution DNS ici.
                socket.connect(InetAddress.getByName(upstream), DnsFilter.DNS_PORT)
                socket.send(DatagramPacket(request, request.size))
                val buffer = ByteArray(4096)
                // Quelques essais : un paquet étranger ne doit pas tout bloquer.
                repeat(3) {
                    val packet = DatagramPacket(buffer, buffer.size)
                    socket.receive(packet) // SocketTimeoutException après 2 s
                    val response = buffer.copyOf(packet.length)
                    if (DnsPacket.isResponseTo(request, query, response)) return response
                }
            }
        } catch (e: IOException) {
            // Délai dépassé, réseau absent…
        }
        return null
    }

    private fun writeToTun(packet: ByteArray) {
        synchronized(outputLock) {
            try {
                tunOutput?.write(packet)
            } catch (e: IOException) {
                // TUN fermé pendant l'arrêt : rien à faire.
            }
        }
    }

    /** Arrêt idempotent : peut être appelé plusieurs fois sans risque. */
    private fun stopFirewall() {
        val wasRunning = isRunning
        isRunning = false
        if (wasRunning) FirewallEngine.onVpnStopped()
        closeQuietly(stopWrite) // réveille la boucle de lecture
        stopWrite = null
        readerThread?.let { thread ->
            if (thread != Thread.currentThread()) thread.join(1000)
        }
        readerThread = null
        forwarders?.shutdownNow()
        forwarders = null
        closeQuietly(stopRead)
        stopRead = null
        synchronized(outputLock) {
            tunOutput = null
            try {
                tun?.close() // retire le VPN
            } catch (e: IOException) {
                // Déjà fermé.
            }
            tun = null
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun closeQuietly(fd: FileDescriptor?) {
        if (fd == null) return
        try {
            Os.close(fd)
        } catch (e: ErrnoException) {
            // Déjà fermé.
        }
    }

    // Notification permanente, discrète, avec un bouton « Arrêter ».
    private fun showForegroundNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Pare-feu DNS",
                NotificationManager.IMPORTANCE_LOW, // ni son ni vibration
            ).apply {
                description = "Indique que le pare-feu DNS est actif."
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val stopIntent = PendingIntent.getService(
            this,
            0,
            Intent(this, SentinelVpnService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = notificationBuilder()
            .setSmallIcon(R.drawable.ic_stat_arch)
            .setContentTitle("Sentinel filtre les sites dangereux")
            .setContentIntent(openAppIntent())
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .addAction(Notification.Action.Builder(null as Icon?, "Arrêter", stopIntent).build())
            .build()

        // Android 14+ : type « systemExempted », prévu pour les apps VPN.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    @Suppress("DEPRECATION")
    private fun notificationBuilder(): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }

    private fun openAppIntent(): PendingIntent = PendingIntent.getActivity(
        this,
        0,
        Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE,
    )
}
