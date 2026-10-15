import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';

import 'vault_file.dart';
import 'vault_item.dart';

/// Mauvais mot de passe (ou en-tête modifié : impossible de distinguer).
class WrongPasswordException implements Exception {
  const WrongPasswordException();

  @override
  String toString() => 'Mot de passe incorrect';
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

/// Un coffre ouvert : le fichier et la DEK en clair (en mémoire seulement).
class OpenedVault {
  OpenedVault(this.file, this.dek);

  final VaultFile file;
  final Uint8List dek;
}

/// Crée un coffre : DEK aléatoire, enveloppée par la KEK dérivée du mot
/// de passe, puis la liste (vide au départ) chiffrée par la DEK.
Future<OpenedVault> createVault(
  String password, {
  List<VaultItem> items = const [],
  KdfParams? kdf,
}) async {
  final params = kdf ?? newKdfParams();
  final header = VaultFile.headerBytes(VaultFile.currentVersion, params);
  final dek = _randomBytes(_keyLength);
  final kek = await deriveKek(password, params);
  try {
    final wrapped = await _encrypt(dek, kek, header);
    final data = await _encrypt(_encodeItems(items), dek, header);
    final file = VaultFile(kdf: params, wrappedKey: wrapped, data: data);
    return OpenedVault(file, dek);
  } finally {
    wipe(kek);
  }
}

/// Retrouve la DEK. Lève [WrongPasswordException] si le mot de passe
/// est faux (ou si l'en-tête a été modifié).
Future<Uint8List> unwrapKey(String password, VaultFile file) async {
  final kek = await deriveKek(password, file.kdf);
  try {
    return await _decrypt(file.wrappedKey, kek, file.header);
  } on SecretBoxAuthenticationError {
    throw const WrongPasswordException();
  } finally {
    wipe(kek);
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
/// ou l'en-tête a été modifié.
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
