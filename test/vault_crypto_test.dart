import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/vault/vault_crypto.dart';
import 'package:sentinel/services/vault/vault_file.dart';
import 'package:sentinel/services/vault/vault_item.dart';

// Paramètres faibles pour des tests rapides (jamais dans l'app).
KdfParams fastKdf() => newKdfParams(memoryKib: 64, iterations: 2);

const password = 'cheval correct batterie agrafe';

final sample = [
  VaultItem(
    id: 'a1',
    type: VaultItemType.motDePasse,
    titre: 'Courriel',
    identifiant: 'moi@example.com',
    motDePasse: 'Tr0ub4dour&3',
    siteWeb: 'https://mail.example',
    note: 'Compte principal',
    creeLe: DateTime.utc(2026, 1, 2),
    modifieLe: DateTime.utc(2026, 3, 4),
  ),
  VaultItem(
    id: 'b2',
    type: VaultItemType.note,
    titre: 'Codes de secours',
    note: 'é ü 🔐\n1234-5678',
    creeLe: DateTime.utc(2026, 5, 6),
    modifieLe: DateTime.utc(2026, 5, 6),
  ),
];

/// Copie d'un bloc avec un octet inversé à la position [index].
EncryptedBlob flipByte(EncryptedBlob blob, int index) {
  final cipher = Uint8List.fromList(blob.cipherText);
  cipher[index] ^= 0x01;
  return EncryptedBlob(nonce: blob.nonce, cipherText: cipher);
}

/// Même fichier, avec un en-tête légèrement différent.
VaultFile withHeader(VaultFile file, {int? version, int? iterations}) {
  final slot = file.passwordSlot;
  return VaultFile(
    version: version ?? file.version,
    slots: [
      PasswordSlot(
        kdf: KdfParams(
          memoryKib: slot.kdf.memoryKib,
          iterations: iterations ?? slot.kdf.iterations,
          parallelism: slot.kdf.parallelism,
          salt: slot.kdf.salt,
        ),
        wrappedKey: slot.wrappedKey,
      ),
      ...file.slots.skip(1),
    ],
    lastPasswordUnlock: file.lastPasswordUnlock,
    data: file.data,
  );
}

String jsonOf(List<VaultItem> items) =>
    jsonEncode([for (final item in items) item.toJson()]);

