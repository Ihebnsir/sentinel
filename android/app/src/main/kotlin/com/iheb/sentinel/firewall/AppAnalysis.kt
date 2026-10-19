package com.iheb.sentinel.firewall

import org.json.JSONArray
import org.json.JSONObject

/**
 * « Analyser une application » : pendant quelques minutes, le VPN ne capte
 * que les requêtes DNS d'UNE app. Tout ce qu'il voit lui appartient donc.
 * Fichier sans Android : testable avec JUnit.
 */
class AnalysisSession(
    val packageName: String,
    val appLabel: String,
    val startedAt: Long,
    val minutes: Int,
    /** SystemClock.elapsedRealtime() au début : avance aussi pendant la veille. */
    val startedElapsed: Long = 0L,
) {
    init {
        require(minutes in ALLOWED_MINUTES) { "Durée refusée" }
    }

    /** Fin prévue, à l'heure du téléphone (affichage seulement). */
    val endsAt: Long get() = startedAt + minutes * 60_000L

    /** Fin prévue en elapsedRealtime : heure du réveil AlarmManager. */
    val endsAtElapsed: Long get() = startedElapsed + minutes * 60_000L

    /**
     * Vrai si la durée est écoulée. Mesurée avec elapsedRealtime, pas avec
     * l'heure (modifiable) ni le temps actif (arrêté pendant la veille).
     */
    fun isOver(elapsedNow: Long): Boolean = elapsedNow >= endsAtElapsed

    /** Domaines vus pendant CETTE analyse, en mémoire seulement. */
    val recorder = DomainRecorder()

    companion object {
        /** Durées proposées à l'utilisateur, en minutes. */
        val ALLOWED_MINUTES = setOf(2, 5, 15)
    }
}

/** Réveil de fin d'analyse : exact, ou inexact si Android l'interdit. */
enum class AlarmMode { EXACT, INEXACT }

object AnalysisAlarm {
    /**
     * Android 12+ (API 31) : un réveil exact demande l'autorisation
     * « Alarmes et rappels », sinon SecurityException. Sans elle, réveil
     * inexact (Android peut le retarder un peu).
     */
    fun mode(sdkInt: Int, canScheduleExact: Boolean): AlarmMode =
        if (sdkInt < 31 || canScheduleExact) AlarmMode.EXACT else AlarmMode.INEXACT
}

/** Un domaine demandé pendant l'analyse. */
class RecordedDomain(
    val name: String,
    var count: Int,
    /** null : « autre » (connu d'aucune liste). */
    val category: BlockCategory?,
    var blocked: Boolean,
)

/**
 * Compte les requêtes par domaine. Plafonné à [maxDomains] domaines
 * différents : une app ne peut pas faire grossir la mémoire sans limite.
 */
class DomainRecorder(private val maxDomains: Int = 2000) {
    private val domains = LinkedHashMap<String, RecordedDomain>()

    /** Vrai si des domaines ont été ignorés (plafond atteint). */
    @get:Synchronized
    var truncated = false
        private set

    @Synchronized
    fun record(name: String, category: BlockCategory?, blocked: Boolean) {
        val existing = domains[name]
        if (existing != null) {
            existing.count++
            if (blocked) existing.blocked = true
            return
        }
        if (domains.size >= maxDomains) {
            truncated = true
            return
        }
        domains[name] = RecordedDomain(name, 1, category, blocked)
    }

    @get:Synchronized
    val size: Int get() = domains.size

    /** Copie triée : les plus fréquents d'abord, puis par ordre alphabétique. */
    @Synchronized
    fun snapshot(): List<RecordedDomain> = domains.values
        .map { RecordedDomain(it.name, it.count, it.category, it.blocked) }
        .sortedWith(compareByDescending<RecordedDomain> { it.count }.thenBy { it.name })
}

/** Ce dont le VPN a besoin pour se construire (VpnService.Builder en vrai). */
interface TunBuilder {
    fun addAddress(address: String, prefixLength: Int)
    fun addRoute(address: String, prefixLength: Int)
    fun addDnsServer(address: String)
    fun addAllowedApplication(packageName: String)
}

/**
 * Configuration du VPN. Mode normal : toutes les apps. Mode analyse :
 * une seule app ([allowedPackage]), les autres ne passent plus par le
 * pare-feu. Dans les deux cas, seul le DNS virtuel est routé.
 */
data class TunPlan(val allowedPackage: String?) {

    fun applyTo(builder: TunBuilder) {
        builder.addAddress(TUN_ADDRESS_V4, 32)
        builder.addDnsServer(DNS_ADDRESS_V4)
        builder.addRoute(DNS_ADDRESS_V4, 32) // uniquement le DNS virtuel
        builder.addAddress(TUN_ADDRESS_V6, 128)
        builder.addDnsServer(DNS_ADDRESS_V6)
        builder.addRoute(DNS_ADDRESS_V6, 128)
        // Une seule app autorisée : Android envoie les autres hors du VPN.
        if (allowedPackage != null) builder.addAllowedApplication(allowedPackage)
    }

    companion object {
        // Adresses privées, jamais utilisées sur Internet.
        const val TUN_ADDRESS_V4 = "10.111.222.1"
        const val DNS_ADDRESS_V4 = "10.111.222.2"
        const val TUN_ADDRESS_V6 = "fdc5:3a71:9e04::1" // ULA (fc00::/7)
        const val DNS_ADDRESS_V6 = "fdc5:3a71:9e04::2"

        val NORMAL = TunPlan(null)

        /** Le VPN à construire : analyse en cours ou non. */
        fun forAnalysis(session: AnalysisSession?): TunPlan =
            if (session == null) NORMAL else TunPlan(session.packageName)
    }
}

/** Construction du rapport (JSON lu par lib/services/app_analysis.dart). */
object AppReport {
    const val FORMAT_VERSION = 1

    fun toJson(
        session: AnalysisSession,
        endedAt: Long,
        domains: List<RecordedDomain>,
        truncated: Boolean,
        brandOf: (String) -> String?,
    ): String {
        val array = JSONArray()
        for (domain in domains) {
            val item = JSONObject()
                .put("name", domain.name)
                .put("count", domain.count)
                .put("category", domain.category?.id ?: "other")
                .put("blocked", domain.blocked)
            if (domain.category == BlockCategory.IMPERSONATION) {
                brandOf(domain.name)?.let { item.put("brand", it) }
            }
            array.put(item)
        }
        return JSONObject()
            .put("formatVersion", FORMAT_VERSION)
            .put("id", session.startedAt.toString())
            .put("packageName", session.packageName)
            .put("appLabel", session.appLabel)
            .put("startedAt", session.startedAt)
            .put("endedAt", endedAt)
            .put("plannedMinutes", session.minutes)
            .put("stoppedEarly", endedAt < session.endsAt)
            .put("truncated", truncated)
            .put("domains", array)
            .toString()
    }
}
