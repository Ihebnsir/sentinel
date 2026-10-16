import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sentinel/services/vault/vault_biometrics.dart';
import 'package:sentinel/services/vault/vault_file.dart';

/// Fausse empreinte pour les tests : une clé AES-GCM en mémoire joue le
/// rôle de la clé du Keystore. [invalidate] simule une empreinte ajoutée.
class FakeBiometrics implements VaultBiometrics {
  FakeBiometrics({this.available = true});

  bool available;

  /// Prochaine réponse forcée (annulation, blocage…).
  BiometricError? nextError;

  final _aes = AesGcm.with256bits();
  SecretKey? _key;
  int prompts = 0; // nombre de fenêtres d'empreinte affichées

  bool get hasKey => _key != null;

  /// Comme Android quand une empreinte est ajoutée : la clé est perdue.
  void invalidate() => _key = null;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<EncryptedBlob> encrypt(Uint8List secret, Uint8List aad) async {
    _check();
    final key = _key = await _aes.newSecretKey();
    final box = await _aes.encrypt(secret, secretKey: key, aad: aad);
    return EncryptedBlob(
      nonce: Uint8List.fromList(box.nonce),
      cipherText: box.concatenation(nonce: false),
    );
  }

  @override
  Future<Uint8List> decrypt(EncryptedBlob blob, Uint8List aad) async {
    final key = _key;
    if (key == null) throw const BiometricException(BiometricError.invalidee);
    _check();
    try {
      final clear = await _aes.decrypt(
        SecretBox.fromConcatenation(
          [...blob.nonce, ...blob.cipherText],
          nonceLength: 12,
          macLength: 16,
        ),
        secretKey: key,
        aad: aad,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const BiometricException(BiometricError.echec);
    }
  }

  @override
  Future<void> deleteKey() async => _key = null;

  void _check() {
    if (!available) throw const BiometricException(BiometricError.indisponible);
    prompts++;
    final error = nextError;
    nextError = null;
    if (error != null) throw BiometricException(error);
  }
}
