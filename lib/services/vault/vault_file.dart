import 'dart:convert';
import 'dart:typed_data';

/// Le coffre est illisible (fichier abîmé, format inconnu…).
class VaultFormatException implements Exception {
  const VaultFormatException(this.message);

  final String message;

  @override
  String toString() => 'VaultFormatException: $message';
}

/// Paramètres de la dérivation Argon2id, enregistrés dans l'en-tête
/// pour pouvoir les renforcer plus tard sans casser les anciens coffres.
class KdfParams {
  const KdfParams({
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
    required this.salt,
  });

  static const algo = 'argon2id';
  static const saltLength = 16;

  final int memoryKib; // mémoire en Kio (1024 octets)
  final int iterations;
  final int parallelism;
  final Uint8List salt;

  Map<String, Object> toJson() => {
    'algo': algo,
    'memoire': memoryKib,
    'iterations': iterations,
    'parallelisme': parallelism,
    'sel': base64.encode(salt),
  };

  factory KdfParams.fromJson(Map<String, Object?> json) {
    if (json['algo'] != algo) {
      throw const VaultFormatException('Algorithme de dérivation inconnu');
    }
    final params = KdfParams(
      memoryKib: _int(json, 'memoire'),
      iterations: _int(json, 'iterations'),
      parallelism: _int(json, 'parallelisme'),
      salt: _bytes(json, 'sel'),
    );
    // Bornes de bon sens : un fichier trafiqué ne doit pas pouvoir
    // demander 50 Go de mémoire ou un million d'itérations.
    if (params.parallelism < 1 ||
        params.parallelism > 16 ||
        params.memoryKib < 8 * params.parallelism ||
        params.memoryKib > 1024 * 1024 ||
        params.iterations < 1 ||
        params.iterations > 20 ||
        params.salt.length != saltLength) {
      throw const VaultFormatException('Paramètres de dérivation invalides');
    }
    return params;
  }
}

/// Un bloc chiffré AES-GCM : le nonce et le chiffré (tag de 16 octets
/// collé à la fin, comme le veut l'usage).
class EncryptedBlob {
  const EncryptedBlob({required this.nonce, required this.cipherText});

  static const nonceLength = 12;
  static const tagLength = 16;

  final Uint8List nonce;
  final Uint8List cipherText; // chiffré + tag

  Map<String, Object> toJson() => {
    'nonce': base64.encode(nonce),
    'chiffre': base64.encode(cipherText),
  };

  factory EncryptedBlob.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const VaultFormatException('Bloc chiffré manquant');
    }
    final blob = EncryptedBlob(
      nonce: _bytes(json, 'nonce'),
      cipherText: _bytes(json, 'chiffre'),
    );
    if (blob.nonce.length != nonceLength ||
        blob.cipherText.length < tagLength) {
      throw const VaultFormatException('Bloc chiffré invalide');
    }
    return blob;
  }
}

/// Le fichier vault.json, entièrement en base64 sauf l'en-tête.
class VaultFile {
  const VaultFile({
    required this.kdf,
    required this.wrappedKey,
    required this.data,
    this.version = currentVersion,
  });

  static const currentVersion = 1;

  final int version;
  final KdfParams kdf;
  final EncryptedBlob wrappedKey; // la DEK chiffrée par la KEK
  final EncryptedBlob data; // les éléments chiffrés par la DEK

  /// L'en-tête (version + paramètres) en octets, utilisé comme données
  /// associées (AAD) de GCM : s'il change d'un seul octet, le
  /// déchiffrement échoue. Reconstruit toujours dans le même ordre.
  Uint8List get header => headerBytes(version, kdf);

  static Uint8List headerBytes(int version, KdfParams kdf) =>
      utf8.encode(jsonEncode({'version': version, 'kdf': kdf.toJson()}));

  VaultFile withData(EncryptedBlob data) =>
      VaultFile(version: version, kdf: kdf, wrappedKey: wrappedKey, data: data);

  Map<String, Object> toJson() => {
    'version': version,
    'kdf': kdf.toJson(),
    'wrappedKey': wrappedKey.toJson(),
    'data': data.toJson(),
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Lit le texte du fichier ; lève [VaultFormatException] s'il est abîmé.
  factory VaultFile.decode(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, Object?>) {
        throw const VaultFormatException('Fichier de coffre invalide');
      }
      final version = json['version'];
      if (version != currentVersion) {
        throw VaultFormatException('Version de coffre inconnue : $version');
      }
      final kdf = json['kdf'];
      if (kdf is! Map<String, Object?>) {
        throw const VaultFormatException('Paramètres de dérivation manquants');
      }
      return VaultFile(
        version: version as int,
        kdf: KdfParams.fromJson(kdf),
        wrappedKey: EncryptedBlob.fromJson(json['wrappedKey']),
        data: EncryptedBlob.fromJson(json['data']),
      );
    } on VaultFormatException {
      rethrow;
    } on FormatException {
      throw const VaultFormatException('Fichier de coffre illisible');
    } on TypeError {
      throw const VaultFormatException('Fichier de coffre illisible');
    }
  }
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw VaultFormatException('Champ « $key » invalide');
  return value;
}

Uint8List _bytes(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw VaultFormatException('Champ « $key » invalide');
  return base64.decode(value);
}
