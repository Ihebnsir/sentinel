import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';

import 'recovery_key.dart';
import 'vault_file.dart';
import 'vault_item.dart';

/// Mauvais mot de passe (ou en-tête modifié : impossible de distinguer).
class WrongPasswordException implements Exception {
  const WrongPasswordException();

  @override
  String toString() => 'Mot de passe incorrect';
}

/// Clé de récupération fausse, mal tapée, ou coffre sans clé.
class WrongRecoveryKeyException implements Exception {
  const WrongRecoveryKeyException();

  @override
  String toString() => 'Clé de récupération incorrecte';
}

/// La clé est bonne mais les données ont été modifiées ou abîmées.
class VaultCorruptedException implements Exception {
  const VaultCorruptedException();

  @override
  String toString() => 'Coffre endommagé';
}

/// Paramètres Argon2id par défaut : 46 Mio, 2 passes, 1 fil.
/// Au-dessus du minimum OWASP (19 Mio, 2 passes) sur les deux axes.
/// Mesuré sur PC : ~0,3 s ; un téléphone moyen est 2 à 3 fois plus lent.
const defaultMemoryKib = 46 * 1024;
const defaultIterations = 2;
const defaultParallelism = 1;

const _keyLength = 32; // 256 bits

// AES-256-GCM avec nonce de 12 octets (taille recommandée pour GCM).
final _aesGcm = AesGcm.with256bits(nonceLength: EncryptedBlob.nonceLength);

// HKDF-SHA256 pour la clé de récupération. L'« info » sépare cet usage
// de tout autre usage de la même entrée.
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: _keyLength);
final _recoveryInfo = utf8.encode('Sentinel coffre : clé de récupération');

final _random = Random.secure();

Uint8List _randomBytes(int length) =>
    Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

/// Paramètres neufs avec un sel aléatoire de 16 octets.
KdfParams newKdfParams({
  int memoryKib = defaultMemoryKib,
  int iterations = defaultIterations,
  int parallelism = defaultParallelism,
}) {
  return KdfParams(
    memoryKib: memoryKib,
    iterations: iterations,
    parallelism: parallelism,
    salt: _randomBytes(KdfParams.saltLength),
  );
}

/// Argon2id dans un isolate séparé : l'écran ne se fige pas pendant
/// le calcul (volontairement lent). Renvoie la KEK (32 octets).
Future<Uint8List> deriveKek(String password, KdfParams kdf) async {
  final stopwatch = Stopwatch()..start();
  final memoryKib = kdf.memoryKib;
  final iterations = kdf.iterations;
  final parallelism = kdf.parallelism;
  final salt = kdf.salt;
  final kek = await Isolate.run(() async {
    final argon2id = DartArgon2id(
      memory: memoryKib,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: _keyLength,
    );
    final key = await argon2id.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  });
  // Seulement la durée, jamais le mot de passe ni la clé.
  if (kDebugMode) {
    debugPrint('Argon2id : ${stopwatch.elapsedMilliseconds} ms');
  }
  return kek;
}

/// KEK de la clé de récupération : HKDF-SHA256, instantané.
/// [normalizedKey] est la clé sans tirets (voir [RecoveryKey.normalize]).
Future<Uint8List> deriveRecoveryKek(
  String normalizedKey,
  Uint8List salt,
) async {
  final key = await _hkdf.deriveKey(
    secretKey: SecretKey(utf8.encode(normalizedKey)),
    nonce: salt,
    info: _recoveryInfo,
  );
  return Uint8List.fromList(await key.extractBytes());
}

Future<EncryptedBlob> _encrypt(
  List<int> clearText,
  Uint8List key,
  Uint8List aad,
) async {
  // Nonce neuf et aléatoire à CHAQUE chiffrement.
  final nonce = _aesGcm.newNonce();
  final box = await _aesGcm.encrypt(
    clearText,
    secretKey: SecretKeyData(key),
    nonce: nonce,
    aad: aad,
  );
  return EncryptedBlob(
    nonce: Uint8List.fromList(nonce),
    cipherText: box.concatenation(nonce: false),
  );
}

/// Lève [SecretBoxAuthenticationError] si le tag ne correspond pas.
Future<Uint8List> _decrypt(
  EncryptedBlob blob,
  Uint8List key,
  Uint8List aad,
) async {
  final box = SecretBox.fromConcatenation(
    [...blob.nonce, ...blob.cipherText],
    nonceLength: EncryptedBlob.nonceLength,
    macLength: EncryptedBlob.tagLength,
  );
  final clear = await _aesGcm.decrypt(
    box,
    secretKey: SecretKeyData(key),
    aad: aad,
  );
  return Uint8List.fromList(clear);
}

/// Date enregistrée : UTC, à la seconde (l'en-tête se relit à l'identique).
DateTime _stamp(DateTime now) => DateTime.fromMillisecondsSinceEpoch(
  now.millisecondsSinceEpoch ~/ 1000 * 1000,
  isUtc: true,
);

// ---------------------------------------------------------------------
// Emplacements de clé
// ---------------------------------------------------------------------

