package com.iheb.sentinel

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

/**
 * SEN-05 : les seuls logs Kotlin sont relus et ne contiennent aucune donnée
 * de l'utilisateur. Tout nouveau Log fait échouer ce test : il faut le
 * relire (pas de texte de message, de domaine, de mot de passe), puis
 * l'ajouter à la liste.
 */
class KotlinLogsTest {

    // Aucun log depuis la 1.1.0 (moteur d'analyse des messages retiré).
    private val allowed = emptyList<String>()

    @Test
    fun `seuls les logs relus existent`() {
        val logCall = Regex("""\b(Log\.[a-z]+\(|println\(|printStackTrace\()""")
        val found = File("src/main/kotlin").walkTopDown()
            .filter { it.isFile && it.extension == "kt" }
            .flatMap { file ->
                file.readLines()
                    .map { it.trim() }
                    .filter { !it.startsWith("//") && logCall.containsMatchIn(it) }
                    .map { "${file.name}: $it" }
            }
            .sorted()
            .toList()
        assertEquals(allowed.sorted(), found)
    }
}
