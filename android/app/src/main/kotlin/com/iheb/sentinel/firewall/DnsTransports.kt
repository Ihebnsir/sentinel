package com.iheb.sentinel.firewall

import android.annotation.SuppressLint
import java.io.BufferedInputStream
import java.io.IOException
import java.io.OutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.LinkedBlockingDeque
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SNIHostName
import javax.net.ssl.SSLPeerUnverifiedException
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory

/** Quad9 : adresses fixes (aucune résolution DNS) et nom du certificat. */
object Quad9 {
    const val SERVER_NAME = "dns.quad9.net"
    val ADDRESSES: List<InetAddress> = listOf(
        InetAddress.getByAddress(byteArrayOf(9, 9, 9, 9)),
        InetAddress.getByAddress(byteArrayOf(149.toByte(), 112, 112, 112)),
    )
}

/** Une connexion TLS ouverte, avec ses flux (gardée pour être réutilisée). */
class TlsConnection(val socket: SSLSocket) {
    val input = BufferedInputStream(socket.inputStream)
    val output: OutputStream = socket.outputStream

    // HTTP/2 (DoH) : préface envoyée, prochain flux client (impair).
    var http2Started = false
    var nextStream = 1

    fun close() {
        try {
            socket.close()
        } catch (e: IOException) {
            // Déjà fermée.
        }
    }
}

/**
 * Ouvre une connexion TLS vers Quad9 par son adresse IP (SEN-10) :
 * socket protégé par [protect] (il sort par le vrai réseau, pas par le VPN),
 * SNI = [serverName], certificat vérifié par le magasin système et nom
 * d'hôte vérifié deux fois (algorithme HTTPS + HostnameVerifier).
 */
class TlsConnector(
    private val protect: (Socket) -> Boolean,
    private val serverName: String = Quad9.SERVER_NAME,
    private val addresses: List<InetAddress> = Quad9.ADDRESSES,
    private val factory: SSLSocketFactory = SSLSocketFactory.getDefault() as SSLSocketFactory,
    private val verifier: HostnameVerifier = HttpsURLConnection.getDefaultHostnameVerifier(),
    private val connectTimeoutMs: Int = 3000,
    private val readTimeoutMs: Int = 3000,
) {
    /** [alpn] : protocole exigé (« h2 » pour DoH), ou null. */
    fun open(port: Int, alpn: String? = null): TlsConnection {
        var last: IOException? = null
        for (address in addresses) {
            try {
                return TlsConnection(connect(address, port, alpn))
            } catch (e: IOException) {
                last = e
            }
        }
        throw last ?: IOException("Aucune adresse")
    }

    // ALPN (API 29) n'est utilisé que si [alpn] est fourni : seul DohTransport
    // le fait, et uniquement à partir d'Android 10 (voir SentinelVpnService).
    @SuppressLint("NewApi")
    private fun connect(address: InetAddress, port: Int, alpn: String?): SSLSocket {
        val raw = Socket()
        try {
            // Le descripteur n'existe qu'une fois le socket lié : protect()
            // échouerait sur un socket neuf.
            raw.bind(null)
            val protected = try {
                protect(raw)
            } catch (e: RuntimeException) {
                false
            }
            if (!protected) throw IOException("protect() refusé")
            raw.connect(InetSocketAddress(address, port), connectTimeoutMs)
            raw.soTimeout = readTimeoutMs
            val ssl = factory.createSocket(raw, serverName, port, true) as SSLSocket
            ssl.sslParameters = ssl.sslParameters.apply {
                endpointIdentificationAlgorithm = "HTTPS"
                serverNames = listOf(SNIHostName(serverName))
                if (alpn != null) applicationProtocols = arrayOf(alpn)
            }
            ssl.startHandshake()
            if (alpn != null && ssl.applicationProtocol != alpn) {
                ssl.close()
                throw IOException("Protocole $alpn refusé par le serveur")
            }
            if (!verifier.verify(serverName, ssl.session)) {
                ssl.close()
                throw SSLPeerUnverifiedException("Certificat d'un autre nom que $serverName")
            }
            return ssl
        } catch (e: IOException) {
            try {
                raw.close()
            } catch (ignored: IOException) {
                // Déjà fermé.
            }
            throw e
        }
    }
}

