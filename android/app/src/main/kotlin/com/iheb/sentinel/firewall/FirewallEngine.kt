package com.iheb.sentinel.firewall

import android.content.Context
import android.content.pm.ApplicationInfo
import java.io.File
import java.util.EnumMap
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

/**
 * Cœur du pare-feu, partagé par le service VPN et FirewallChannel :
 * listes chargées, règles actives, compteurs, mises à jour.
 *
 * Tout le travail lourd (lecture des listes, téléchargements) se fait sur
 * UN thread d'arrière-plan. Le thread DNS lit seulement [policy], une
 * photo figée remplacée d'un coup : un changement de réglage s'applique
 * sans redémarrer le VPN.
 */
object FirewallEngine {

    private const val ASSETS_DIR = "flutter_assets/assets/blocklists"
    private const val PRIVATE_DIR = "blocklists"
    private const val DAY_MS = 24 * 60 * 60 * 1000L
    private const val AUTO_CHECK_HOURS = 6L

    /** Règles actives, lues par le thread DNS. */
    @Volatile
    var policy: BlockPolicy = BlockPolicy.EMPTY
        private set

    @Volatile
    var loading = false
        private set

    @Volatile
    var updating = false
        private set

    /** Blocages par catégorie depuis le démarrage du VPN (en mémoire). */
    val blockedByCategory: Map<BlockCategory, AtomicLong> =
        BlockCategory.entries.associateWith { AtomicLong() }

    val alertLimiter = AlertLimiter()

    private val worker: ScheduledExecutorService by lazy {
        ScheduledThreadPoolExecutor(1) { r -> Thread(r, "sentinel-lists") }
    }
    private var autoUpdateTask: ScheduledFuture<*>? = null

    // Touchés uniquement par le thread « sentinel-lists ».
    private val loaded = EnumMap<BlockCategory, CategoryList>(BlockCategory::class.java)
    private var bundledCache: BlocklistManifest? = null
    private var protectedCache: Set<String>? = null

    /** Le VPN démarre : remise à zéro et chargement en arrière-plan. */
    fun onVpnStarted(context: Context) {
        blockedByCategory.values.forEach { it.set(0) }
        alertLimiter.clear()
        refresh(context)
        val app = context.applicationContext
        synchronized(this) {
            autoUpdateTask?.cancel(false)
            autoUpdateTask = worker.scheduleWithFixedDelay(
                { autoUpdateIfDue(app) }, 1, AUTO_CHECK_HOURS * 60, TimeUnit.MINUTES,
            )
        }
    }

    /** Le VPN s'arrête : on libère la mémoire des listes. */
    fun onVpnStopped() {
        synchronized(this) {
            autoUpdateTask?.cancel(false)
            autoUpdateTask = null
        }
        policy = BlockPolicy.EMPTY
        alertLimiter.clear()
        worker.execute { loaded.clear() }
    }

    /**
     * Réapplique les réglages (catégories, liste blanche). Ne relit que les
     * listes nécessaires ; [reloadFiles] force la relecture (après mise à jour).
     */
    fun refresh(context: Context, reloadFiles: Boolean = false) {
        val app = context.applicationContext
        worker.execute { applySettings(app, reloadFiles) }
    }

    private fun applySettings(context: Context, reloadFiles: Boolean) {
        if (!SentinelVpnService.isRunning) return // rien à filtrer
        val settings = FirewallSettings(context)
        val enabled = settings.enabledCategories()
        if (reloadFiles) loaded.clear()
        loaded.keys.retainAll(enabled) // catégorie coupée : mémoire libérée
        val missing = enabled - loaded.keys
        if (missing.isNotEmpty()) {
            loading = true
            try {
                for (category in missing) loaded[category] = loadCategory(context, category)
            } finally {
                loading = false
            }
        }
        if (!SentinelVpnService.isRunning) return // arrêté pendant le chargement
        policy = BlockPolicy(
            lists = EnumMap(loaded),
            enabled = enabled,
            allowlist = DomainSet.of(settings.allowlist()),
            testDomain = if (isDebug(context)) TEST_DOMAIN else null,
        )
    }

    /** Bloqué en build debug uniquement, pour tester facilement. */
    const val TEST_DOMAIN = "example.com"

