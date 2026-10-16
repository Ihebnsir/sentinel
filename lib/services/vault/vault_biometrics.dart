import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'vault_file.dart';

/// Pourquoi l'empreinte n'a pas abouti.
enum BiometricError {
  indisponible, // pas d'Android, pas de capteur, ou aucune empreinte
  invalidee, // nouvelle empreinte ajoutée, ou clé Keystore absente
  annulee, // l'utilisateur a choisi le mot de passe ou fermé la fenêtre
  bloquee, // trop d'essais : le capteur est bloqué un moment
  echec, // autre erreur (chiffré abîmé, erreur système…)
}

class BiometricException implements Exception {
  const BiometricException(this.error);

  final BiometricError error;

  @override
  String toString() => 'BiometricException: ${error.name}';
}

/// Chiffre / déchiffre la DEK avec une clé protégée par l'empreinte.
/// Interface séparée pour pouvoir la simuler dans les tests.
abstract class VaultBiometrics {
  /// Un capteur fort (BIOMETRIC_STRONG) avec au moins une empreinte ?
  Future<bool> isAvailable();

  /// Crée une clé neuve, demande l'empreinte, puis chiffre [secret].
  Future<EncryptedBlob> encrypt(Uint8List secret, Uint8List aad);

  /// Demande l'empreinte puis déchiffre.
  Future<Uint8List> decrypt(EncryptedBlob blob, Uint8List aad);

  /// Efface la clé du Keystore (rien à faire si elle n'existe pas).
  Future<void> deleteKey();
}

/// Version Android : Keystore + BiometricPrompt (VaultBiometric.kt).
/// Sur Windows (ou ailleurs), tout est « indisponible ».
class AndroidVaultBiometrics implements VaultBiometrics {
  const AndroidVaultBiometrics();

  // Même canal que les autres protections du coffre (VaultProtection.kt).
  static const _channel = MethodChannel('com.iheb.sentinel/vault');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isAvailable() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('biometricAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<EncryptedBlob> encrypt(Uint8List secret, Uint8List aad) async {
    final result = await _call('biometricEncrypt', {
      'data': secret,
      'aad': aad,
    });
    if (result is! Map) throw const BiometricException(BiometricError.echec);
    final iv = result['iv'];
    final cipherText = result['chiffre'];
    if (iv is! Uint8List ||
        iv.length != EncryptedBlob.nonceLength ||
        cipherText is! Uint8List) {
      throw const BiometricException(BiometricError.echec);
    }
    return EncryptedBlob(nonce: iv, cipherText: cipherText);
  }

  @override
  Future<Uint8List> decrypt(EncryptedBlob blob, Uint8List aad) async {
    final result = await _call('biometricDecrypt', {
      'iv': blob.nonce,
      'chiffre': blob.cipherText,
      'aad': aad,
    });
    if (result is! Uint8List) {
      throw const BiometricException(BiometricError.echec);
    }
    return result;
  }

  @override
  Future<void> deleteKey() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('biometricDeleteKey');
    } on PlatformException {
      // Rien à effacer.
    } on MissingPluginException {
      // Idem.
    }
  }

  // Traduit les codes d'erreur de Kotlin. Jamais de détails dans les
  // journaux : les arguments contiennent la DEK.
  Future<Object?> _call(String method, Map<String, Object> arguments) async {
    if (!_isAndroid) {
      throw const BiometricException(BiometricError.indisponible);
    }
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      throw const BiometricException(BiometricError.indisponible);
    } on PlatformException catch (e) {
      throw BiometricException(switch (e.code) {
        'INDISPONIBLE' => BiometricError.indisponible,
        'INVALIDEE' || 'ABSENTE' => BiometricError.invalidee,
        'ANNULEE' => BiometricError.annulee,
        'BLOQUEE' => BiometricError.bloquee,
        _ => BiometricError.echec,
      });
    }
  }
}
