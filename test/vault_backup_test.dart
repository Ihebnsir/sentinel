import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/vault/vault_backup.dart';
import 'package:sentinel/services/vault/vault_crypto.dart';
import 'package:sentinel/services/vault/vault_file.dart';
import 'package:sentinel/services/vault/vault_item.dart';
import 'package:sentinel/services/vault/vault_session.dart';
import 'package:sentinel/services/vault/vault_storage.dart';

import 'support/fake_biometrics.dart';

// Paramètres faibles pour des tests rapides (jamais dans l'app).
KdfParams fastKdf() => newKdfParams(memoryKib: 64, iterations: 2);

const exportPassword = 'phrase pour le nouveau téléphone 7';
const masterPassword = 'cheval correct batterie agrafe';

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

Map<String, Object?> asJson(Uint8List bytes) =>
    jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;

Uint8List fromJson(Map<String, Object?> json) => utf8.encode(jsonEncode(json));

Matcher throwsProblem(BackupProblem problem) => throwsA(
  isA<BackupFormatException>().having((e) => e.problem, 'problem', problem),
);

void main() {
  late Uint8List backup;

  setUpAll(() async {
    backup = await exportBackup(sample, exportPassword, kdf: fastKdf());
  });

  test('aller-retour : tous les champs sont retrouvés', () async {
    final items = await importBackup(backup, exportPassword);
    expect(
      items.map((i) => i.toJson()).toList(),
      sample.map((i) => i.toJson()).toList(),
    );
  });

  test('format versionné, sans rien en clair', () {
    final json = asJson(backup);
    expect(json['format'], VaultBackup.formatName);
    expect(json['version'], VaultBackup.currentVersion);
    expect((json['kdf'] as Map)['algo'], 'argon2id');
    final text = utf8.decode(backup);
    for (final secret in ['Tr0ub4dour', 'Courriel', 'moi@example', '1234']) {
      expect(text, isNot(contains(secret)));
    }
  });

  test('deux exports du même coffre diffèrent (sel et nonce neufs)', () async {
    final again = await exportBackup(sample, exportPassword, kdf: fastKdf());
    expect(asJson(again)['kdf'], isNot(asJson(backup)['kdf']));
    expect(asJson(again)['data'], isNot(asJson(backup)['data']));
  });

  test('mauvais mot de passe : refusé', () {
    expect(
      importBackup(backup, 'pas le bon mot de passe du tout'),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('chiffré altéré : refusé comme un mauvais mot de passe', () {
    final json = asJson(backup);
    final data = json['data'] as Map<String, Object?>;
    final cipher = base64.decode(data['chiffre'] as String);
    cipher[0] ^= 0x01;
    data['chiffre'] = base64.encode(cipher);
    expect(
      importBackup(fromJson(json), exportPassword),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('en-tête altéré : refusé, même avec le bon mot de passe', () {
    final json = asJson(backup);
    (json['kdf'] as Map<String, Object?>)['iterations'] = 3;
    expect(
      importBackup(fromJson(json), exportPassword),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('version inconnue : message dédié, sans dériver de clé', () {
    final json = asJson(backup)..['version'] = 99;
    expect(
      () => VaultBackup.decode(fromJson(json)),
      throwsProblem(BackupProblem.versionInconnue),
    );
    expect(
      importBackup(fromJson(json), exportPassword),
      throwsProblem(BackupProblem.versionInconnue),
    );
  });

  test('fichier vide', () {
    expect(
      () => VaultBackup.decode(Uint8List(0)),
      throwsProblem(BackupProblem.vide),
    );
    expect(
      importBackup(Uint8List(0), exportPassword),
      throwsProblem(BackupProblem.vide),
    );
  });

  test("fichiers qui n'en sont pas : illisibles, sans plantage", () {
    final notBackups = <Uint8List>[
      utf8.encode('bonjour'),
      Uint8List.fromList([0xff, 0xfe, 0x00, 0x81]), // pas de l'UTF-8
      utf8.encode('[1, 2, 3]'),
      utf8.encode('{"version": 1}'), // pas de « format »
      // Un vault.json n'est pas une sauvegarde.
      File('test/fixtures/vault_v1.json').readAsBytesSync(),
      fromJson(asJson(backup)..remove('data')),
      fromJson(asJson(backup)..['kdf'] = {'algo': 'scrypt'}),
      // Paramètres absurdes : refusés avant Argon2.
      fromJson(
        asJson(backup)
          ..['kdf'] = {
            ...(asJson(backup)['kdf'] as Map<String, Object?>),
            'memoire': 50 * 1024 * 1024,
          },
      ),
      Uint8List(VaultBackup.maxBytes + 1),
    ];
    for (final bytes in notBackups) {
      expect(
        () => VaultBackup.decode(bytes),
        throwsProblem(BackupProblem.illisible),
      );
    }
  });

  group('session', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('sauvegarde_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    VaultSession newSession() => VaultSession(
      storage: VaultStorage(directory: () async => dir),
      biometrics: FakeBiometrics(),
      kdfForNewVault: fastKdf,
    );

    test(
      'restaurer : coffre neuf, nouveau mot de passe, nouvelle clé',
      () async {
        final session = newSession();
        await session.load();
        expect(session.status, VaultStatus.absent);

        final items = await session.readBackup(backup, exportPassword);
        await session.restore(items, masterPassword);
        expect(session.status, VaultStatus.ouvert);
        expect(session.pendingRecoveryKey, isNotNull);
        expect(session.items.map((i) => i.id), containsAll(['a1', 'b2']));

        // Rouvert depuis le disque avec le NOUVEAU mot de passe.
        session.lock();
        final reopened = newSession();
        await reopened.load();
        expect(await reopened.unlock(exportPassword), UnlockResult.incorrect);
        reopened.dispose();
        final again = newSession();
        await again.load();
        expect(await again.unlock(masterPassword), UnlockResult.ouvert);
        expect(again.items.length, 2);

        // Et l'export du coffre restauré se relit.
        final reexport = await again.createBackup(exportPassword);
        expect((await importBackup(reexport, exportPassword)).length, 2);
        again.dispose();
        session.dispose();
      },
    );

    test('restaurer par-dessus un coffre existant : interdit', () async {
      final session = newSession();
      await session.load();
      await session.create(masterPassword);
      expect(() => session.restore(sample, masterPassword), throwsStateError);
      session.lock();
      expect(() => session.createBackup(exportPassword), throwsStateError);
      session.dispose();
    });
  });
}
