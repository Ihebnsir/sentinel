import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/vault/recovery_key.dart';
import 'package:sentinel/services/vault/vault_crypto.dart';
import 'package:sentinel/services/vault/vault_file.dart';
import 'package:sentinel/services/vault/vault_item.dart';

// Paramètres faibles pour des tests rapides (jamais dans l'app).
KdfParams fastKdf() => newKdfParams(memoryKib: 64, iterations: 2);

const password = 'cheval correct batterie agrafe';
const newPassword = 'Une autre phrase bien plus longue 42';

final now = DateTime.utc(2026, 10, 16, 12);

final sample = [
  VaultItem(
    id: 'a1',
    type: VaultItemType.motDePasse,
    titre: 'Courriel',
    identifiant: 'moi@example.com',
    motDePasse: 'Tr0ub4dour&3',
    creeLe: DateTime.utc(2026, 1, 2),
    modifieLe: DateTime.utc(2026, 3, 4),
  ),
];

String jsonOf(List<VaultItem> items) =>
    jsonEncode([for (final item in items) item.toJson()]);

EncryptedBlob flipByte(EncryptedBlob blob, int index) {
  final cipher = Uint8List.fromList(blob.cipherText);
  cipher[index] ^= 0x01;
  return EncryptedBlob(nonce: blob.nonce, cipherText: cipher);
}

/// Coffre v2 avec des éléments, et sa clé de récupération.
Future<NewVault> sampleVault() async {
  final created = await createVault(password, kdf: fastKdf(), now: now);
  final file = await sealItems(created.dek, created.file, sample);
  return NewVault(file, created.dek, created.recoveryKey);
}

String fixture() => File('test/fixtures/vault_v1.json').readAsStringSync();

