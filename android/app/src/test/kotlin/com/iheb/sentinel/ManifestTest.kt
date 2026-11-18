package com.iheb.sentinel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

/** Surface d'attaque du manifeste (SEN-06, SEN-14). */
class ManifestTest {

    private val ns = "http://schemas.android.com/apk/res/android"

    private fun parse(path: String) =
        DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }
            .newDocumentBuilder().parse(File(path))

    // Manifestes écrits à la main : main (commun) et complete (Google Play).
    private val manifests = listOf("src/main/AndroidManifest.xml", "src/complete/AndroidManifest.xml")

    private val components: List<Element> by lazy {
        manifests.map(::parse).flatMap { doc -> componentsOf(doc) }
    }

    private fun componentsOf(doc: org.w3c.dom.Document): List<Element> =
        listOf("activity", "service", "receiver", "provider").flatMap { tag ->
            val nodes = doc.getElementsByTagName(tag)
            (0 until nodes.length).map { nodes.item(it) as Element }
        }

    private fun Element.attr(name: String) = getAttributeNS(ns, name)

    private fun component(name: String) = components.single { it.attr("name") == name }

    private fun actionsOf(component: Element): List<String> {
        val actions = component.getElementsByTagName("action")
        return (0 until actions.length).map { (actions.item(it) as Element).attr("name") }
    }

    @Test
    fun `le relais des alertes n'est pas exporte`() {
        assertEquals("false", component(".AlertRelayActivity").attr("exported"))
    }

    @Test
    fun `MainActivity - seulement lanceur, partage et selection de texte`() {
        val actions = actionsOf(component(".MainActivity")).sorted()
        assertEquals(
            listOf(
                "android.intent.action.MAIN",
                "android.intent.action.PROCESS_TEXT",
                "android.intent.action.SEND",
            ),
            actions,
        )
    }

    @Test
    fun `tuile du pare-feu - reservee au panneau d'Android`() {
        val tile = component(".firewall.FirewallTileService")
        assertEquals("android.permission.BIND_QUICK_SETTINGS_TILE", tile.attr("permission"))
        assertEquals(listOf("android.service.quicksettings.action.QS_TILE"), actionsOf(tile))
        assertEquals("@drawable/ic_stat_arch", tile.attr("icon"))
    }

    @Test
    fun `tout composant exporte est protege par une permission systeme`() {
        // Exceptions justifiées : l'activité du lanceur (partage public), et
        // BOOT_COMPLETED, diffusé par le système seul (broadcast protégé).
        val publicByDesign = setOf(".MainActivity", ".firewall.BootReceiver")
        for (c in components.filter { it.attr("exported") == "true" }) {
            val name = c.attr("name")
            if (name in publicByDesign) continue
            assertTrue("$name exporté sans permission", c.attr("permission").isNotEmpty())
        }
    }

    @Test
    fun `aucune permission dangereuse en dehors de la camera et des notifications`() {
        val factory = DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }
        val doc = factory.newDocumentBuilder().parse(File("src/main/AndroidManifest.xml"))
        val nodes = doc.getElementsByTagName("uses-permission")
        val names = (0 until nodes.length).map { (nodes.item(it) as Element).attr("name") }
        // Accès sensibles : autorisation spéciale, jamais micro ni localisation.
        assertTrue("android.permission.PACKAGE_USAGE_STATS" in names)
        val dangerous = listOf(
            "RECORD_AUDIO", "ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION",
            "ACCESS_BACKGROUND_LOCATION", "READ_PHONE_STATE", "READ_CONTACTS",
        ).map { "android.permission.$it" }
        assertTrue(names.none { it in dangerous })
    }

    // Le manifeste FUSIONNÉ (bibliothèques comprises) est vérifié à chaque
    // build standard par la tâche checkPlayProtectStandard* (build.gradle.kts).
    @Test
    fun `le lecteur de notifications n'est declare que dans la variante complete`() {
        val playProtectRisk = listOf(
            "BIND_NOTIFICATION_LISTENER_SERVICE", "NotificationListenerService",
            "BIND_ACCESSIBILITY_SERVICE", "SMS", "RECEIVE_MMS", "RECEIVE_WAP_PUSH",
        )
        val main = File("src/main/AndroidManifest.xml").readText()
            .replace(Regex("<!--.*?-->", RegexOption.DOT_MATCHES_ALL), "")
        for (word in playProtectRisk) assertTrue("$word dans src/main", word !in main)
        assertTrue(!File("src/standard/AndroidManifest.xml").exists())

        val listener = componentsOf(parse("src/complete/AndroidManifest.xml"))
            .single { it.attr("name") == ".SentinelNotificationListener" }
        assertEquals("android.permission.BIND_NOTIFICATION_LISTENER_SERVICE", listener.attr("permission"))
        assertTrue(File("src/complete/kotlin/com/iheb/sentinel/SentinelNotificationListener.kt").isFile)
        assertTrue(!File("src/main/kotlin/com/iheb/sentinel/SentinelNotificationListener.kt").exists())
    }
}
