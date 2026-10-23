package com.iheb.sentinel.firewall

import java.security.GeneralSecurityException
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Chiffre les rapports d'analyse sur le disque (SEN-14). */
interface ReportCipher {
    fun encrypt(plain: ByteArray, aad: ByteArray): ByteArray

    /** Lève GeneralSecurityException si le fichier a été modifié ou déplacé. */
    fun decrypt(sealed: ByteArray, aad: ByteArray): ByteArray
}

/**
 * AES-256-GCM. Format : [version (1 o)][IV (12 o)][chiffré + tag (16 o)].
 * [aad] = nom du fichier : renommer un rapport (pour repousser son
 * expiration) le rend illisible. La clé vient du Keystore Android dans
 * l'app (ReportKeystore), d'une clé en mémoire dans les tests JUnit.
 */
class AesGcmReportCipher(private val key: () -> SecretKey) : ReportCipher {

    override fun encrypt(plain: ByteArray, aad: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key()) // IV aléatoire choisi par le système
        cipher.updateAAD(aad)
        val body = cipher.doFinal(plain)
        val iv = cipher.iv
        if (iv.size != IV_BYTES) throw GeneralSecurityException("IV inattendu")
        return byteArrayOf(VERSION) + iv + body
    }

    override fun decrypt(sealed: ByteArray, aad: ByteArray): ByteArray {
        if (sealed.size < 1 + IV_BYTES + TAG_BYTES || sealed[0] != VERSION) {
            throw GeneralSecurityException("Format inconnu")
        }
        val cipher = Cipher.getInstance(TRANSFORMATION)
        val iv = sealed.copyOfRange(1, 1 + IV_BYTES)
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(TAG_BYTES * 8, iv))
        cipher.updateAAD(aad)
        return cipher.doFinal(sealed, 1 + IV_BYTES, sealed.size - 1 - IV_BYTES)
    }

    companion object {
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val VERSION: Byte = 1
        private const val IV_BYTES = 12
        private const val TAG_BYTES = 16
    }
}
