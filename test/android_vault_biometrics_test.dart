import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/vault/vault_biometrics.dart';
import 'package:sentinel/services/vault/vault_file.dart';

// AndroidVaultBiometrics parle à VaultBiometric.kt : un faux canal joue
// Android. On vérifie surtout que chaque erreur Kotlin donne la bonne
// raison, et qu'une réponse mal formée n'est jamais acceptée.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.iheb.sentinel/vault');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const biometrics = AndroidVaultBiometrics();

  final secret = Uint8List.fromList(List.filled(32, 7));
  final aad = Uint8List.fromList([1, 2, 3]);
  final iv = Uint8List(EncryptedBlob.nonceLength);
  final chiffre = Uint8List.fromList(List.filled(48, 9));

  late List<MethodCall> calls;

  void android(Object? Function(MethodCall call) answer) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer(call);
    });
  }

  Matcher raison(BiometricError error) =>
      throwsA(isA<BiometricException>().having((e) => e.error, 'error', error));

  setUp(() => calls = []);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('sans code Android : indisponible partout', () async {
    expect(await biometrics.isAvailable(), isFalse);
    expect(
      biometrics.encrypt(secret, aad),
      raison(BiometricError.indisponible),
    );
    expect(
      biometrics.decrypt(EncryptedBlob(nonce: iv, cipherText: chiffre), aad),
      raison(BiometricError.indisponible),
    );
    await biometrics.deleteKey(); // pas d'erreur
  });

  test('disponibilité : réponse vide ou erreur = non', () async {
    android((call) => true);
    expect(await biometrics.isAvailable(), isTrue);
    android((call) => null);
    expect(await biometrics.isAvailable(), isFalse);
    android((call) => throw PlatformException(code: 'ERREUR'));
    expect(await biometrics.isAvailable(), isFalse);
  });

  test('chiffrer puis déchiffrer : arguments transmis', () async {
    android(
      (call) => switch (call.method) {
        'biometricEncrypt' => {'iv': iv, 'chiffre': chiffre},
        'biometricDecrypt' => secret,
        _ => null,
      },
    );
    final blob = await biometrics.encrypt(secret, aad);
    expect(blob.nonce, iv);
    expect(blob.cipherText, chiffre);
    expect(calls.single.arguments, {'data': secret, 'aad': aad});

    expect(await biometrics.decrypt(blob, aad), secret);
    expect(calls.last.arguments, {'iv': iv, 'chiffre': chiffre, 'aad': aad});
  });

  test('chiffrement mal formé renvoyé par Android : échec', () async {
    final reponses = <Object?>[
      null,
      'pas une Map',
      {'chiffre': chiffre}, // iv manquant
      {'iv': Uint8List(8), 'chiffre': chiffre}, // iv trop court
      {'iv': iv, 'chiffre': 'texte'},
    ];
    for (final reponse in reponses) {
      android((call) => reponse);
      expect(
        biometrics.encrypt(secret, aad),
        raison(BiometricError.echec),
        reason: '$reponse',
      );
    }
  });

  test('déchiffrement qui ne renvoie pas d\'octets : échec', () async {
    android((call) => 'texte');
    expect(
      biometrics.decrypt(EncryptedBlob(nonce: iv, cipherText: chiffre), aad),
      raison(BiometricError.echec),
    );
  });

  test('codes d\'erreur Kotlin traduits', () async {
    const attendu = {
      'INDISPONIBLE': BiometricError.indisponible,
      'INVALIDEE': BiometricError.invalidee,
      'ABSENTE': BiometricError.invalidee,
      'ANNULEE': BiometricError.annulee,
      'BLOQUEE': BiometricError.bloquee,
      'AUTRE': BiometricError.echec,
    };
    for (final MapEntry(key: code, value: erreur) in attendu.entries) {
      android((call) => throw PlatformException(code: code));
      await expectLater(biometrics.encrypt(secret, aad), raison(erreur));
    }
  });

  test('effacer la clé : erreur Android ignorée', () async {
    android((call) => throw PlatformException(code: 'ERREUR'));
    await biometrics.deleteKey();
    expect(calls.single.method, 'biometricDeleteKey');
  });

  test('le message d\'exception ne contient que la raison', () {
    expect(
      const BiometricException(BiometricError.bloquee).toString(),
      'BiometricException: bloquee',
    );
  });
}
