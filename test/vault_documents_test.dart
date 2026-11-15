import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/vault/vault_backup.dart';
import 'package:sentinel/services/vault/vault_crypto.dart';
import 'package:sentinel/services/vault/vault_documents.dart';
import 'package:sentinel/services/vault/vault_file.dart';
import 'package:sentinel/services/vault/vault_item.dart';
import 'package:sentinel/services/vault/vault_session.dart';
import 'package:sentinel/services/vault/vault_storage.dart';

import 'support/fake_biometrics.dart';

// Paramètres faibles pour des tests rapides (jamais dans l'app).
KdfParams fastKdf() => newKdfParams(memoryKib: 64, iterations: 2);

const masterPassword = 'cheval correct batterie agrafe';
const exportPassword = 'phrase pour le nouveau téléphone 7';

// Marqueur cherché dans chaque fichier : il ne doit jamais y être en clair.
const marker = 'CONTENU-SECRET-DU-DOCUMENT';

Uint8List pdfBytes([String extra = '']) =>
    utf8.encode('%PDF-1.7\n$marker $extra\n${'x' * 3000}\n%%EOF');

Uint8List jpegBytes() => Uint8List.fromList([
  0xFF, 0xD8, 0xFF, 0xE0, //
  ...utf8.encode(marker),
  0xFF, 0xD9,
]);

VaultItem documentItem(String id, Uint8List content, {String titre = 'CNI'}) =>
    VaultItem(
      id: id,
      type: VaultItemType.document,
      titre: titre,
      mime: detectDocumentMime(content)!,
      taille: content.length,
      creeLe: DateTime.utc(2026, 11, 1),
      modifieLe: DateTime.utc(2026, 11, 1),
    );

bool containsBytes(Uint8List haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

/// Aucun fichier du dossier ne contient le marqueur en clair, et aucun
/// fichier temporaire n'est resté.
void expectNoClearFile(Directory dir) {
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    expect(entity.path, isNot(endsWith('.tmp')), reason: 'temporaire oublié');
    expect(
      containsBytes(entity.readAsBytesSync(), utf8.encode(marker)),
      isFalse,
      reason: '${entity.path} contient le document en clair',
    );
  }
}

File docFile(Directory dir, String id) => File(
  '${dir.path}${Platform.pathSeparator}${VaultDocumentStore.folderName}'
  '${Platform.pathSeparator}$id.bin',
);

Map<String, Object?> asJson(Uint8List bytes) =>
    jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;