void main() {
  group('Argon2id', () {
    test('vecteur de test officiel RFC 9106 (section 5.3)', () async {
      // m = 32 Kio, t = 3, p = 4, mot de passe 32 × 0x01, sel 16 × 0x02,
      // secret 8 × 0x03, données associées 12 × 0x04.
      const argon2id = DartArgon2id(
        memory: 32,
        iterations: 3,
        parallelism: 4,
        hashLength: 32,
      );
      final key = await argon2id.deriveKey(
        secretKey: SecretKey(List.filled(32, 0x01)),
        nonce: List.filled(16, 0x02),
        optionalSecret: List.filled(8, 0x03),
        associatedData: List.filled(12, 0x04),
      );
      final hex = (await key.extractBytes())
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(
        hex,
        '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659',
      );
    });

    test('paramètres par défaut au moins au niveau OWASP', () {
      expect(defaultMemoryKib, greaterThanOrEqualTo(19 * 1024));
      expect(defaultIterations, greaterThanOrEqualTo(2));
      expect(defaultParallelism, 1);
    });

    test('sel aléatoire de 16 octets, différent à chaque coffre', () {
      final a = newKdfParams();
      final b = newKdfParams();
      expect(a.salt.length, 16);
      expect(a.salt, isNot(equals(b.salt)));
    });
  });

  group('Chiffrement du coffre', () {
    test('chiffrer puis déchiffrer redonne les mêmes données', () async {
      final created = await createVault(password, kdf: fastKdf());
      final sealed = await sealItems(created.dek, created.file, sample);

      // Comme au prochain lancement : relu depuis le texte du fichier.
      final reread = VaultFile.decode(sealed.encode());
      final dek = await unwrapKey(password, reread);
      expect(dek, created.dek);
      expect(jsonOf(await openItems(dek, reread)), jsonOf(sample));
    });

    test('un coffre neuf est vide', () async {
      final created = await createVault(password, kdf: fastKdf());
      expect(await openItems(created.dek, created.file), isEmpty);
    });

    test('mauvais mot de passe : échec propre', () async {
      final created = await createVault(password, kdf: fastKdf());
      await expectLater(
        unwrapKey('cheval correct batterie agrafée', created.file),
        throwsA(
          isA<WrongPasswordException>().having(
            (e) => e.toString(),
            'message',
            'Mot de passe incorrect',
          ),
        ),
      );
    });

    test('un octet modifié dans les données chiffrées est détecté', () async {
      final created = await createVault(password, kdf: fastKdf());
      final file = await sealItems(created.dek, created.file, sample);
      // Au début (chiffré) et à la fin (tag d'authentification).
      for (final index in [0, file.data.cipherText.length - 1]) {
        final tampered = file.withData(flipByte(file.data, index));
        await expectLater(
          openItems(created.dek, tampered),
          throwsA(isA<VaultCorruptedException>()),
        );
      }
    });

    test('un octet modifié dans la clé enveloppée est détecté', () async {
      final created = await createVault(password, kdf: fastKdf());
      final file = created.file;
      final slot = file.passwordSlot;
      final tampered = file.withSlot(
        PasswordSlot(kdf: slot.kdf, wrappedKey: flipByte(slot.wrappedKey, 3)),
      );
      await expectLater(
        unwrapKey(password, tampered),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('un en-tête modifié est détecté (AAD)', () async {
      final created = await createVault(password, kdf: fastKdf());
      final file = await sealItems(created.dek, created.file, sample);
      // Même DEK : seule l'AAD change, et GCM le remarque.
      for (final tampered in [
        withHeader(file, version: 3),
        withHeader(file, iterations: 3),
      ]) {
        await expectLater(
          openItems(created.dek, tampered),
          throwsA(isA<VaultCorruptedException>()),
        );
      }
      await expectLater(
        unwrapKey(password, withHeader(file, iterations: 3)),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test(
      'deux chiffrements identiques : nonces et chiffrés différents',
      () async {
        final created = await createVault(password, kdf: fastKdf());
        final a = await sealItems(created.dek, created.file, sample);
        final b = await sealItems(created.dek, created.file, sample);
        expect(a.data.nonce.length, 12);
        expect(a.data.nonce, isNot(equals(b.data.nonce)));
        expect(a.data.cipherText, isNot(equals(b.data.cipherText)));
        // Et les deux se déchiffrent bien.
        expect(jsonOf(await openItems(created.dek, b)), jsonOf(sample));
      },
    );

    test('le fichier ne contient aucun secret en clair', () async {
      final created = await createVault(password, kdf: fastKdf());
      final text = (await sealItems(
        created.dek,
        created.file,
        sample,
      )).encode();
      for (final secret in [
        'Tr0ub4dour',
        'Courriel',
        'moi@example',
        password,
      ]) {
        expect(text, isNot(contains(secret)));
      }
    });

    test('wipe remplit la clé de zéros', () {
      final key = Uint8List.fromList([1, 2, 3, 4]);
      wipe(key);
      expect(key, [0, 0, 0, 0]);
    });
  });

  group('Format du fichier', () {
    test("lecture d'un coffre de version 1 connu", () async {
      final text = File('test/fixtures/vault_v1.json').readAsStringSync();
      final file = VaultFile.decode(text);
      expect(file.version, 1);
      final kdf = file.passwordSlot.kdf;
      expect(kdf.memoryKib, 64);
      expect(kdf.iterations, 2);
      expect(kdf.parallelism, 1);
      expect(kdf.salt.length, 16);

      final dek = await unwrapKey(password, file);
      final items = await openItems(dek, file);
      expect(items.map((i) => i.titre), ['Banque', 'Wi-Fi maison']);
      final banque = items.first;
      expect(banque.type, VaultItemType.motDePasse);
      expect(banque.identifiant, 'iheb@example.com');
      expect(banque.motDePasse, 'S3cr3t!-exemple');
      expect(banque.siteWeb, 'https://banque.example');
      expect(banque.creeLe, DateTime.utc(2026, 10, 15, 9));
      expect(items.last.type, VaultItemType.note);
      expect(items.last.note, 'Réseau : Maison\nClé : exemple-de-note');
    });

    test('version inconnue refusée', () {
      final json = jsonDecode(
        File('test/fixtures/vault_v1.json').readAsStringSync(),
      ) as Map<String, Object?>;
      json['version'] = 99;
      expect(
        () => VaultFile.decode(jsonEncode(json)),
        throwsA(isA<VaultFormatException>()),
      );
    });

    test('paramètres absurdes refusés (fichier trafiqué)', () {
      final json = jsonDecode(
        File('test/fixtures/vault_v1.json').readAsStringSync(),
      ) as Map<String, Object?>;
      (json['kdf'] as Map<String, Object?>)['memoire'] = 1 << 30;
      expect(
        () => VaultFile.decode(jsonEncode(json)),
        throwsA(isA<VaultFormatException>()),
      );
    });

    test('texte illisible refusé', () {
      for (final text in ['', 'pas du json', '[]', '{"version": 1}']) {
        expect(
          () => VaultFile.decode(text),
          throwsA(isA<VaultFormatException>()),
        );
      }
    });
  });
}
