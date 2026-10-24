package com.iheb.sentinel.firewall

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.io.IOException
import java.net.SocketTimeoutException
import javax.net.ssl.SSLHandshakeException

/** SEN-10 : choix du transport, et jamais de DNS en clair sans accord. */
class UpstreamResolverTest {

    private class FakeTransport(override val mode: UpstreamMode) : DnsTransport {
        var calls = 0
        var failure: IOException? = null
        var answer = byteArrayOf(1, 2)

        override fun exchange(request: ByteArray): ByteArray {
            calls++
            failure?.let { throw it }
            return answer
        }

        override fun close() = Unit
    }

    private val dot = FakeTransport(UpstreamMode.DOT)
    private val doh = FakeTransport(UpstreamMode.DOH)
    private val plain = FakeTransport(UpstreamMode.PLAIN)
    private var plainAllowed = false
    private var now = 0L

    private val resolver = UpstreamResolver(
        encrypted = listOf(dot, doh),
        plain = plain,
        plainAllowed = { plainAllowed },
        clock = { now },
        retryAfterMs = 60_000,
    )

    private fun ask() = resolver.resolve(byteArrayOf(9)) { true }

    @Test
    fun `DNS-over-TLS en premier`() {
        assertArrayEquals(byteArrayOf(1, 2), ask())
        assertEquals(UpstreamMode.DOT, resolver.mode)
        assertEquals(0, doh.calls)
        assertEquals(0, plain.calls)
    }

    @Test
    fun `port 853 bloque - DNS-over-HTTPS`() {
        dot.failure = SocketTimeoutException("853 bloqué")
        assertArrayEquals(byteArrayOf(1, 2), ask())
        assertEquals(UpstreamMode.DOH, resolver.mode)
        assertEquals(0, plain.calls)
    }

    @Test
    fun `certificat invalide - refuse comme une panne, pas de repli en clair`() {
        dot.failure = SSLHandshakeException("certificat non approuvé")
        doh.failure = SSLHandshakeException("certificat non approuvé")
        assertNull(ask()) // l'appelant répond SERVFAIL
        assertEquals(UpstreamMode.FAILING, resolver.mode)
        assertEquals(0, plain.calls)
    }

    @Test
    fun `tout chiffre en panne et clair non autorise - jamais de clair`() {
        dot.failure = IOException()
        doh.failure = IOException()
        repeat(5) { assertNull(ask()) }
        assertEquals(UpstreamMode.FAILING, resolver.mode)
        assertEquals(0, plain.calls)
    }

    @Test
    fun `clair seulement apres accord explicite`() {
        dot.failure = IOException()
        doh.failure = IOException()
        plainAllowed = true
        assertArrayEquals(byteArrayOf(1, 2), ask())
        assertEquals(UpstreamMode.PLAIN, resolver.mode)
        // Le chiffré revient dès qu'il remarche (après le délai de reprise).
        dot.failure = null
        now += 60_001
        ask()
        assertEquals(UpstreamMode.DOT, resolver.mode)
    }

    @Test
    fun `reponse qui ne correspond pas a la question - refusee`() {
        dot.answer = byteArrayOf(7)
        doh.answer = byteArrayOf(7)
        assertNull(resolver.resolve(byteArrayOf(9)) { it.contentEquals(byteArrayOf(1, 2)) })
        assertEquals(UpstreamMode.FAILING, resolver.mode)
    }

    @Test
    fun `transport en panne essaye en dernier, puis de nouveau apres le delai`() {
        dot.failure = IOException()
        ask() // DoT en panne -> DoH
        assertEquals(1, dot.calls)
        now += 1_000
        ask()
        assertEquals(1, dot.calls) // DoH d'abord, DoT pas réessayé
        assertEquals(UpstreamMode.DOH, resolver.mode)
        now += 60_000
        dot.failure = null
        ask()
        assertEquals(2, dot.calls)
        assertEquals(UpstreamMode.DOT, resolver.mode)
    }

    @Test
    fun `accord pour un reseau precis seulement`() {
        val permission = PlainDnsPermission()
        assertEquals(false, permission.isAllowedFor("wifi-1")) // désactivé par défaut
        permission.allow("wifi-1")
        assertEquals(true, permission.isAllowedFor("wifi-1"))
        assertEquals(false, permission.isAllowedFor("wifi-2")) // autre réseau
        assertEquals(false, permission.isAllowedFor(null))
        permission.revoke()
        assertEquals(false, permission.isAllowedFor("wifi-1"))
    }

    @Test
    fun `DNS prive strict - un nom de serveur suffit`() {
        assertNull(UnderlyingNetworks.strictServer(emptyList()))
        assertNull(UnderlyingNetworks.strictServer(listOf(null, ""))) // Automatique / désactivé
        assertEquals("dns.google", UnderlyingNetworks.strictServer(listOf(null, "dns.google")))
    }
}