Uint8List fromJson(Map<String, Object?> json) => utf8.encode(jsonEncode(json));

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('documents_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  VaultSession newSession() => VaultSession(
    storage: VaultStorage(directory: () async => dir),
    biometrics: FakeBiometrics(),
    kdfForNewVault: fastKdf,
  );

  Future<VaultSession> openedSession() async {
    final session = newSession();
    await session.load();
    await session.create(masterPassword);
    session.recoveryKeyNoted();
    return session;
  }

  group('type du fichier (premiers octets)', () {
    test('images et PDF reconnus, le reste refusé', () {
      expect(detectDocumentMime(jpegBytes()), 'image/jpeg');
      expect(
        detectDocumentMime(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
        'image/png',
      );
      expect(
        detectDocumentMime(utf8.encode('RIFF\x00\x00\x00\x00WEBPVP8 ')),
        'image/webp',
      );
      expect(detectDocumentMime(pdfBytes()), 'application/pdf');
      expect(detectDocumentMime(utf8.encode('bonjour')), isNull);
      expect(detectDocumentMime(utf8.encode('MZ\x90\x00')), isNull); // .exe
      expect(detectDocumentMime(Uint8List(0)), isNull);
    });
  });

  group('fichier chiffré', () {
    final dek = Uint8List.fromList(List.generate(32, (i) => i));
    late VaultDocumentStore store;

    setUp(() => store = VaultDocumentStore(directory: () async => dir));

    test(
      'aller-retour : contenu identique, rien en clair sur le disque',
      () async {
        final content = pdfBytes();
        await store.write('doc1', dek, content);
        expect(await store.read('doc1', dek), content);
        final onDisk = docFile(dir, 'doc1').readAsBytesSync();
        expect(utf8.decode(onDisk.sublist(0, 4)), 'SDOC');
        expect(onDisk.length, 4 + 1 + 12 + content.length + 16);
        expectNoClearFile(dir);
      },
    );

    test('deux écritures du même contenu : nonces différents', () async {
      final content = pdfBytes();
      await store.write('a', dek, content);
      await store.write('b', dek, content);
      final a = docFile(dir, 'a').readAsBytesSync().sublist(5, 17);
      final b = docFile(dir, 'b').readAsBytesSync().sublist(5, 17);
      expect(a, isNot(b));
    });

    test('un octet modifié : refusé', () async {
      await store.write('doc1', dek, pdfBytes());
      final file = docFile(dir, 'doc1');
      final bytes = file.readAsBytesSync();
      bytes[bytes.length ~/ 2] ^= 0x01;
      file.writeAsBytesSync(bytes);
      expect(store.read('doc1', dek), throwsA(isA<VaultCorruptedException>()));
    });

    test('tag, nonce ou en-tête modifiés, fichier tronqué : refusés', () async {
      await store.write('doc1', dek, pdfBytes());
      final file = docFile(dir, 'doc1');
      final original = file.readAsBytesSync();
      for (final change in <Uint8List Function(Uint8List)>[
        (b) => b..[b.length - 1] ^= 0x80, // tag
        (b) => b..[6] ^= 0x01, // nonce
        (b) => b..[0] = 0x58, // « XDOC »
        (b) => b..[4] = 9, // version inconnue
        (b) => Uint8List.sublistView(b, 0, 20), // tronqué
      ]) {
        file.writeAsBytesSync(change(Uint8List.fromList(original)));
        expect(
          store.read('doc1', dek),
          throwsA(isA<VaultCorruptedException>()),
        );
      }
    });

    test(
      'fichier échangé avec un autre document (AAD = id) : refusé',
      () async {
        await store.write('doc1', dek, pdfBytes('un'));
        await store.write('doc2', dek, pdfBytes('deux'));
        docFile(
          dir,
          'doc2',
        ).writeAsBytesSync(docFile(dir, 'doc1').readAsBytesSync());
        expect(
          store.read('doc2', dek),
          throwsA(isA<VaultCorruptedException>()),
        );
      },
    );

    test('mauvaise clé ou fichier absent : refusés', () async {
      await store.write('doc1', dek, pdfBytes());
      final other = Uint8List(32);
      expect(
        store.read('doc1', other),
        throwsA(isA<VaultCorruptedException>()),
      );
      expect(
        store.read('absent', dek),
        throwsA(isA<VaultCorruptedException>()),
      );
    });

    test('id dangereux (chemin) : refusé', () {
      for (final id in ['../vault', 'a/b', r'a\b', '', '..', 'x' * 65]) {
        expect(isSafeDocumentId(id), isFalse, reason: id);
        expect(store.write(id, dek, pdfBytes()), throwsArgumentError);
      }
    });
  });

  group('session', () {
    test('ajouter puis relire, seulement coffre ouvert', () async {
      final session = await openedSession();
      final content = pdfBytes();
      await session.addDocument(documentItem('d1', content), content);
      expect(session.items.single.type, VaultItemType.document);
      expect(session.items.single.mime, 'application/pdf');
      expect(await session.readDocument('d1'), content);

      session.lock();
      expect(() => session.readDocument('d1'), throwsStateError);
      expectNoClearFile(dir);

      // Rouvert depuis le disque : métadonnées et contenu retrouvés.
      final again = newSession();
      await again.load();
      expect(await again.unlock(masterPassword), UnlockResult.ouvert);
      expect(again.items.single.taille, content.length);
      expect(await again.readDocument('d1'), content);
      again.dispose();
      session.dispose();
    });

    test('trop gros ou type refusé : rien n\'est écrit', () async {
      final session = await openedSession();
      final big = Uint8List(maxDocumentBytes + 1)
        ..setAll(0, utf8.encode('%PDF-'));
      expect(
        session.addDocument(documentItem('big', pdfBytes()), big),
        throwsA(isA<DocumentTooLargeException>()),
      );
      final exe = utf8.encode('MZ programme');
      expect(
        session.addDocument(documentItem('exe', pdfBytes()), exe),
        throwsA(isA<UnsupportedDocumentException>()),
      );
      await pumpEventQueue();
      expect(session.items, isEmpty);
      expect(docFile(dir, 'big').existsSync(), isFalse);
      expect(docFile(dir, 'exe').existsSync(), isFalse);
      session.dispose();
    });

    test('supprimer un document efface son fichier chiffré', () async {
      final session = await openedSession();
      final content = jpegBytes();
      await session.addDocument(documentItem('d1', content), content);
      expect(docFile(dir, 'd1').existsSync(), isTrue);
      await session.delete('d1');
      expect(session.items, isEmpty);
      expect(docFile(dir, 'd1').existsSync(), isFalse);
      session.dispose();
    });

    test('renommer garde le fichier', () async {
      final session = await openedSession();
      final content = pdfBytes();
      await session.addDocument(documentItem('d1', content), content);
      await session.save(session.items.single.copyWith(titre: 'Passeport'));
      expect(session.items.single.titre, 'Passeport');
      expect(await session.readDocument('d1'), content);
      session.dispose();
    });

    test(
      'fichier orphelin (suppression interrompue) : effacé à l\'ouverture',
      () async {
        final session = await openedSession();
        final content = pdfBytes();
        await session.addDocument(documentItem('d1', content), content);
        // Un fichier qu'aucun élément ne référence plus.
        final orphan = docFile(dir, 'orphelin')..writeAsBytesSync([1, 2, 3]);
        session.lock();
        expect(await session.unlock(masterPassword), UnlockResult.ouvert);
        expect(orphan.existsSync(), isFalse);
        expect(docFile(dir, 'd1').existsSync(), isTrue);
        session.dispose();
      },
    );

    test('supprimer le coffre efface tous les documents', () async {
      final session = await openedSession();
      final content = pdfBytes();
      await session.addDocument(documentItem('d1', content), content);
      await session.deleteVault();
      expect(
        Directory(
          '${dir.path}${Platform.pathSeparator}${VaultDocumentStore.folderName}',
        ).existsSync(),
        isFalse,
      );
      session.dispose();
    });

    test('fichier altéré sur le disque : lecture refusée', () async {
      final session = await openedSession();
      final content = pdfBytes();
      await session.addDocument(documentItem('d1', content), content);
      final file = docFile(dir, 'd1');
      final bytes = file.readAsBytesSync();
      bytes[30] ^= 0xFF;
      file.writeAsBytesSync(bytes);
      expect(
        session.readDocument('d1'),
        throwsA(isA<VaultCorruptedException>()),
      );
      session.dispose();
    });
  });

  group('sauvegarde .sentinel', () {
    final note = VaultItem(
      id: 'n1',
      type: VaultItemType.note,
      titre: 'Codes',
      note: '1234',
      creeLe: DateTime.utc(2026, 1, 1),
      modifieLe: DateTime.utc(2026, 1, 1),
    );

    test(
      'export v2 : documents inclus, chiffrés, relus à l\'identique',
      () async {
        final pdf = pdfBytes();
        final jpeg = jpegBytes();
        final items = [note, documentItem('d1', pdf), documentItem('d2', jpeg)];
        final backup = await exportBackup(
          items,
          exportPassword,
          kdf: fastKdf(),
          documents: {'d1': pdf, 'd2': jpeg},
        );
        final json = asJson(backup);
        expect(json['version'], 2);
        expect((json['documents'] as List).length, 2);
        expect(containsBytes(backup, utf8.encode(marker)), isFalse);

        final contents = await importBackup(backup, exportPassword);
        expect(contents.items.length, 3);
        expect(contents.documents['d1'], pdf);
        expect(contents.documents['d2'], jpeg);
      },
    );

    test('document altéré ou manquant dans la sauvegarde : refusée', () async {
      final pdf = pdfBytes();
      final backup = await exportBackup(
        [documentItem('d1', pdf)],
        exportPassword,
        kdf: fastKdf(),
        documents: {'d1': pdf},
      );

      final altered = asJson(backup);
      final doc = (altered['documents'] as List).single as Map<String, Object?>;
      final cipher = base64.decode(doc['chiffre'] as String);
      cipher[3] ^= 0x01;
      doc['chiffre'] = base64.encode(cipher);
      expect(
        importBackup(fromJson(altered), exportPassword),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.problem,
            'problem',
            BackupProblem.illisible,
          ),
        ),
      );

      final missing = asJson(backup)..['documents'] = <Object>[];
      expect(
        importBackup(fromJson(missing), exportPassword),
        throwsA(isA<BackupFormatException>()),
      );

      // Contenu d'un document attribué à un autre id : refusé (AAD).
      final swapped = asJson(backup);
      ((swapped['documents'] as List).single as Map)['id'] = 'autre';
      expect(
        importBackup(fromJson(swapped), exportPassword),
        throwsA(isA<BackupFormatException>()),
      );

      // id dangereux : refusé dès la lecture du fichier.
      final traversal = asJson(backup);
      ((traversal['documents'] as List).single as Map)['id'] = '../vault';
      expect(
        () => VaultBackup.decode(fromJson(traversal)),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('ancien export (version 1, sans documents) : toujours lu', () async {
      final v1 = await legacyV1Backup([note], exportPassword);
      expect(asJson(v1)['version'], 1);
      expect(asJson(v1).containsKey('documents'), isFalse);
      final contents = await importBackup(v1, exportPassword);
      expect(contents.items.single.toJson(), note.toJson());
      expect(contents.documents, isEmpty);
    });

    test('exporter, restaurer sur un autre téléphone : documents lisibles, '
        'aucun fichier en clair', () async {
      final session = await openedSession();
      final pdf = pdfBytes();
      await session.save(note);
      await session.addDocument(documentItem('d1', pdf), pdf);
      final backup = await session.createBackup(exportPassword);
      session.dispose();

      // « Nouveau téléphone » : dossier vide.
      final other = Directory.systemTemp.createTempSync('documents_autre');
      addTearDown(() => other.deleteSync(recursive: true));
      VaultSession otherSession() => VaultSession(
        storage: VaultStorage(directory: () async => other),
        biometrics: FakeBiometrics(),
        kdfForNewVault: fastKdf,
      );
      final restored = otherSession();
      await restored.load();
      final contents = await restored.readBackup(backup, exportPassword);
      await restored.restore(
        contents.items,
        masterPassword,
        documents: contents.documents,
      );
      contents.wipeDocuments();
      expect(await restored.readDocument('d1'), pdf);
      restored.dispose();

      // Rouvert depuis le disque : rechiffré avec la NOUVELLE DEK.
      final reopened = otherSession();
      await reopened.load();
      expect(await reopened.unlock(masterPassword), UnlockResult.ouvert);
      expect(reopened.items.length, 2);
      expect(await reopened.readDocument('d1'), pdf);
      reopened.dispose();

      expectNoClearFile(dir);
      expectNoClearFile(other);
    });
  });
}

/// Une sauvegarde au format de la version 1 (avant les documents), comme
/// l'écrivaient les anciennes versions de Sentinel.
Future<Uint8List> legacyV1Backup(List<VaultItem> items, String password) async {
  final kdf = fastKdf();
  final empty = VaultBackup(
    version: 1,
    kdf: kdf,
    data: EncryptedBlob(nonce: Uint8List(0), cipherText: Uint8List(0)),
  );
  final key = await deriveKek(password, kdf);
  final aes = AesGcm.with256bits(nonceLength: EncryptedBlob.nonceLength);
  final nonce = aes.newNonce();
  final box = await aes.encrypt(
    utf8.encode(jsonEncode([for (final item in items) item.toJson()])),
    secretKey: SecretKeyData(key),
    nonce: nonce,
    aad: empty.header,
  );
  return empty
      .withData(
        EncryptedBlob(
          nonce: Uint8List.fromList(nonce),
          cipherText: box.concatenation(nonce: false),
        ),
      )
      .encode();
}
