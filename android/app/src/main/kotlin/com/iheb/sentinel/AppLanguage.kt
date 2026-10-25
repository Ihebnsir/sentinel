package com.iheb.sentinel

import android.content.Context
import android.content.res.Configuration
import android.os.Build
import java.util.Locale

/**
 * Langue choisie dans les Réglages de Sentinel (envoyée par Dart,
 * voir lib/services/language_store.dart). Sans choix : celle du téléphone.
 * Les notifications l'utilisent via [localized].
 */
object AppLanguage {
    private const val PREFS = "sentinel_language"
    private const val KEY = "language"

    // Mêmes langues que lib/l10n (le français d'abord : langue par défaut).
    val SUPPORTED = listOf("fr", "ar", "en")

    /** Code choisi (« ar »), ou null pour suivre le téléphone. */
    fun chosen(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null)
            ?.takeIf { it in SUPPORTED }

    fun choose(context: Context, language: String?) {
        val editor = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        if (language in SUPPORTED) editor.putString(KEY, language) else editor.remove(KEY)
        editor.apply()
    }

    /** Langue des textes : le choix, sinon la première du téléphone proposée, sinon fr. */
    fun current(context: Context): String {
        chosen(context)?.let { return it }
        return deviceLanguages(context).firstOrNull { it in SUPPORTED } ?: SUPPORTED.first()
    }

    /** Contexte dont getString suit le choix de Réglages (inchangé sans choix). */
    fun localized(context: Context): Context {
        val language = chosen(context) ?: return context
        val config = Configuration(context.resources.configuration)
        config.setLocale(Locale.forLanguageTag(language))
        return context.createConfigurationContext(config)
    }

    private fun deviceLanguages(context: Context): List<String> {
        val config = context.resources.configuration
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            @Suppress("DEPRECATION")
            return listOf(config.locale.language)
        }
        val locales = config.locales
        return (0 until locales.size()).map { locales[it].language }
    }
}