void main() {
  group('Migration v1 → v2', () {
    test('le coffre de la fixture est migré sans changer la DEK', () async {
      final v1 = VaultFile.decode(fixture());
      final dekV1 = await unwrapKey(password, v1);
      final itemsV1 = await openItems(dekV1, v1);

      final opening = await openWithPassword(password, v1, now: now);
      expect(opening.migrated, isTrue);
      expect(opening.dek, dekV1);
      expect(jsonOf(opening.items), jsonOf(itemsV1));

      // Comme au prochain lancement : relu depuis le texte écrit.
      final text = opening.file.encode();
      final v2 = VaultFile.decode(text);
      expect(v2.version, 2);
      expect(jsonDecode(text)['keySlots'], hasLength(1));
      expect(v2.recoverySlot, isNull);
      expect(v2.lastPasswordUnlock, now);
      // Mêmes paramètres Argon2 (même sel) : pas de second calcul.
      expect(v2.passwordSlot.kdf.salt, v1.passwordSlot.kdf.salt);

      final dekV2 = await unwrapKey(password, v2);
      expect(dekV2, dekV1);
      expect((await openItems(dekV2, v2)).map((i) => i.titre), [
        'Banque',
        'Wi-Fi maison',
      ]);
    });

    test('une seconde ouverture ne migre plus', () async {
      final first = await openWithPassword(
        password,
        VaultFile.decode(fixture()),
        now: now,
      );
      final second = await openWithPassword(password, first.file, now: now);
      expect(second.migrated, isFalse);
      expect(second.file.version, 2);
    });

    test('mauvais mot de passe : rien n\'est migré', () async {
      await expectLater(
        openWithPassword('faux', VaultFile.decode(fixture()), now: now),
        throwsA(isA<WrongPasswordException>()),
      );
    });
  });

  group('Clé de récupération', () {
    test(
      'mot de passe et clé donnent la même DEK et les mêmes éléments',
      () async {
        final vault = await sampleVault();
        final file = VaultFile.decode(vault.file.encode());
        final byPassword = await unwrapKey(password, file);
        final byRecovery = await unwrapWithRecoveryKey(vault.recoveryKey, file);
        expect(byPassword, vault.dek);
        expect(byRecovery, vault.dek);
        expect(
          jsonOf(await openItems(byRecovery, file)),
          jsonOf(await openItems(byPassword, file)),
        );
      },
    );

    test('mauvaise clé refusée', () async {
      final vault = await sampleVault();
      final good = RecoveryKey.normalize(vault.recoveryKey)!;
      // Un seul caractère changé (toujours dans l'alphabet).
      final last = good[good.length - 1];
      final typo =
          good.substring(0, good.length - 1) + (last == '2' ? '3' : '2');
      for (final wrong in [
        RecoveryKey.generate(),
        typo,
        good.substring(1), // trop courte
        'pas une clé',
        '',
      ]) {
        await expectLater(
          unwrapWithRecoveryKey(wrong, vault.file),
          throwsA(isA<WrongRecoveryKeyException>()),
          reason: wrong,
        );
      }
    });

    test('saisie tolérante : minuscules, espaces, sans tirets', () async {
      final vault = await sampleVault();
      final key = vault.recoveryKey;
      for (final typed in [
        key.toLowerCase(),
        key.replaceAll('-', ''),
        key.replaceAll('-', ' '),
        '  ${key.replaceAll('-', ' - ').toLowerCase()}  ',
      ]) {
        expect(await unwrapWithRecoveryKey(typed, vault.file), vault.dek);
      }
    });

    test('une nouvelle clé invalide l\'ancienne', () async {
      final vault = await sampleVault();
      final (file, newKey) = await replaceRecoveryKey(vault.dek, vault.file);
      expect(newKey, isNot(vault.recoveryKey));
      expect(await unwrapWithRecoveryKey(newKey, file), vault.dek);
      await expectLater(
        unwrapWithRecoveryKey(vault.recoveryKey, file),
        throwsA(isA<WrongRecoveryKeyException>()),
      );
      // Le mot de passe et les données ne bougent pas.
      expect(await unwrapKey(password, file), vault.dek);
      expect(jsonOf(await openItems(vault.dek, file)), jsonOf(sample));
    });

    test(
      'mot de passe oublié : nouveau mot de passe et nouvelle clé',
      () async {
        final vault = await sampleVault();
        final reset = await resetWithRecoveryKey(
          vault.recoveryKey,
          newPassword,
          vault.file,
          kdf: fastKdf(),
          now: now.add(const Duration(days: 30)),
        );
        final file = VaultFile.decode(reset.file.encode());
        expect(reset.dek, vault.dek);
        expect(jsonOf(reset.items), jsonOf(sample));
        expect(await unwrapKey(newPassword, file), vault.dek);
        await expectLater(
          unwrapKey(password, file),
          throwsA(isA<WrongPasswordException>()),
        );
        await expectLater(
          unwrapWithRecoveryKey(vault.recoveryKey, file),
          throwsA(isA<WrongRecoveryKeyException>()),
        );
        expect(await unwrapWithRecoveryKey(reset.recoveryKey, file), vault.dek);
        expect(file.lastPasswordUnlock, now.add(const Duration(days: 30)));
      },
    );
  });

  group('Format de la clé de récupération', () {
    test('7 groupes de 4, au moins 128 bits', () {
      final key = RecoveryKey.generate();
      expect(RecoveryKey.bits, greaterThanOrEqualTo(128));
      expect(key.length, 28 + 6);
      expect(RegExp(r'^([A-Z2-9]{4}-){6}[A-Z2-9]{4}$').hasMatch(key), isTrue);
    });

    test('alphabet de 32 caractères sans 0/O/1/I', () {
      expect(RecoveryKey.alphabet.length, 32);
      expect(RecoveryKey.alphabet.split('').toSet(), hasLength(32));
      for (final ambiguous in ['0', 'O', '1', 'I']) {
        expect(RecoveryKey.alphabet, isNot(contains(ambiguous)));
      }
      // Sur beaucoup de clés, seuls les caractères permis apparaissent.
      final rng = Random(42);
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        seen.addAll(RecoveryKey.generate(rng).replaceAll('-', '').split(''));
      }
      expect(seen.difference(RecoveryKey.alphabet.split('').toSet()), isEmpty);
    });

    test('deux clés sont différentes', () {
      expect(RecoveryKey.generate(), isNot(RecoveryKey.generate()));
    });

    test('normalisation', () {
      const key = 'K7QM-4XPA-ABCD-EFGH-JKLM-NPQR-STUV';
      const normalized = 'K7QM4XPAABCDEFGHJKLMNPQRSTUV';
      expect(RecoveryKey.normalize(key), normalized);
      expect(RecoveryKey.normalize(key.toLowerCase()), normalized);
      expect(
        RecoveryKey.normalize(' k7qm 4xpa abcd efgh jklm npqr stuv '),
        normalized,
      );
      expect(RecoveryKey.format(normalized), key);
      expect(RecoveryKey.lastGroup(key), 'STUV');
      // O, 0, 1, I : refusés ; longueur fausse : refusée.
      for (final bad in [
        key.replaceFirst('K', 'O'),
        key.replaceFirst('K', '0'),
        key.replaceFirst('K', '1'),
        key.replaceFirst('K', 'I'),
        key.substring(0, key.length - 1),
        '${key}A',
      ]) {
        expect(RecoveryKey.normalize(bad), isNull, reason: bad);
      }
    });
  });

  group('Changement du mot de passe maître', () {
    test('ancien refusé, nouveau accepté, données intactes', () async {
      final vault = await sampleVault();
      final file = VaultFile.decode(
        (await changePassword(
          password,
          newPassword,
          vault.file,
          vault.dek,
          kdf: fastKdf(),
          now: now,
        )).encode(),
      );
      await expectLater(
        unwrapKey(password, file),
        throwsA(isA<WrongPasswordException>()),
      );
      final dek = await unwrapKey(newPassword, file);
      expect(dek, vault.dek); // la DEK ne change jamais
      expect(jsonOf(await openItems(dek, file)), jsonOf(sample));
      // Nouveau sel ; l'emplacement de récupération est inchangé.
      expect(
        file.passwordSlot.kdf.salt,
        isNot(vault.file.passwordSlot.kdf.salt),
      );
      expect(
        jsonEncode(file.recoverySlot!.toJson()),
        jsonEncode(vault.file.recoverySlot!.toJson()),
      );
      expect(await unwrapWithRecoveryKey(vault.recoveryKey, file), vault.dek);
    });

    test('mauvais ancien mot de passe : refusé', () async {
      final vault = await sampleVault();
      await expectLater(
        changePassword('faux', newPassword, vault.file, vault.dek),
        throwsA(isA<WrongPasswordException>()),
      );
    });
  });

  group('Règle des 7 jours', () {
    VaultFile at(DateTime? last) => VaultFile(
      slots: const [],
      lastPasswordUnlock: last,
      data: EncryptedBlob(nonce: Uint8List(12), cipherText: Uint8List(16)),
    );

    test('empreinte acceptée pendant 7 jours, puis mot de passe exigé', () {
      final file = at(now);
      expect(file.needsPassword(now), isFalse);
      expect(file.needsPassword(now.add(const Duration(days: 7))), isFalse);
      expect(
        file.needsPassword(now.add(const Duration(days: 7, seconds: 1))),
        isTrue,
      );
    });

    test('sans date, ou horloge très en retard : mot de passe exigé', () {
      expect(at(null).needsPassword(now), isTrue);
      expect(
        at(now).needsPassword(now.subtract(const Duration(days: 2))),
        isTrue,
      );
    });

    test(
      'la date est enregistrée à chaque ouverture par mot de passe',
      () async {
        final vault = await sampleVault();
        final later = now.add(const Duration(days: 10, milliseconds: 1234));
        final opening = await openWithPassword(
          password,
          vault.file,
          now: later,
        );
        final file = VaultFile.decode(opening.file.encode());
        expect(file.lastPasswordUnlock, DateTime.utc(2026, 10, 26, 12, 0, 1));
        expect(file.needsPassword(later), isFalse);
        expect(jsonOf(await openItems(opening.dek, file)), jsonOf(sample));
      },
    );
  });

  group('Altérations détectées', () {
    test('un octet modifié dans un emplacement', () async {
      final vault = await sampleVault();
      final slot = vault.file.recoverySlot!;
      final tampered = vault.file.withSlot(
        RecoverySlot(salt: slot.salt, wrappedKey: flipByte(slot.wrappedKey, 2)),
      );
      await expectLater(
        unwrapWithRecoveryKey(vault.recoveryKey, tampered),
        throwsA(isA<WrongRecoveryKeyException>()),
      );
      // L'en-tête est l'AAD des données : même le mot de passe s'en aperçoit.
      await expectLater(
        openItems(vault.dek, tampered),
        throwsA(isA<VaultCorruptedException>()),
      );
      await expectLater(
        openWithPassword(password, tampered, now: now),
        throwsA(isA<VaultCorruptedException>()),
      );
    });

    test('sel de récupération modifié', () async {
      final vault = await sampleVault();
      final slot = vault.file.recoverySlot!;
      final salt = Uint8List.fromList(slot.salt)..[0] ^= 0x01;
      final tampered = vault.file.withSlot(
        RecoverySlot(salt: salt, wrappedKey: slot.wrappedKey),
      );
      await expectLater(
        unwrapWithRecoveryKey(vault.recoveryKey, tampered),
        throwsA(isA<WrongRecoveryKeyException>()),
      );
    });

    test('emplacement retiré ou date reculée (sans la DEK)', () async {
      final vault = await sampleVault();
      final removed = vault.file.copyWith(slots: [vault.file.passwordSlot]);
      final redated = vault.file.copyWith(
        lastPasswordUnlock: now.add(const Duration(days: 365)),
      );
      for (final tampered in [removed, redated]) {
        await expectLater(
          openItems(vault.dek, VaultFile.decode(tampered.encode())),
          throwsA(isA<VaultCorruptedException>()),
        );
      }
    });

    test('changement légitime : les données sont rescellées', () async {
      final vault = await sampleVault();
      final next = await reseal(
        vault.dek,
        vault.file,
        vault.file.copyWith(slots: [vault.file.passwordSlot]),
      );
      expect(jsonOf(await openItems(vault.dek, next)), jsonOf(sample));
    });
  });

  group('Lecture du format v2', () {
    test('relu à l\'identique (même en-tête)', () async {
      final vault = await sampleVault();
      final reread = VaultFile.decode(vault.file.encode());
      expect(reread.header, vault.file.header);
      expect(reread.slots.map((s) => s.runtimeType), [
        PasswordSlot,
        RecoverySlot,
      ]);
    });

    test('fichiers incohérents refusés', () async {
      final vault = await sampleVault();
      final json = vault.file.toJson();
      final slots = json['keySlots']! as List<Object?>;
      final variants = <Map<String, Object?>>[
        {
          ...json,
          'keySlots': [slots[0], slots[0]],
        }, // deux mots de passe
        {
          ...json,
          'keySlots': [slots[1]],
        }, // aucun mot de passe
        {
          ...json,
          'keySlots': [
            slots[0],
            {'type': 'inconnu', 'wrappedKey': (slots[1]! as Map)['wrappedKey']},
          ],
        },
        {...json}..remove('derniereOuvertureMdp'),
      ];
      for (final variant in variants) {
        expect(
          () => VaultFile.decode(jsonEncode(variant)),
          throwsA(isA<VaultFormatException>()),
        );
      }
    });
  });
}