/**
 * Connexions gardées ouvertes pour être réutilisées. Une connexion
 * réutilisée peut avoir été fermée par le serveur : on réessaie alors
 * une seule fois avec une connexion neuve.
 */
abstract class PooledTlsTransport(
    private val connector: TlsConnector,
    private val port: Int,
    private val alpn: String? = null,
    private val maxIdle: Int = 4,
) : DnsTransport {
    private val idle = LinkedBlockingDeque<TlsConnection>()

    /** Envoie [request] ; true dans la paire si la connexion reste utilisable. */
    protected abstract fun send(connection: TlsConnection, request: ByteArray): Pair<ByteArray, Boolean>

    override fun exchange(request: ByteArray): ByteArray {
        idle.pollFirst()?.let { reused ->
            try {
                return finish(reused, send(reused, request))
            } catch (e: IOException) {
                reused.close() // fermée par le serveur : nouvelle connexion
            }
        }
        val fresh = connector.open(port, alpn)
        try {
            return finish(fresh, send(fresh, request))
        } catch (e: IOException) {
            fresh.close()
            throw e
        }
    }

    private fun finish(connection: TlsConnection, result: Pair<ByteArray, Boolean>): ByteArray {
        if (result.second && idle.size < maxIdle) idle.offerFirst(connection) else connection.close()
        return result.first
    }

    override fun close() {
        while (true) (idle.pollFirst() ?: return).close()
    }
}

/** DNS-over-TLS, port 853 (RFC 7858). */
class DotTransport(connector: TlsConnector) : PooledTlsTransport(connector, 853) {
    override val mode = UpstreamMode.DOT

    override fun send(connection: TlsConnection, request: ByteArray): Pair<ByteArray, Boolean> {
        connection.output.write(DnsFraming.frame(request))
        connection.output.flush()
        return DnsFraming.read(connection.input) to true
    }
}

/**
 * DNS-over-HTTPS en HTTP/2, port 443 (RFC 8484), si le port 853 est bloqué.
 * Quad9 exige HTTP/2, négocié par ALPN : disponible à partir d'Android 10
 * ([available] faux avant : le transport échoue, sans jamais passer en clair).
 */
class DohTransport(
    connector: TlsConnector,
    private val available: Boolean = true,
) : PooledTlsTransport(connector, 443, alpn = DohHttp.ALPN) {
    override val mode = UpstreamMode.DOH

    override fun exchange(request: ByteArray): ByteArray {
        if (!available) throw IOException("DoH indisponible (ALPN : Android 10+)")
        return super.exchange(request)
    }

    override fun send(connection: TlsConnection, request: ByteArray): Pair<ByteArray, Boolean> {
        if (!connection.http2Started) {
            connection.output.write(DohHttp.connectionPreface())
            connection.http2Started = true
        }
        val stream = connection.nextStream
        connection.nextStream += 2
        connection.output.write(DohHttp.request(request, stream))
        connection.output.flush()
        val body = DohHttp.readResponse(connection.input, connection.output, stream)
        return body to (connection.nextStream < MAX_STREAMS)
    }

    private companion object {
        // Au-delà, nouvelle connexion (bien avant la limite de HTTP/2).
        const val MAX_STREAMS = 10_001
    }
}

/**
 * DNS en clair (UDP 53), comme avant SEN-10. Utilisé UNIQUEMENT si
 * l'utilisateur a choisi « Autoriser le DNS non chiffré sur ce réseau ».
 */
class PlainUdpTransport(
    private val protect: (DatagramSocket) -> Boolean,
    private val addresses: List<InetAddress> = Quad9.ADDRESSES,
    private val timeoutMs: Int = 2000,
) : DnsTransport {
    override val mode = UpstreamMode.PLAIN

    override fun exchange(request: ByteArray): ByteArray {
        var last: IOException? = null
        for (address in addresses) {
            try {
                DatagramSocket().use { socket ->
                    if (!protect(socket)) throw IOException("protect() refusé")
                    socket.soTimeout = timeoutMs
                    socket.connect(address, 53)
                    socket.send(DatagramPacket(request, request.size))
                    val buffer = ByteArray(4096)
                    val packet = DatagramPacket(buffer, buffer.size)
                    socket.receive(packet)
                    return buffer.copyOf(packet.length)
                }
            } catch (e: IOException) {
                last = e
            }
        }
        throw last ?: IOException("Aucune adresse")
    }

    override fun close() = Unit
}
