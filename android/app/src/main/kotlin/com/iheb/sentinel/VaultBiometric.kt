package com.iheb.sentinel

import android.app.Activity
import android.content.Context
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.hardware.fingerprint.FingerprintManager
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Ouverture du coffre par empreinte : la DEK est chiffrée par une clé
 * AES-256-GCM qui ne quitte jamais l'Android Keystore, et qui ne sert
 * qu'après une empreinte forte (BIOMETRIC_STRONG), à chaque utilisation.
 * Ne journalise jamais la DEK ni le chiffré.
 */
class VaultBiometric(private val activity: Activity) {

    companion object {
        const val KEY_ALIAS = "sentinel_vault_bio"
        private const val KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val TAG_BITS = 128
    }

    // Fenêtre d'empreinte en cours (une seule à la fois).
    private var cancelSignal: CancellationSignal? = null

    /** Android 9+ avec un capteur fort et au moins une empreinte. */
    fun isAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                val manager = activity.getSystemService(BiometricManager::class.java)
                manager?.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
                    BiometricManager.BIOMETRIC_SUCCESS
            }
            Build.VERSION.SDK_INT == Build.VERSION_CODES.Q -> {
                val manager = activity.getSystemService(BiometricManager::class.java)
                @Suppress("DEPRECATION")
                manager?.canAuthenticate() == BiometricManager.BIOMETRIC_SUCCESS
            }
            else -> {
                // Android 9 : pas de BiometricManager, on interroge le capteur.
                @Suppress("DEPRECATION")
                val manager = activity.getSystemService(Context.FINGERPRINT_SERVICE) as? FingerprintManager
                @Suppress("DEPRECATION")
                manager != null && manager.isHardwareDetected && manager.hasEnrolledFingerprints()
            }
        }
    }

    /** Clé neuve, empreinte, puis chiffre [data] ; renvoie l'IV et le chiffré. */
    fun encrypt(data: ByteArray, aad: ByteArray, result: MethodChannel.Result) {
        if (!isAvailable()) return result.error("INDISPONIBLE", null, null)
        val cipher = try {
            deleteKey()
            Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, generateKey()) }
        } catch (e: Exception) {
            return result.error("ECHEC", null, null)
        }
        authenticate(
            cipher,
            title = R.string.biometric_enable_title,
            negative = R.string.biometric_cancel,
            result = result,
        ) { c ->
            c.updateAAD(aad)
            val cipherText = c.doFinal(data)
            mapOf("iv" to c.iv, "chiffre" to cipherText)
        }
    }

    /** Empreinte, puis déchiffre la DEK. */
    fun decrypt(iv: ByteArray, cipherText: ByteArray, aad: ByteArray, result: MethodChannel.Result) {
        if (!isAvailable()) return result.error("INDISPONIBLE", null, null)
        val key = try {
            loadKey()
        } catch (e: Exception) {
            null
        } ?: return result.error("ABSENTE", null, null)
        val cipher = try {
            Cipher.getInstance(TRANSFORMATION).apply {
                init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, iv))
            }
        } catch (e: KeyPermanentlyInvalidatedException) {
            // Empreinte ajoutée (ou toutes supprimées) : la clé est morte.
            deleteKey()
            return result.error("INVALIDEE", null, null)
        } catch (e: Exception) {
            return result.error("ECHEC", null, null)
        }
        authenticate(
            cipher,
            title = R.string.biometric_open_title,
            negative = R.string.biometric_use_password,
            result = result,
        ) { c ->
            c.updateAAD(aad)
            c.doFinal(cipherText)
        }
    }

    fun deleteKey() {
        try {
            val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
            if (keyStore.containsAlias(KEY_ALIAS)) keyStore.deleteEntry(KEY_ALIAS)
        } catch (e: Exception) {
            // Rien à effacer.
        }
    }

    fun dispose() {
        cancelSignal?.cancel()
        cancelSignal = null
    }

    private fun loadKey(): SecretKey? {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        return keyStore.getKey(KEY_ALIAS, null) as? SecretKey
    }

    // AES-256-GCM, inextractible, empreinte forte exigée à chaque usage,
    // invalidée si une nouvelle empreinte est enregistrée.
    private fun generateKey(): SecretKey {
        val builder = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // 0 seconde : une authentification par opération.
            builder.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
        } else {
            // Équivalent avant Android 11 : -1 = à chaque usage, biométrie seule.
            @Suppress("DEPRECATION")
            builder.setUserAuthenticationValidityDurationSeconds(-1)
        }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        generator.init(builder.build())
        return generator.generateKey()
    }

    // Affiche la fenêtre d'empreinte ; après succès, le Keystore autorise
    // UNE opération avec ce Cipher précis (CryptoObject).
    private fun authenticate(
        cipher: Cipher,
        title: Int,
        negative: Int,
        result: MethodChannel.Result,
        operation: (Cipher) -> Any,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return result.error("INDISPONIBLE", null, null)
        }
        cancelSignal?.cancel() // une fenêtre précédente répondra « ANNULEE »
        val signal = CancellationSignal()
        cancelSignal = signal
        var answered = false
        fun answer(block: () -> Unit) {
            if (answered) return
            answered = true
            if (cancelSignal === signal) cancelSignal = null
            block()
        }

        val executor = activity.mainExecutor
        // Textes dans la langue choisie dans Réglages.
        val texts = AppLanguage.localized(activity)
        val builder = BiometricPrompt.Builder(activity)
            .setTitle(texts.getString(title))
            .setSubtitle(texts.getString(R.string.biometric_subtitle))
            .setNegativeButton(texts.getString(negative), executor) { _, _ ->
                answer { result.error("ANNULEE", null, null) }
            }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setConfirmationRequired(false)
        }

        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(res: BiometricPrompt.AuthenticationResult) {
                val authorized = res.cryptoObject?.cipher
                    ?: return answer { result.error("ECHEC", null, null) }
                answer {
                    try {
                        result.success(operation(authorized))
                    } catch (e: AEADBadTagException) {
                        result.error("ECHEC", null, null) // chiffré modifié
                    } catch (e: Exception) {
                        result.error("ECHEC", null, null)
                    }
                }
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence?) {
                val code = when (errorCode) {
                    BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT,
                    BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT_PERMANENT -> "BLOQUEE"
                    BiometricPrompt.BIOMETRIC_ERROR_HW_NOT_PRESENT,
                    BiometricPrompt.BIOMETRIC_ERROR_HW_UNAVAILABLE,
                    BiometricPrompt.BIOMETRIC_ERROR_NO_BIOMETRICS -> "INDISPONIBLE"
                    else -> "ANNULEE" // annulé, délai dépassé, autre fenêtre…
                }
                answer { result.error(code, null, null) }
            }

            // onAuthenticationFailed : doigt non reconnu, la fenêtre
            // reste ouverte et l'utilisateur réessaie.
        }

        try {
            builder.build().authenticate(BiometricPrompt.CryptoObject(cipher), signal, executor, callback)
        } catch (e: Exception) {
            answer { result.error("ECHEC", null, null) }
        }
    }
}
