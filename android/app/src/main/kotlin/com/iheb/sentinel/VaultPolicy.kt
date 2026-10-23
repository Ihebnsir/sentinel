package com.iheb.sentinel

/**
 * Règles du coffre qui dépendent de la version d'Android.
 * Fonctions pures : testées avec JUnit (VaultPolicyTest).
 */

/** Android 10 (API 29) : premier à interdire la lecture du presse-papiers en arrière-plan. */
const val CLIPBOARD_PRIVATE_SINCE = 29

/** Android 9 et avant : toutes les apps peuvent lire le presse-papiers (SEN-03). */
fun isClipboardShared(sdkInt: Int): Boolean = sdkInt < CLIPBOARD_PRIVATE_SINCE
