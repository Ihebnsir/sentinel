package com.iheb.sentinel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

/** Textes Android : mêmes clés en français, anglais et arabe. */
class StringsResourcesTest {

    private fun strings(folder: String): Map<String, String> {
        val file = File("src/main/res/$folder/strings.xml")
        val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file)
        val nodes = doc.getElementsByTagName("string")
        return (0 until nodes.length)
            .map { nodes.item(it) as Element }
            .associate { it.getAttribute("name") to it.textContent }
    }

    private val french = strings("values")
    private val translations = listOf("values-en", "values-ar").associateWith { strings(it) }

    // %1$s, %2$s… : la traduction doit garder les mêmes valeurs à insérer.
    private fun placeholders(text: String) =
        Regex("""%\d+\$[sd]""").findAll(text).map { it.value }.toSortedSet()

    @Test
    fun `chaque cle existe dans les 3 langues`() {
        for ((folder, texts) in translations) {
            assertEquals(folder, french.keys, texts.keys)
        }
    }

    @Test
    fun `les traductions gardent les valeurs a inserer`() {
        for ((folder, texts) in translations) {
            for ((key, text) in french) {
                assertEquals("$folder/$key", placeholders(text), placeholders(texts.getValue(key)))
                assertTrue("$folder/$key vide", texts.getValue(key).isNotBlank())
            }
        }
    }

    @Test
    fun `le manifeste ne contient plus de texte francais en dur`() {
        val manifest = File("src/main/AndroidManifest.xml").readText()
        val labels = Regex("""android:label="([^"]*)"""").findAll(manifest).map { it.groupValues[1] }
        // Seul le nom de l'app reste écrit tel quel.
        for (label in labels) {
            assertTrue(label, label == "Sentinel" || label.startsWith("@string/"))
        }
        for (ref in Regex("""@string/(\w+)""").findAll(manifest).map { it.groupValues[1] }) {
            assertTrue("$ref absent de values/strings.xml", ref in french)
        }
    }
}
