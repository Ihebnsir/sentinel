package com.iheb.sentinel

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Règles du coffre selon la version d'Android (SEN-03). */
class VaultPolicyTest {

    @Test
    fun `presse-papiers partage jusqu'a Android 9 inclus`() {
        assertTrue(isClipboardShared(24)) // Android 7.0, minSdk
        assertTrue(isClipboardShared(28)) // Android 9
        assertFalse(isClipboardShared(29)) // Android 10
        assertFalse(isClipboardShared(37))
    }
}