    // Version privée (mise à jour) si elle est plus récente et intacte,
    // sinon celle des assets. Liste vide si tout échoue.
    private fun loadCategory(context: Context, category: BlockCategory): CategoryList {
        val local = activeLocalFile(context, category)
        if (local != null) {
            try {
                return File(privateDir(context), local.file).inputStream().use {
                    CategoryList.read(it, local.sha256, local.entries * 28)
                }
            } catch (e: Exception) {
                // Fichier abîmé ou modifié : on retombe sur les assets.
            }
        }
        val bundled = bundledManifest(context)?.categories?.get(category) ?: return CategoryList.EMPTY
        return try {
            context.assets.open("$ASSETS_DIR/${bundled.file}").use {
                CategoryList.read(it, bundled.sha256, bundled.entries * 28)
            }
        } catch (e: Exception) {
            CategoryList.EMPTY
        }
    }

    private fun activeLocalFile(context: Context, category: BlockCategory): CategoryFile? {
        val local = updater(context)?.readLocalManifest() ?: return null
        val bundled = bundledManifest(context) ?: return null
        // Une nouvelle version de l'app peut apporter des listes plus récentes.
        if (local.generatedAt <= bundled.generatedAt) return null
        return local.categories[category]
    }

    /** Lance une mise à jour ; [onDone] est appelé sur le thread des listes. */
    fun updateNow(context: Context, onDone: (Boolean) -> Unit) {
        val app = context.applicationContext
        worker.execute { onDone(runUpdate(app)) }
    }

    // Au plus une tentative automatique par jour, et seulement si l'option est active.
    private fun autoUpdateIfDue(context: Context) {
        val settings = FirewallSettings(context)
        if (!settings.autoUpdate) return
        if (System.currentTimeMillis() - settings.lastUpdateAttempt < DAY_MS) return
        runUpdate(context)
    }

    private fun runUpdate(context: Context): Boolean {
        val settings = FirewallSettings(context)
        val updater = updater(context) ?: return false
        updating = true
        try {
            settings.lastUpdateAttempt = System.currentTimeMillis()
            val result = updater.update(settings.enabledCategories())
            settings.lastUpdateFailed = !result.success
            if (result.updated.isNotEmpty()) {
                settings.lastUpdateSuccess = System.currentTimeMillis()
                applySettings(context, reloadFiles = true)
            }
            return result.success
        } finally {
            updating = false
        }
    }

    private fun updater(context: Context): BlocklistUpdater? {
        val bundled = bundledManifest(context) ?: return null
        return BlocklistUpdater(privateDir(context), bundled, protectedDomains(context))
    }

    private fun privateDir(context: Context) = File(context.filesDir, PRIVATE_DIR)

    @Synchronized
    fun bundledManifest(context: Context): BlocklistManifest? {
        bundledCache?.let { return it }
        return try {
            val json = context.assets.open("$ASSETS_DIR/manifest.json")
                .use { it.readBytes().toString(Charsets.UTF_8) }
            BlocklistManifest.parse(json).also { bundledCache = it }
        } catch (e: Exception) {
            null
        }
    }

    @Synchronized
    private fun protectedDomains(context: Context): Set<String> {
        protectedCache?.let { return it }
        val names = try {
            context.assets.open("$ASSETS_DIR/protected.txt").bufferedReader().useLines { lines ->
                lines.map { it.substringBefore('#').trim() }
                    .filter { it.isNotEmpty() }
                    .mapNotNull(DomainNames::normalize)
                    .toSet()
            }
        } catch (e: Exception) {
            emptySet()
        }
        return names.also { protectedCache = it }
    }

    /** Nombre d'entrées par catégorie (liste chargée, sinon manifeste). */
    fun entryCounts(context: Context): Map<BlockCategory, Int> {
        val currentPolicy = policy
        val bundled = bundledManifest(context)
        val local = updater(context)?.readLocalManifest()
            ?.takeIf { bundled != null && it.generatedAt > bundled.generatedAt }
        return BlockCategory.entries.associateWith { category ->
            currentPolicy.size(category)
                ?: local?.categories?.get(category)?.entries
                ?: bundled?.categories?.get(category)?.entries
                ?: 0
        }
    }

    private fun isDebug(context: Context): Boolean =
        context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
}
