package com.iheb.sentinel.firewall

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.BufferedInputStream
import java.io.File
import java.io.IOException
import java.net.InetAddress
import java.security.KeyStore
import java.util.concurrent.atomic.AtomicInteger
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLServerSocket
import javax.net.ssl.SSLSocketFactory
import javax.net.ssl.TrustManagerFactory
import kotlin.concurrent.thread

/**
 * SEN-10 : vrai TLS, en local. Un faux serveur DoT (certificat créé par
 * keytool) renvoie chaque requête à l'envers.
 */
class DotTransportTest {

    @get:Rule
    val folder = TemporaryFolder()

    private val password = "test-seulement".toCharArray()

    // Certificat autosigné pour [name], créé par le keytool du JDK des tests.
    private fun keyStore(name: String): KeyStore {
        val file = File(folder.root, "$name.p12")
        val keytool = File(System.getProperty("java.home"), "bin/keytool").path
        val process = ProcessBuilder(
            keytool, "-genkeypair", "-alias", "srv", "-keyalg", "EC", "-groupname", "secp256r1",
            "-dname", "CN=$name", "-ext", "SAN=dns:$name", "-validity", "2",
            "-storetype", "PKCS12", "-keystore", file.path,
            "-storepass", String(password), "-keypass", String(password),
        ).redirectErrorStream(true).start()
        process.inputStream.readBytes()
        assertEquals(0, process.waitFor())
        return KeyStore.getInstance("PKCS12").apply { file.inputStream().use { load(it, password) } }
    }

    private fun server(store: KeyStore, accepts: AtomicInteger): SSLServerSocket {
        val keys = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm())
            .apply { init(store, password) }
        val context = SSLContext.getInstance("TLS").apply { init(keys.keyManagers, null, null) }
        val socket = context.serverSocketFactory.createServerSocket(0, 5, InetAddress.getLoopbackAddress())
            as SSLServerSocket
        thread(isDaemon = true) {
            while (!socket.isClosed) {
                val client = try { socket.accept() } catch (e: IOException) { break }
                accepts.incrementAndGet()
                thread(isDaemon = true) {
                    client.use {
                        val input = BufferedInputStream(it.inputStream)
                        try {
                            while (true) {
                                val request = DnsFraming.read(input)
                                it.outputStream.write(DnsFraming.frame(request.reversedArray()))
                                it.outputStream.flush()
                            }
                        } catch (e: IOException) {
                            // client parti
                        }
                    }
                }
            }
        }
        return socket
    }

    // Client qui fait confiance à [trusted] (comme le magasin système fait confiance à Quad9).
    private fun factoryTrusting(trusted: KeyStore?): SSLSocketFactory {
        if (trusted == null) return SSLSocketFactory.getDefault() as SSLSocketFactory
        val trust = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm())
            .apply { init(trusted) }
        return SSLContext.getInstance("TLS").apply { init(null, trust.trustManagers, null) }.socketFactory
    }

    private fun transport(port: Int, factory: SSLSocketFactory, protects: AtomicInteger) =
        object : PooledTlsTransport(
            TlsConnector(
                // Comme VpnService.protect() : exige un socket déjà lié (descripteur créé).
                protect = { socket -> protects.incrementAndGet(); socket.isBound },
                addresses = listOf(InetAddress.getLoopbackAddress()),
                factory = factory,
                // Vérification réelle du nom (le vérificateur Android n'existe pas sur la JVM).
                verifier = { host, session ->
                    val cert = session.peerCertificates[0] as java.security.cert.X509Certificate
                    cert.subjectAlternativeNames.orEmpty().any { it[1] == host }
                },
            ),
            port,
        ) {
            override val mode = UpstreamMode.DOT
            override fun send(connection: TlsConnection, request: ByteArray): Pair<ByteArray, Boolean> {
                connection.output.write(DnsFraming.frame(request))
                connection.output.flush()
                return DnsFraming.read(connection.input) to true
            }
        }

    @Test
    fun `certificat non approuve - refuse`() {
        val accepts = AtomicInteger()
        server(keyStore(Quad9.SERVER_NAME), accepts).use { srv ->
            val dot = transport(srv.localPort, factoryTrusting(null), AtomicInteger())
            try {
                dot.exchange(byteArrayOf(1, 2, 3))
                fail("certificat autosigné accepté")
            } catch (e: IOException) {
                // attendu : SSLHandshakeException
            }
        }
    }

    @Test
    fun `certificat approuve mais pour un autre nom - refuse`() {
        val store = keyStore("autre.example")
        server(store, AtomicInteger()).use { srv ->
            val dot = transport(srv.localPort, factoryTrusting(store), AtomicInteger())
            try {
                dot.exchange(byteArrayOf(1, 2, 3))
                fail("nom d'hôte incorrect accepté")
            } catch (e: IOException) {
                // attendu : nom d'hôte vérifié
            }
        }
    }

    @Test
    fun `bon certificat - echange, socket protege, connexion reutilisee`() {
        val store = keyStore(Quad9.SERVER_NAME)
        val accepts = AtomicInteger()
        val protects = AtomicInteger()
        server(store, accepts).use { srv ->
            val dot = transport(srv.localPort, factoryTrusting(store), protects)
            assertArrayEquals(byteArrayOf(3, 2, 1), dot.exchange(byteArrayOf(1, 2, 3)))
            assertArrayEquals(byteArrayOf(5, 4), dot.exchange(byteArrayOf(4, 5)))
            assertEquals(1, accepts.get()) // une seule connexion pour les deux requêtes
            assertEquals(1, protects.get()) // protect() appelé avant de se connecter
            dot.close()
        }
    }
}
