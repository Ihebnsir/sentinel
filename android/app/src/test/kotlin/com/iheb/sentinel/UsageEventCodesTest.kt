package com.iheb.sentinel

import android.app.usage.UsageEvents
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Accès sensibles : événements Android traduits pour Dart (UsageEventKind). */
class UsageEventCodesTest {

    @Test
    fun `ouverture, fermeture et services au premier plan`() {
        assertEquals(UsageEventCodes.FOREGROUND, UsageEventCodes.codeOf(UsageEvents.Event.ACTIVITY_RESUMED))
        assertEquals(UsageEventCodes.BACKGROUND, UsageEventCodes.codeOf(UsageEvents.Event.ACTIVITY_PAUSED))
        assertEquals(UsageEventCodes.BACKGROUND, UsageEventCodes.codeOf(UsageEvents.Event.ACTIVITY_STOPPED))
        assertEquals(
            UsageEventCodes.SERVICE_START,
            UsageEventCodes.codeOf(UsageEvents.Event.FOREGROUND_SERVICE_START),
        )
        assertEquals(
            UsageEventCodes.SERVICE_STOP,
            UsageEventCodes.codeOf(UsageEvents.Event.FOREGROUND_SERVICE_STOP),
        )
    }

    @Test
    fun `anciens noms d'avant Android 10 - memes valeurs`() {
        @Suppress("DEPRECATION")
        assertEquals(UsageEventCodes.FOREGROUND, UsageEventCodes.codeOf(UsageEvents.Event.MOVE_TO_FOREGROUND))
        @Suppress("DEPRECATION")
        assertEquals(UsageEventCodes.BACKGROUND, UsageEventCodes.codeOf(UsageEvents.Event.MOVE_TO_BACKGROUND))
    }

    @Test
    fun `le reste est ignore`() {
        for (type in listOf(
            UsageEvents.Event.NONE,
            UsageEvents.Event.CONFIGURATION_CHANGE,
            UsageEvents.Event.USER_INTERACTION,
            UsageEvents.Event.SCREEN_INTERACTIVE,
            UsageEvents.Event.KEYGUARD_SHOWN,
        )) {
            assertNull(UsageEventCodes.codeOf(type))
        }
    }
}
