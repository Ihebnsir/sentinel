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

    private val allowed = listOf(
        // Exception au démarrage du moteur Flutter : aucune donnée reçue.
        "BackgroundAnalyzer.kt: Log.w(TAG, \"Moteur Flutter impossible à démarrer\", e)",
        // Code d'erreur fixe envoyé par Dart (ANALYSIS_FAILED), jamais le texte.
        "BackgroundAnalyzer.kt: Log.w(TAG, \"Analyse impossible (\$code)\")",
    )

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