/// Emplacement « password » : la DEK enveloppée par Argon2id(mot de passe).
Future<PasswordSlot> newPasswordSlot(
  String password,
  Uint8List dek, {
  KdfParams? kdf,
}) async {
  final params = kdf ?? newKdfParams();
  final kek = await deriveKek(password, params);
  try {
    return PasswordSlot(
      kdf: params,
      wrappedKey: await _encrypt(
        dek,
        kek,
        KeySlot.aadFor(PasswordSlot.paramsFor(params)),
      ),
    );
  } finally {
    wipe(kek);
  }
}

/// Emplacement « recovery » et sa clé (mise en forme, à montrer une fois).
Future<(RecoverySlot, String)> newRecoverySlot(Uint8List dek) async {
  final key = RecoveryKey.generate();
  final salt = _randomBytes(RecoverySlot.saltLength);
  final kek = await deriveRecoveryKek(RecoveryKey.normalize(key)!, salt);
  try {
    final slot = RecoverySlot(
      salt: salt,
      wrappedKey: await _encrypt(
        dek,
        kek,
        KeySlot.aadFor(RecoverySlot.paramsFor(salt)),
      ),
    );
    return (slot, key);
  } finally {
    wipe(kek);
  }
}

/// Un coffre neuf : sa DEK et sa clé de récupération (à montrer une fois).
class NewVault {
  NewVault(this.file, this.dek, this.recoveryKey);

  final VaultFile file;
  final Uint8List dek;
  final String recoveryKey;
}

/// Crée un coffre : DEK aléatoire, enveloppée deux fois (mot de passe et
/// clé de récupération), puis la liste (vide au départ) chiffrée par la DEK.
Future<NewVault> createVault(
  String password, {
  List<VaultItem> items = const [],
  KdfParams? kdf,
  DateTime? now,
}) async {
  final dek = _randomBytes(_keyLength);
  final passwordSlot = await newPasswordSlot(password, dek, kdf: kdf);
  final (recoverySlot, key) = await newRecoverySlot(dek);
  final file = VaultFile(
    slots: [passwordSlot, recoverySlot],
    lastPasswordUnlock: _stamp(now ?? DateTime.now()),
    data: EncryptedBlob(nonce: Uint8List(0), cipherText: Uint8List(0)),
  );
  return NewVault(await sealItems(dek, file, items), dek, key);
}

// Retrouve la DEK et garde la KEK (utile pour migrer sans refaire Argon2).
Future<(Uint8List, Uint8List)> _unwrapPassword(
  String password,
  VaultFile file,
) async {
  final slot = file.passwordSlot;
  final kek = await deriveKek(password, slot.kdf);
  try {
    final dek = await _decrypt(slot.wrappedKey, kek, file.aadOf(slot));
    return (dek, kek);
  } on SecretBoxAuthenticationError {
    wipe(kek);
    throw const WrongPasswordException();
  }
}

/// Retrouve la DEK. Lève [WrongPasswordException] si le mot de passe
/// est faux (ou si les paramètres de l'emplacement ont été modifiés).
Future<Uint8List> unwrapKey(String password, VaultFile file) async {
  final (dek, kek) = await _unwrapPassword(password, file);
  wipe(kek);
  return dek;
}

/// Retrouve la DEK avec la clé de récupération (saisie tolérante).
Future<Uint8List> unwrapWithRecoveryKey(String input, VaultFile file) async {
  final normalized = RecoveryKey.normalize(input);
  final slot = file.recoverySlot;
  if (normalized == null || slot == null) {
    throw const WrongRecoveryKeyException();
  }
  final kek = await deriveRecoveryKek(normalized, slot.salt);
  try {
    return await _decrypt(slot.wrappedKey, kek, file.aadOf(slot));
  } on SecretBoxAuthenticationError {
    throw const WrongRecoveryKeyException();
  } finally {
    wipe(kek);
  }
}

/// Résultat d'une ouverture par mot de passe.
class PasswordOpening {
  PasswordOpening(this.file, this.dek, this.items, {required this.migrated});

  /// Fichier à réécrire : date mise à jour, migré en v2 si besoin.
  final VaultFile file;
  final Uint8List dek;
  final List<VaultItem> items;

  /// true si le coffre était en version 1.
  final bool migrated;
}

/// Ouvre avec le mot de passe, note la date, et migre un coffre v1 en v2.
/// Avec [dropBiometric], retire l'emplacement « empreinte » devenu inutile.
Future<PasswordOpening> openWithPassword(
  String password,
  VaultFile file, {
  DateTime? now,
  bool dropBiometric = false,
}) async {
  final (dek, kek) = await _unwrapPassword(password, file);
  try {
    final items = await openItems(dek, file);
    var next = file.copyWith(lastPasswordUnlock: _stamp(now ?? DateTime.now()));
    if (file.version == 1) {
      // Même KEK (même sel) : on ré-enveloppe la DEK avec l'AAD v2.
      final kdf = file.passwordSlot.kdf;
      next = next.copyWith(
        slots: [
          PasswordSlot(
            kdf: kdf,
            wrappedKey: await _encrypt(
              dek,
              kek,
              KeySlot.aadFor(PasswordSlot.paramsFor(kdf)),
            ),
          ),
        ],
      );
    }
    if (dropBiometric) next = next.withoutBiometricSlot();
    return PasswordOpening(
      await sealItems(dek, next, items),
      dek,
      items,
      migrated: file.version == 1,
    );
  } catch (_) {
    wipe(dek);
    rethrow;
  } finally {
    wipe(kek);
  }
}

