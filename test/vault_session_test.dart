import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/vault/vault_biometrics.dart';
import 'package:sentinel/services/vault/vault_crypto.dart';
import 'package:sentinel/services/vault/vault_file.dart';
import 'package:sentinel/services/vault/vault_item.dart';
import 'package:sentinel/services/vault/vault_session.dart';
import 'package:sentinel/services/vault/vault_storage.dart';

import 'support/fake_biometrics.dart';

const password = 'cheval correct batterie';
const newPassword = 'Une autre phrase bien plus longue 42';

void main() {
  late Directory dir;
  late DateTime now;
  late FakeBiometrics biometrics;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('coffre_test');
    now = DateTime(2026, 10, 15, 12);
    biometrics = FakeBiometrics();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  VaultSession newSession() => VaultSession(
    storage: VaultStorage(directory: () async => dir),
    biometrics: biometrics,
    kdfForNewVault: () => newKdfParams(memoryKib: 64, iterations: 2),
    clock: () => now,
  );

  VaultFile onDisk() =>
      VaultFile.decode(File('${dir.path}/vault.json').readAsStringSync());

  Future<VaultSession> openedVault() async {
    final session = newSession();
    await session.load();
    await session.create(password);
    session.recoveryKeyNoted();
    return session;
  }

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

    await session.create(password);
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
    expect(await again.unlock(password), UnlockResult.ouvert);
    expect(again.items.map((i) => i.motDePasse), ['secret-1', 'secret-2']);

    await again.delete('1');
    expect(again.items.map((i) => i.id), ['2']);
  });

  test("échecs : attente imposée, puis l'ouverture refonctionne", () async {
    final session = newSession();
    await session.load();
    await session.create(password);
    session.lock();

    expect(await session.unlock('faux'), UnlockResult.incorrect);
    expect(session.remainingWait, const Duration(seconds: 1));
    // Pendant l'attente, même le bon mot de passe est refusé.
    expect(await session.unlock(password), UnlockResult.attendre);

    now = now.add(const Duration(seconds: 1));
    expect(await session.unlock('faux'), UnlockResult.incorrect);
    expect(session.remainingWait, const Duration(seconds: 2));

    now = now.add(const Duration(seconds: 2));
    expect(await session.unlock(password), UnlockResult.ouvert);
    expect(session.remainingWait, Duration.zero);
  });

  test('écriture atomique : pas de fichier temporaire restant', () async {
    final session = newSession();
    await session.load();
    await session.create(password);
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

  test('création : clé de récupération montrée une fois', () async {
    final session = newSession();
    await session.load();
    await session.create(password);
    final key = session.pendingRecoveryKey;
    expect(key, isNotNull);
    expect(onDisk().recoverySlot, isNotNull);
    session.recoveryKeyNoted();
    expect(session.pendingRecoveryKey, isNull);

    // Verrouiller oublie aussi une clé pas encore notée.
    await session.createRecoveryKey();
    expect(session.pendingRecoveryKey, isNotNull);
    session.lock();
    expect(session.pendingRecoveryKey, isNull);
  });

  test('migration v1 → v2 sur disque, puis clé proposée', () async {
    File('test/fixtures/vault_v1.json').copySync('${dir.path}/vault.json');
    final session = newSession();
    await session.load();
    expect(session.status, VaultStatus.verrouille);
    expect(session.hasRecoveryKey, isFalse);

    expect(
      await session.unlock('cheval correct batterie agrafe'),
      UnlockResult.ouvert,
    );
    expect(session.items.map((i) => i.titre), ['Banque', 'Wi-Fi maison']);
    // Écrit en v2, de façon atomique (pas de fichier temporaire).
    expect(onDisk().version, 2);
    expect(dir.listSync().map((f) => f.uri.pathSegments.last), ['vault.json']);
    expect(session.offerRecoveryKey, isTrue);

    await session.createRecoveryKey();
    final key = session.pendingRecoveryKey!;
    expect(session.offerRecoveryKey, isFalse);
    session.recoveryKeyNoted();
    session.lock();

    // Relancement : la clé ouvre bien le coffre migré.
    final again = newSession();
    await again.load();
    expect(again.hasRecoveryKey, isTrue);
    expect(await again.recoveryKeyMatches(key), isTrue);
    expect(
      await again.unlock('cheval correct batterie agrafe'),
      UnlockResult.ouvert,
    );
    expect(again.offerRecoveryKey, isFalse); // proposée une seule fois
  });

  test('mot de passe oublié : nouvelle clé, ancienne refusée', () async {
    final session = newSession();
    await session.load();
    await session.create(password);
    final oldKey = session.pendingRecoveryKey!;
    session.recoveryKeyNoted();
    await session.save(item('1', 'Banque'));
    session.lock();

    expect(await session.recoveryKeyMatches('AAAA-BBBB'), isFalse);
    expect(await session.recover('mauvaise clé', newPassword), isFalse);
    expect(session.status, VaultStatus.verrouille);

    expect(await session.recover(oldKey.toLowerCase(), newPassword), isTrue);
    expect(session.status, VaultStatus.ouvert);
    expect(session.items.map((i) => i.titre), ['Banque']);
    final newKey = session.pendingRecoveryKey!;
    expect(newKey, isNot(oldKey));
    session.recoveryKeyNoted();
    session.lock();

    expect(await session.recoveryKeyMatches(oldKey), isFalse);
    expect(await session.recoveryKeyMatches(newKey), isTrue);
    expect(await session.unlock(password), UnlockResult.incorrect);
    now = now.add(const Duration(minutes: 1));
    expect(await session.unlock(newPassword), UnlockResult.ouvert);
  });

  test('changer le mot de passe maître', () async {
    final session = await openedVault();
    await session.save(item('1', 'Banque'));
    expect(await session.changeMasterPassword('faux', newPassword), isFalse);
    expect(await session.changeMasterPassword(password, newPassword), isTrue);
    session.lock();

    final again = newSession();
    await again.load();
    expect(await again.unlock(password), UnlockResult.incorrect);
    now = now.add(const Duration(minutes: 1));
    expect(await again.unlock(newPassword), UnlockResult.ouvert);
    expect(again.items.map((i) => i.motDePasse), ['secret-1']);
  });

  test('empreinte : activer, ouvrir, règle des 7 jours', () async {
    final session = await openedVault();
    await session.save(item('1', 'Banque'));
    await session.setBiometricEnabled(true);
    expect(session.biometricEnabled, isTrue);
    expect(onDisk().biometricSlot, isNotNull);
    session.lock();

    // Relancement : l'empreinte est proposée et ouvre le coffre.
    final again = newSession();
    await again.load();
    expect(again.canUnlockWithBiometrics, isTrue);
    expect(await again.unlockWithBiometrics(), BiometricUnlockResult.ouvert);
    expect(again.items.map((i) => i.titre), ['Banque']);
    again.lock();

    // Annulation : rien ne change, le mot de passe reste possible.
    biometrics.nextError = BiometricError.annulee;
    expect(await again.unlockWithBiometrics(), BiometricUnlockResult.annule);
    expect(again.status, VaultStatus.verrouille);

    // 8 jours sans mot de passe : l'empreinte ne suffit plus.
    now = now.add(const Duration(days: 8));
    expect(again.canUnlockWithBiometrics, isFalse);
    expect(again.biometricNeedsPassword, isTrue);
    final promptsBefore = biometrics.prompts;
    expect(
      await again.unlockWithBiometrics(),
      BiometricUnlockResult.motDePasseExige,
    );
    expect(biometrics.prompts, promptsBefore); // pas de fenêtre affichée

    // Le mot de passe remet le compteur à zéro.
    expect(await again.unlock(password), UnlockResult.ouvert);
    again.lock();
    expect(again.canUnlockWithBiometrics, isTrue);
    expect(await again.unlockWithBiometrics(), BiometricUnlockResult.ouvert);
  });

  test(
    'empreinte invalidée : emplacement retiré après le mot de passe',
    () async {
      final session = await openedVault();
      await session.setBiometricEnabled(true);
      session.lock();

      biometrics.invalidate(); // nouvelle empreinte ajoutée au téléphone
      expect(
        await session.unlockWithBiometrics(),
        BiometricUnlockResult.empreintesChangees,
      );
      expect(session.biometricBroken, isTrue);
      expect(session.canUnlockWithBiometrics, isFalse);
      expect(onDisk().biometricSlot, isNotNull); // pas de DEK : pas encore

      expect(await session.unlock(password), UnlockResult.ouvert);
      expect(onDisk().biometricSlot, isNull);
      expect(session.biometricBroken, isFalse);
      expect(session.biometricEnabled, isFalse);

      // Réactivation possible.
      await session.setBiometricEnabled(true);
      session.lock();
      expect(
        await session.unlockWithBiometrics(),
        BiometricUnlockResult.ouvert,
      );
    },
  );

  test('empreinte désactivée : emplacement et clé supprimés', () async {
    final session = await openedVault();
    await session.setBiometricEnabled(true);
    expect(biometrics.hasKey, isTrue);
    await session.setBiometricEnabled(false);
    expect(onDisk().biometricSlot, isNull);
    expect(biometrics.hasKey, isFalse);
  });

  test('sans capteur (Windows) : empreinte jamais proposée', () async {
    biometrics.available = false;
    final session = await openedVault();
    expect(session.biometricsAvailable, isFalse);
    session.lock();
    expect(session.canUnlockWithBiometrics, isFalse);
    expect(
      await session.unlockWithBiometrics(),
      BiometricUnlockResult.indisponible,
    );
  });

  test('supprimer le coffre : fichier et clé effacés', () async {
    final session = await openedVault();
    await session.setBiometricEnabled(true);
    await session.deleteVault();
    expect(session.status, VaultStatus.absent);
    expect(dir.listSync(), isEmpty);
    expect(biometrics.hasKey, isFalse);

    final again = newSession();
    await again.load();
    expect(again.status, VaultStatus.absent);
  });
}
