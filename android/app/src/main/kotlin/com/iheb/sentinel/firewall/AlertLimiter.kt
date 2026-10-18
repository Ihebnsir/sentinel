package com.iheb.sentinel.firewall

/**
 * Limite les alertes « Site dangereux bloqué » : une par domaine et par
 * heure, et au plus [maxPerWindow] en tout par heure (une page piégée peut
 * appeler des dizaines de sous-domaines d'un coup).
 *
 * Les noms restent UNIQUEMENT en mémoire, une heure au plus : ce n'est pas
 * un historique, rien n'est écrit sur le disque.
 */
class AlertLimiter(
    private val windowMillis: Long = 60 * 60 * 1000L,
    private val maxPerWindow: Int = 10,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    private val lastAlert = HashMap<String, Long>()

    /** Vrai si une alerte peut être affichée pour [domain] maintenant. */
    @Synchronized
    fun tryAcquire(domain: String): Boolean {
        val now = clock()
        lastAlert.values.removeAll { now - it >= windowMillis } // oubli après 1 h
        if (domain in lastAlert || lastAlert.size >= maxPerWindow) return false
        lastAlert[domain] = now
        return true
    }

    @Synchronized
    fun clear() = lastAlert.clear()
}
