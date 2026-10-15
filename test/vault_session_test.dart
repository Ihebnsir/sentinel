import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/vault/vault_crypto.dart';
import 'package:sentinel/services/vault/vault_item.dart';
import 'package:sentinel/services/vault/vault_session.dart';
import 'package:sentinel/services/vault/vault_storage.dart';

void main() {
  late Directory dir;
  late DateTime now;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('coffre_test');
    now = DateTime(2026, 10, 15, 12);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  VaultSession newSession() => VaultSession(
    storage: VaultStorage(directory: () async => dir),
    kdfForNewVault: () => newKdfParams(memoryKib: 64, iterations: 2),
    clock: () => now,
  );

  VaultItem item(String id, String titre) => VaultItem(
    id: id,
    type: VaultItemType.motDePasse,
    titre: titre,
    motDePasse: 'secret-$id',
    creeLe: now,
    modifieLe: now,
  );

  test('délais croissants : 1, 2, 4, 8, 16 puis 30 s', () {
    expect(
      [
        for (var n = 1; n <= 8; n++)
          VaultSession.delayAfterFailures(n).inSeconds,
      ],
      [1, 2, 4, 8, 16, 30, 30, 30],
    );
  });

  test('créer, verrouiller, rouvrir : les éléments sont retrouvés', () async {
    final session = newSession();
    await session.load();
    expect(session.status, VaultStatus.absent);

    await session.create('cheval correct batterie');
    expect(session.status, VaultStatus.ouvert);
    await session.save(item('2', 'Zèbre'));
    await session.save(item('1', 'abeille'));
    expect(session.items.map((i) => i.titre), ['abeille', 'Zèbre']);

    session.lock();
    expect(session.status, VaultStatus.verrouille);
    expect(session.items, isEmpty);

    // Nouvelle session = relancement de l'app.
    final again = newSession();
    await again.load();
    expect(again.status, VaultStatus.verrouille);
    expect(await again.unlock('cheval correct batterie'), UnlockResult.ouvert);
    expect(again.items.map((i) => i.motDePasse), ['secret-1', 'secret-2']);

    await again.delete('1');
    expect(again.items.map((i) => i.id), ['2']);
  });

  test("échecs : attente imposée, puis l'ouverture refonctionne", () async {
    final session = newSession();
    await session.load();
    await session.create('cheval correct batterie');
    session.lock();

    expect(await session.unlock('faux'), UnlockResult.incorrect);
    expect(session.remainingWait, const Duration(seconds: 1));
    // Pendant l'attente, même le bon mot de passe est refusé.
    expect(
      await session.unlock('cheval correct batterie'),
      UnlockResult.attendre,
    );

    now = now.add(const Duration(seconds: 1));
    expect(await session.unlock('faux'), UnlockResult.incorrect);
    expect(session.remainingWait, const Duration(seconds: 2));

    now = now.add(const Duration(seconds: 2));
    expect(
      await session.unlock('cheval correct batterie'),
      UnlockResult.ouvert,
    );
    expect(session.remainingWait, Duration.zero);
  });

  test('écriture atomique : pas de fichier temporaire restant', () async {
    final session = newSession();
    await session.load();
    await session.create('cheval correct batterie');
    await session.save(item('1', 'Banque'));
    final names = dir.listSync().map((f) => f.uri.pathSegments.last);
    expect(names, ['vault.json']);
  });

  test('fichier abîmé : état « illisible », sans plantage', () async {
    File('${dir.path}/vault.json').writeAsStringSync('{ abîmé');
    final session = newSession();
    await session.load();
    expect(session.status, VaultStatus.illisible);
  });
}
