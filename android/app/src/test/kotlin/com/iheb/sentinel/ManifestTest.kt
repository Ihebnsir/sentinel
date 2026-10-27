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

    private val components: List<Element> by lazy {
        val factory = DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }
        val doc = factory.newDocumentBuilder().parse(File("src/main/AndroidManifest.xml"))
        listOf("activity", "service", "receiver", "provider").flatMap { tag ->
            val nodes = doc.getElementsByTagName(tag)
            (0 until nodes.length).map { nodes.item(it) as Element }
        }
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
}