/// Change le mot de passe : vérifie l'ancien, nouveau sel, seul
/// l'emplacement « password » change. La DEK reste la même.
Future<VaultFile> changePassword(
  String oldPassword,
  String newPassword,
  VaultFile file,
  Uint8List dek, {
  KdfParams? kdf,
  DateTime? now,
}) async {
  final check = await unwrapKey(oldPassword, file);
  final same = listEquals(check, dek);
  wipe(check);
  if (!same) throw const WrongPasswordException();
  final slot = await newPasswordSlot(newPassword, dek, kdf: kdf);
  final next = file
      .withSlot(slot)
      .copyWith(lastPasswordUnlock: _stamp(now ?? DateTime.now()));
  return reseal(dek, file, next);
}

/// Nouvelle clé de récupération : l'ancienne ne fonctionne plus.
Future<(VaultFile, String)> replaceRecoveryKey(
  Uint8List dek,
  VaultFile file,
) async {
  final (slot, key) = await newRecoverySlot(dek);
  return (await reseal(dek, file, file.withSlot(slot)), key);
}

/// Résultat de « Mot de passe oublié ».
class RecoveryReset {
  RecoveryReset(this.file, this.dek, this.items, this.recoveryKey);

  final VaultFile file;
  final Uint8List dek;
  final List<VaultItem> items;
  final String recoveryKey; // la NOUVELLE clé, à montrer une fois
}

/// Ouvre avec la clé de récupération, remplace le mot de passe et la clé
/// de récupération (l'ancienne ne marche plus).
Future<RecoveryReset> resetWithRecoveryKey(
  String recoveryInput,
  String newPassword,
  VaultFile file, {
  KdfParams? kdf,
  DateTime? now,
}) async {
  final dek = await unwrapWithRecoveryKey(recoveryInput, file);
  try {
    final items = await openItems(dek, file);
    final passwordSlot = await newPasswordSlot(newPassword, dek, kdf: kdf);
    final (recoverySlot, key) = await newRecoverySlot(dek);
    final next = file
        .withSlot(passwordSlot)
        .withSlot(recoverySlot)
        .copyWith(lastPasswordUnlock: _stamp(now ?? DateTime.now()));
    return RecoveryReset(await sealItems(dek, next, items), dek, items, key);
  } catch (_) {
    wipe(dek);
    rethrow;
  }
}

/// Les emplacements ont changé : l'en-tête (AAD) aussi, donc on
/// déchiffre les données avec l'ancien et on les rechiffre avec le neuf.
Future<VaultFile> reseal(Uint8List dek, VaultFile from, VaultFile to) async {
  final Uint8List clear;
  try {
    clear = await _decrypt(from.data, dek, from.header);
  } on SecretBoxAuthenticationError {
    throw const VaultCorruptedException();
  }
  try {
    return to.withData(await _encrypt(clear, dek, to.header));
  } finally {
    wipe(clear);
  }
}

/// Rechiffre la liste avec la DEK (nouveau nonce) : rapide, sans Argon2.
Future<VaultFile> sealItems(
  Uint8List dek,
  VaultFile file,
  List<VaultItem> items,
) async {
  final clear = _encodeItems(items);
  try {
    return file.withData(await _encrypt(clear, dek, file.header));
  } finally {
    wipe(clear);
  }
}

/// Déchiffre la liste. Lève [VaultCorruptedException] si le chiffré
/// ou l'en-tête (emplacements, date…) a été modifié.
Future<List<VaultItem>> openItems(Uint8List dek, VaultFile file) async {
  final Uint8List clear;
  try {
    clear = await _decrypt(file.data, dek, file.header);
  } on SecretBoxAuthenticationError {
    throw const VaultCorruptedException();
  }
  try {
    final json = jsonDecode(utf8.decode(clear)) as List<Object?>;
    return [
      for (final item in json) VaultItem.fromJson(item as Map<String, Object?>),
    ];
  } on FormatException {
    throw const VaultCorruptedException();
  } finally {
    wipe(clear);
  }
}

Uint8List _encodeItems(List<VaultItem> items) =>
    utf8.encode(jsonEncode([for (final item in items) item.toJson()]));

/// Remplit de zéros un tableau d'octets secret. Limite de Dart : les
/// copies faites ailleurs (Strings, isolates, ramasse-miettes) ne sont
/// pas effacées ; on réduit la durée de vie des clés, sans garantie.
void wipe(Uint8List bytes) => bytes.fillRange(0, bytes.length, 0);
