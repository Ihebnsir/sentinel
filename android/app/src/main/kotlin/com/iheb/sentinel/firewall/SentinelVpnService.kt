package com.iheb.sentinel.firewall

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import com.iheb.sentinel.AppLanguage
import com.iheb.sentinel.MainActivity
import com.iheb.sentinel.R
import java.io.FileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.text.DateFormat
import java.util.Date
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

/**
 * Pare-feu DNS local. Le VPN ne capte QUE les paquets envoyés au serveur
 * DNS virtuel : le reste du trafic ne passe jamais par Sentinel.
 * Aucun domaine demandé n'est journalisé : seuls des compteurs existent,
 * sauf pendant une analyse d'app demandée par l'utilisateur (rapport).
 */
class SentinelVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.iheb.sentinel.firewall.START"
        const val ACTION_STOP = "com.iheb.sentinel.firewall.STOP"
        const val ACTION_START_ANALYSIS = "com.iheb.sentinel.firewall.START_ANALYSIS"
        const val ACTION_STOP_ANALYSIS = "com.iheb.sentinel.firewall.STOP_ANALYSIS"
        private const val ACTION_ANALYSIS_ALARM = "com.iheb.sentinel.firewall.ANALYSIS_ALARM"
        const val EXTRA_PACKAGE = "packageName"
        const val EXTRA_MINUTES = "minutes"

        private const val MTU = 1500
        private const val IP_UDP_HEADERS = 48 // IPv6 (40) + UDP (8), le pire cas

        private const val CHECK_MS = 10_000L

        private const val CHANNEL_ID = "dns_firewall"
        private const val NOTIFICATION_ID = 2001

        /** Vrai tant que le filtrage tourne. Lu par FirewallChannel. */
        @Volatile
        var isRunning = false
            private set

        /** Analyse d'app en cours, ou null. Lu par FirewallChannel et FirewallEngine. */
        @Volatile
        var analysis: AnalysisSession? = null
            private set

        // Compteurs en mémoire, remis à zéro à chaque démarrage.
        val totalQueries = AtomicLong()
        val blockedQueries = AtomicLong()

        /** Transport vers Quad9 (SEN-10). Lu par FirewallChannel. */
        @Volatile
        var upstream: UpstreamMode = UpstreamMode.IDLE
            private set

        /** « Autoriser le DNS non chiffré sur ce réseau », désactivé par défaut. */
        val plainDns = PlainDnsPermission()
    }

    /**
     * Une interface TUN et son thread de lecture. Reconstruire le VPN
     * (début ou fin d'analyse) = ouvrir une nouvelle session, puis fermer
     * l'ancienne. [recorder] n'existe que pour la session d'analyse.
     */
    private inner class TunSession(
        val pfd: ParcelFileDescriptor,
        val stopRead: FileDescriptor,
        val stopWrite: FileDescriptor,
        val recorder: DomainRecorder?,
    ) {
        val output = FileOutputStream(pfd.fileDescriptor)
        var thread: Thread? = null

        @Volatile
        var closed = false
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val outputLock = Any()

    @Volatile
    private var current: TunSession? = null

    @Volatile
    private var forwarders: ThreadPoolExecutor? = null

    @Volatile
    private var resolver: UpstreamResolver? = null

    // Filet de sécurité : vérifie la fin toutes les 10 s. postDelayed compte
    // le temps ACTIF (arrêté en veille) : c'est l'alarme qui réveille le
    // téléphone à l'heure (voir scheduleAnalysisAlarm).
    private val endAnalysis: Runnable = object : Runnable {
        override fun run() {
            val session = analysis ?: return
            if (session.isOver(SystemClock.elapsedRealtime())) {
                finishAnalysis()
            } else {
                mainHandler.postDelayed(this, CHECK_MS)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopFirewall()
                return START_NOT_STICKY
            }
            ACTION_START_ANALYSIS -> {
                showForegroundNotification()
                startAnalysis(
                    intent.getStringExtra(EXTRA_PACKAGE).orEmpty(),
                    intent.getIntExtra(EXTRA_MINUTES, 0),
                )
                return START_STICKY
            }
            ACTION_STOP_ANALYSIS -> {
                showForegroundNotification()
                finishAnalysis()
                return START_STICKY
            }
            ACTION_ANALYSIS_ALARM -> {
                // Service arrêté entre-temps : rien à terminer.
                if (!isRunning) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                val session = analysis
                if (session != null) {
                    if (session.isOver(SystemClock.elapsedRealtime())) {
                        finishAnalysis()
                    } else {
                        scheduleAnalysisAlarm(session) // réveil en avance : on recommence
                    }
                }
                return START_STICKY
            }
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

        val session = openSession(TunPlan.NORMAL, recorder = null)
        if (session == null) {
            stopFirewall() // pas d'autorisation VPN (prepare non accepté)
            return
        }
        totalQueries.set(0)
        blockedQueries.set(0)

        // 4 transferts en parallèle au plus ; file pleine : requête ignorée
        // (le téléphone réessaiera de lui-même).
        forwarders = ThreadPoolExecutor(
            4, 4, 30, TimeUnit.SECONDS,
            ArrayBlockingQueue(64),
            ThreadPoolExecutor.DiscardPolicy(),
        ).apply { allowCoreThreadTimeOut(true) }

        // SEN-10 : DNS-over-TLS, puis DNS-over-HTTPS ; en clair seulement si
        // l'utilisateur l'a autorisé pour ce réseau. Sockets protégés : ils
        // sortent par le vrai réseau, sans repasser dans le VPN.
        val connector = TlsConnector(protect = { socket -> protect(socket) })
        resolver = UpstreamResolver(
            encrypted = listOf(
                DotTransport(connector),
                // ALPN « h2 » : Android 10 et plus.
                DohTransport(connector, available = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q),
            ),
            plain = PlainUdpTransport(protect = { socket -> protect(socket) }),
            plainAllowed = { plainDns.isAllowedFor(UnderlyingNetworks.currentKey(this)) },
        )
        upstream = UpstreamMode.IDLE

        current = session
        startReader(session)
        isRunning = true
        FirewallEngine.onVpnStarted(this)
    }

    /** Ouvre une interface TUN selon [plan] ; null si Android refuse. */
    private fun openSession(plan: TunPlan, recorder: DomainRecorder?): TunSession? {
        val pfd = try {
            establishTun(plan)
        } catch (e: Exception) {
            null // adresse refusée, app désinstallée, VPN non autorisé…
        } ?: return null
        val pipe = try {
            Os.pipe()
        } catch (e: ErrnoException) {
            pfd.close()
            return null
        }
        return TunSession(pfd, pipe[0], pipe[1], recorder)
    }

    private fun startReader(session: TunSession) {
        // Les listes se chargent en arrière-plan (FirewallEngine) : le VPN
        // démarre tout de suite et filtre dès qu'elles sont prêtes.
        val filter = DnsFilter { name -> FirewallEngine.policy.check(name) }
        session.thread = Thread({ readLoop(session, filter) }, "sentinel-dns").apply { start() }
    }

    private fun establishTun(plan: TunPlan): ParcelFileDescriptor? {
        val builder = Builder()
            .setSession("Sentinel")
            .setMtu(MTU)
            .setConfigureIntent(openAppIntent())
        plan.applyTo(object : TunBuilder {
            override fun addAddress(address: String, prefixLength: Int) {
                builder.addAddress(address, prefixLength)
            }

            override fun addRoute(address: String, prefixLength: Int) {
                builder.addRoute(address, prefixLength)
            }

            override fun addDnsServer(address: String) {
                builder.addDnsServer(address)
            }

            // Lance NameNotFoundException si l'app n'est plus installée.
            override fun addAllowedApplication(packageName: String) {
                builder.addAllowedApplication(packageName)
            }
        })
        // Pas d'addDisallowedApplication : nos propres requêtes vers Quad9
        // sont exclues une par une avec protect() (voir forward()).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Le VPN suit le réseau réel (Wi-Fi gratuit, données facturées…).
            builder.setMetered(false)
        }
        return builder.establish() // null si l'autorisation VPN manque
    }

    /**
     * Début d'analyse : le VPN est reconstruit pour [packageName] seul.
     * Les autres apps ne sont plus protégées jusqu'à la fin (l'écran de
     * Sentinel le dit avant de lancer).
     */
    private fun startAnalysis(packageName: String, minutes: Int) {
        if (!isRunning || analysis != null) return
        if (minutes !in AnalysisSession.ALLOWED_MINUTES) return
        if (packageName.isEmpty() || packageName == this.packageName) return
        val label = try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            return
        }
        val session = AnalysisSession(
            packageName, label, System.currentTimeMillis(), minutes, SystemClock.elapsedRealtime(),
        )
        // Avant la reconstruction : FirewallEngine charge toutes les listes.
        analysis = session
        FirewallEngine.refresh(this)
        val tun = openSession(TunPlan.forAnalysis(session), session.recorder)
        if (tun == null) {
            analysis = null
            FirewallEngine.refresh(this)
            return
        }
        switchTo(tun)
        mainHandler.removeCallbacks(endAnalysis)
        mainHandler.postDelayed(endAnalysis, CHECK_MS)
        scheduleAnalysisAlarm(session)
        showForegroundNotification()
    }

    /**
     * Réveil d'Android à la fin prévue, même en veille profonde (Doze) :
     * horloge elapsedRealtime, qui avance pendant la veille.
     */
    private fun scheduleAnalysisAlarm(session: AnalysisSession) {
        val alarms = getSystemService(AlarmManager::class.java) ?: return
        val type = AlarmManager.ELAPSED_REALTIME_WAKEUP
        val at = session.endsAtElapsed
        val pending = analysisAlarmIntent()
        val canExact = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarms.canScheduleExactAlarms()
        try {
            when {
                AnalysisAlarm.mode(Build.VERSION.SDK_INT, canExact) == AlarmMode.INEXACT ->
                    alarms.setAndAllowWhileIdle(type, at, pending)
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                    alarms.setExactAndAllowWhileIdle(type, at, pending)
                else -> alarms.setExact(type, at, pending)
            }
        } catch (e: SecurityException) {
            // Autorisation retirée entre-temps : réveil inexact.
            alarms.setAndAllowWhileIdle(type, at, pending)
        }
    }

    private fun cancelAnalysisAlarm() {
        getSystemService(AlarmManager::class.java)?.cancel(analysisAlarmIntent())
    }

    private fun analysisAlarmIntent(): PendingIntent = PendingIntent.getService(
        this,
        2, // 0 et 1 : boutons « Arrêter » de la notification
        Intent(this, SentinelVpnService::class.java).setAction(ACTION_ANALYSIS_ALARM),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    /** Fin (durée écoulée ou arrêt manuel) : rapport, puis VPN normal. */
    private fun finishAnalysis() {
        val session = analysis ?: return
        mainHandler.removeCallbacks(endAnalysis)
        cancelAnalysisAlarm()
        analysis = null
        if (isRunning) {
            val normal = openSession(TunPlan.NORMAL, recorder = null)
            if (normal == null) {
                saveReport(session)
                stopFirewall()
                return
            }
            switchTo(normal) // l'ancienne session est fermée : plus d'enregistrement
            FirewallEngine.refresh(this) // libère les listes inutiles
        }
        saveReport(session)
        showForegroundNotification()
    }

    // Nouvelle session d'abord, puis fermeture de l'ancienne : pas de trou.
    private fun switchTo(next: TunSession) {
        val previous = current
        current = next
        startReader(next)
        if (previous != null) closeSession(previous)
    }

    private fun saveReport(session: AnalysisSession) {
        val endedAt = System.currentTimeMillis()
        val policy = FirewallEngine.policy
        val json = AppReport.toJson(
            session,
            endedAt,
            session.recorder.snapshot(),
            session.recorder.truncated,
        ) { name -> policy.impersonatedBrand(name)?.name }
        val store = ReportCleanupReceiver.store(this)
        try {
            store.save(session.startedAt.toString(), endedAt, json)
        } catch (e: Exception) {
            // Stockage plein… : pas de rapport, rien d'autre à faire.
        }
        ReportCleanupReceiver.schedule(this, store)
    }

    /** Boucle du thread dédié : lit les paquets du TUN jusqu'à l'arrêt. */
    private fun readLoop(session: TunSession, filter: DnsFilter) {
        val tunFd = session.pfd.fileDescriptor
        val input = FileInputStream(tunFd)
        val buffer = ByteArray(Short.MAX_VALUE.toInt())
        val tunPoll = StructPollfd().apply {
            fd = tunFd
            events = OsConstants.POLLIN.toShort()
        }
        val stopPoll = StructPollfd().apply {
            fd = session.stopRead
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
                if (length > 0) handlePacket(session, filter, buffer, length)
            }
        } catch (e: Exception) {
            // Erreur inattendue : on arrête proprement plutôt que planter.
        }
        // TUN fermé ou en erreur : arrêt complet, sur le thread principal
        // (sauf si une nouvelle session l'a remplacé entre-temps).
        mainHandler.post { if (current === session && !session.closed) stopFirewall() }
    }

    private fun handlePacket(session: TunSession, filter: DnsFilter, buffer: ByteArray, length: Int) {
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
                writeToTun(session, decision.packet)
                maybeAlert(decision)
                record(session, decision.name, decision.category, blocked = true)
            }
            is FilterDecision.Forward -> {
                totalQueries.incrementAndGet()
                session.recorder?.let {
                    val name = decision.query.name
                    record(session, name, FirewallEngine.policy.classify(name), blocked = false)
                }
                forwarders?.execute { forward(session, filter, decision) }
            }
        }
    }

    // Seulement pendant une analyse : toutes les requêtes viennent de l'app choisie.
    private fun record(session: TunSession, name: String, category: BlockCategory?, blocked: Boolean) {
        val recorder = session.recorder ?: return
        // Réveil après une veille : on termine dès la première requête.
        if (analysis?.isOver(SystemClock.elapsedRealtime()) == true) {
            mainHandler.post(endAnalysis)
            return
        }
        val normalized = FirewallEngine.policy.normalized(name) ?: return
        recorder.record(normalized, category, blocked)
    }

    // Malware, hameçonnage et imitations : une fois par domaine et par heure.
    // Le nom passe en mémoire jusqu'à la notification, sans être enregistré.
    private fun maybeAlert(decision: FilterDecision.Blocked) {
        if (!decision.category.alerts) return
        if (!FirewallEngine.alertLimiter.tryAcquire(decision.name)) return
        val name = decision.name
        val brand = if (decision.category == BlockCategory.IMPERSONATION) {
            FirewallEngine.policy.impersonatedBrand(name)?.name
        } else {
            null
        }
        mainHandler.post { FirewallAlertNotifier.show(this, name, brand) }
    }

    /**
     * Envoie la requête à Quad9, chiffrée (SEN-10), et réécrit sa réponse
     * dans le TUN. Échec : SERVFAIL tout de suite, jamais de repli en clair
     * sans l'accord de l'utilisateur.
     */
    private fun forward(session: TunSession, filter: DnsFilter, decision: FilterDecision.Forward) {
        val request = decision.udp.payload
        val dns = resolver ?: return
        val response = dns.resolve(request) { DnsPacket.isResponseTo(request, decision.query, it) }
        upstream = dns.mode
        // Trop grande pour un seul paquet : échec plutôt qu'un paquet perdu.
        val message = if (response == null || response.size + IP_UDP_HEADERS > MTU) {
            DnsPacket.buildEmptyResponse(request, decision.query, DnsPacket.RCODE_SERVFAIL)
        } else {
            response
        }
        writeToTun(session, filter.replyTo(decision.udp, message))
    }

    // Réponse écrite dans la session qui a reçu la question ; si elle a
    // été fermée entre-temps, la réponse est perdue (l'app réessaiera).
    private fun writeToTun(session: TunSession, packet: ByteArray) {
        synchronized(outputLock) {
            if (session.closed) return
            try {
                session.output.write(packet)
            } catch (e: IOException) {
                // TUN fermé pendant l'arrêt : rien à faire.
            }
        }
    }

    private fun closeSession(session: TunSession) {
        closeQuietly(session.stopWrite) // réveille la boucle de lecture
        session.thread?.let { thread ->
            if (thread != Thread.currentThread()) thread.join(1000)
        }
        closeQuietly(session.stopRead)
        synchronized(outputLock) {
            session.closed = true
            try {
                session.pfd.close() // retire cette interface
            } catch (e: IOException) {
                // Déjà fermé.
            }
        }
    }

    /** Arrêt idempotent : peut être appelé plusieurs fois sans risque. */
    private fun stopFirewall() {
        mainHandler.removeCallbacks(endAnalysis)
        val session = analysis
        if (session != null) cancelAnalysisAlarm()
        analysis = null
        val wasRunning = isRunning
        isRunning = false
        current?.let(::closeSession)
        current = null
        // Analyse interrompue (arrêt, autre VPN) : le rapport est gardé.
        if (session != null) saveReport(session)
        if (wasRunning) FirewallEngine.onVpnStopped()
        forwarders?.shutdownNow()
        forwarders = null
        resolver?.close()
        resolver = null
        upstream = UpstreamMode.IDLE
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
    // Pendant une analyse, elle rappelle que les autres apps ne sont pas protégées.
    private fun showForegroundNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        // Textes dans la langue choisie dans Réglages.
        val texts = AppLanguage.localized(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                texts.getString(R.string.vpn_channel_name),
                NotificationManager.IMPORTANCE_LOW, // ni son ni vibration
            ).apply {
                description = texts.getString(R.string.vpn_channel_description)
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val running = analysis
        val stopIntent = PendingIntent.getService(
            this,
            if (running == null) 0 else 1,
            Intent(this, SentinelVpnService::class.java)
                .setAction(if (running == null) ACTION_STOP else ACTION_STOP_ANALYSIS),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = notificationBuilder()
            .setSmallIcon(R.drawable.ic_stat_arch)
            .setContentIntent(openAppIntent())
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
        if (running == null) {
            builder.setContentTitle(texts.getString(R.string.vpn_title))
                .addAction(
                    Notification.Action.Builder(
                        null as Icon?,
                        texts.getString(R.string.vpn_stop),
                        stopIntent,
                    ).build(),
                )
        } else {
            val end = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(running.endsAt))
            val text = texts.getString(R.string.vpn_analysis_text, end)
            builder.setContentTitle(texts.getString(R.string.vpn_analysis_title, running.appLabel))
                .setContentText(text)
                .setStyle(Notification.BigTextStyle().bigText(text))
                .addAction(
                    Notification.Action.Builder(
                        null as Icon?,
                        texts.getString(R.string.vpn_analysis_stop),
                        stopIntent,
                    ).build(),
                )
        }
        val notification = builder.build()

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
