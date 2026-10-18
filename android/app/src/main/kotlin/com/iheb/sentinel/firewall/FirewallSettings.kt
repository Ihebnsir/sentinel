package com.iheb.sentinel.firewall

import android.content.Context
import android.content.SharedPreferences

/**
 * Réglages du pare-feu (stockage privé de l'app). On n'y garde que des
 * choix de l'utilisateur et des dates : jamais un domaine visité.
 */
class FirewallSettings(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isEnabled(category: BlockCategory): Boolean =
        prefs.getBoolean(KEY_CATEGORY + category.id, category.defaultEnabled)

    fun setEnabled(category: BlockCategory, enabled: Boolean) {
        prefs.edit().putBoolean(KEY_CATEGORY + category.id, enabled).apply()
    }

    fun enabledCategories(): Set<BlockCategory> =
        BlockCategory.entries.filter(::isEnabled).toSet()

    /** Liste blanche de l'utilisateur (domaines normalisés). */
    fun allowlist(): Set<String> =
        prefs.getStringSet(KEY_ALLOWLIST, null)?.toSet() ?: emptySet()

    /** Renvoie le domaine normalisé, ou null si invalide ou liste pleine. */
    fun addAllowed(raw: String): String? {
        val domain = DomainNames.normalize(raw) ?: return null
        val current = allowlist()
        if (domain !in current && current.size >= MAX_ALLOWLIST) return null
        // Toujours une NOUVELLE copie : Android interdit de modifier celle lue.
        prefs.edit().putStringSet(KEY_ALLOWLIST, current + domain).apply()
        return domain
    }

    fun removeAllowed(domain: String) {
        prefs.edit().putStringSet(KEY_ALLOWLIST, allowlist() - domain).apply()
    }

    var autoUpdate: Boolean
        get() = prefs.getBoolean(KEY_AUTO_UPDATE, false) // désactivé par défaut
        set(value) = prefs.edit().putBoolean(KEY_AUTO_UPDATE, value).apply()

    /** Dernière mise à jour réussie (ms), 0 si jamais. */
    var lastUpdateSuccess: Long
        get() = prefs.getLong(KEY_LAST_SUCCESS, 0L)
        set(value) = prefs.edit().putLong(KEY_LAST_SUCCESS, value).apply()

    /** Dernière tentative (ms), réussie ou non : au plus une par jour. */
    var lastUpdateAttempt: Long
        get() = prefs.getLong(KEY_LAST_ATTEMPT, 0L)
        set(value) = prefs.edit().putLong(KEY_LAST_ATTEMPT, value).apply()

    var lastUpdateFailed: Boolean
        get() = prefs.getBoolean(KEY_LAST_FAILED, false)
        set(value) = prefs.edit().putBoolean(KEY_LAST_FAILED, value).apply()

    companion object {
        private const val PREFS = "sentinel_firewall"
        private const val KEY_CATEGORY = "category_"
        private const val KEY_ALLOWLIST = "allowlist"
        private const val KEY_AUTO_UPDATE = "auto_update"
        private const val KEY_LAST_SUCCESS = "last_update_success"
        private const val KEY_LAST_ATTEMPT = "last_update_attempt"
        private const val KEY_LAST_FAILED = "last_update_failed"
        const val MAX_ALLOWLIST = 500
    }
}
