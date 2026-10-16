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

/// Un emplacement de clé (« key slot ») : une façon d'ouvrir le coffre.
/// Chaque emplacement enveloppe la MÊME DEK avec sa propre KEK.
sealed class KeySlot {
  const KeySlot(this.wrappedKey);

  /// La DEK chiffrée par la KEK de cet emplacement.
  final EncryptedBlob wrappedKey;

  /// Les paramètres publics, sans la clé enveloppée.
  Map<String, Object> get params;

  Map<String, Object> toJson() => {
    ...params,
    'wrappedKey': wrappedKey.toJson(),
  };

  /// AAD de la clé enveloppée : version + paramètres de l'emplacement.
  /// Changer le sel ou le type fait échouer le déchiffrement.
  Uint8List get aad => aadFor(params);

  static Uint8List aadFor(Map<String, Object> params) => utf8.encode(
    jsonEncode({'version': VaultFile.currentVersion, 'slot': params}),
  );

  factory KeySlot.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const VaultFormatException('Emplacement de clé invalide');
    }
    final wrapped = EncryptedBlob.fromJson(json['wrappedKey']);
    switch (json['type']) {
      case PasswordSlot.type:
        final kdf = json['kdf'];
        if (kdf is! Map<String, Object?>) {
          throw const VaultFormatException(
            'Paramètres de dérivation manquants',
          );
        }
        return PasswordSlot(kdf: KdfParams.fromJson(kdf), wrappedKey: wrapped);
      case RecoverySlot.type:
        final salt = _bytes(json, 'sel');
        if (salt.length != RecoverySlot.saltLength) {
          throw const VaultFormatException('Sel de récupération invalide');
        }
        return RecoverySlot(salt: salt, wrappedKey: wrapped);
      case BiometricSlot.type:
        return BiometricSlot(wrappedKey: wrapped);
      default:
        throw const VaultFormatException('Emplacement de clé inconnu');
    }
  }
}

/// Mot de passe maître : KEK = Argon2id(mot de passe, sel).
class PasswordSlot extends KeySlot {
  const PasswordSlot({required this.kdf, required EncryptedBlob wrappedKey})
    : super(wrappedKey);

  static const type = 'password';

  final KdfParams kdf;

  static Map<String, Object> paramsFor(KdfParams kdf) => {
    'type': type,
    'kdf': kdf.toJson(),
  };

  @override
  Map<String, Object> get params => paramsFor(kdf);
}

/// Clé de récupération : KEK = HKDF-SHA256(clé, sel).
class RecoverySlot extends KeySlot {
  const RecoverySlot({required this.salt, required EncryptedBlob wrappedKey})
    : super(wrappedKey);

  static const type = 'recovery';
  static const saltLength = 16;

  final Uint8List salt;

  static Map<String, Object> paramsFor(Uint8List salt) => {
    'type': type,
    'sel': base64.encode(salt),
  };

  @override
  Map<String, Object> get params => paramsFor(salt);
}

/// Empreinte (Android) : la DEK chiffrée par une clé du Keystore.
/// Le fichier ne contient que le chiffré et le nonce (IV).
class BiometricSlot extends KeySlot {
  const BiometricSlot({required EncryptedBlob wrappedKey}) : super(wrappedKey);

  static const type = 'biometric';
  static const Map<String, Object> staticParams = {'type': type};

  @override
  Map<String, Object> get params => staticParams;
}

/// Le fichier vault.json, entièrement en base64 sauf l'en-tête.
///
/// Version 2 : une liste d'emplacements de clé (`keySlots`) et la date de
/// la dernière ouverture par mot de passe. La version 1 (un seul mot de
/// passe) est encore lue, puis migrée à la première ouverture.
class VaultFile {
  const VaultFile({
    required this.slots,
    required this.data,
    this.lastPasswordUnlock,
    this.version = currentVersion,
  });

  static const currentVersion = 2;

  /// Au-delà, l'empreinte ne suffit plus : le mot de passe est exigé.
  static const passwordMaxAge = Duration(days: 7);

  final int version;
  final List<KeySlot> slots;

  /// Dernière ouverture par mot de passe (UTC, à la seconde). Dans
  /// l'en-tête, donc protégée par GCM : impossible de la falsifier.
  final DateTime? lastPasswordUnlock;

  final EncryptedBlob data; // les éléments chiffrés par la DEK

  PasswordSlot get passwordSlot => slots.whereType<PasswordSlot>().first;
  RecoverySlot? get recoverySlot => slots.whereType<RecoverySlot>().firstOrNull;
  BiometricSlot? get biometricSlot =>
      slots.whereType<BiometricSlot>().firstOrNull;

  /// L'en-tête (tout sauf les données) en octets, utilisé comme AAD des
  /// données : si un seul octet change (un emplacement, la date…), le
  /// déchiffrement échoue. Reconstruit toujours dans le même ordre.
  Uint8List get header => version == 1
      ? utf8.encode(
          jsonEncode({'version': 1, 'kdf': passwordSlot.kdf.toJson()}),
        )
      : utf8.encode(jsonEncode(_headerJson()));

  /// AAD de la clé enveloppée d'un emplacement (v1 : l'en-tête entier).
  Uint8List aadOf(KeySlot slot) => version == 1 ? header : slot.aad;

  /// Faut-il le mot de passe (et non l'empreinte) ? Oui après 7 jours,
  /// ou si la date est très en avance (horloge du téléphone reculée).
  bool needsPassword(DateTime now) {
    final last = lastPasswordUnlock;
    if (last == null) return true;
    final age = now.difference(last);
    return age > passwordMaxAge || age < const Duration(days: -1);
  }

  VaultFile withData(EncryptedBlob data) => VaultFile(
    version: version,
    slots: slots,
    lastPasswordUnlock: lastPasswordUnlock,
    data: data,
  );

  /// Copie en version 2 avec d'autres emplacements ou une autre date.
  /// Attention : l'en-tête change, les données doivent être rescellées.
  VaultFile copyWith({List<KeySlot>? slots, DateTime? lastPasswordUnlock}) =>
      VaultFile(
        slots: slots ?? this.slots,
        lastPasswordUnlock: lastPasswordUnlock ?? this.lastPasswordUnlock,
        data: data,
      );

  /// Remplace l'emplacement du même type (ou l'ajoute).
  VaultFile withSlot(KeySlot slot) => copyWith(
    slots: [
      for (final s in slots)
        if (s.runtimeType != slot.runtimeType) s,
      slot,
    ]..sort((a, b) => _order(a).compareTo(_order(b))),
  );

  VaultFile withoutBiometricSlot() => copyWith(
    slots: [
      for (final s in slots)
        if (s is! BiometricSlot) s,
    ],
  );

  // Ordre fixe : mot de passe, récupération, empreinte.
  static int _order(KeySlot slot) => switch (slot) {
    PasswordSlot() => 0,
    RecoverySlot() => 1,
    BiometricSlot() => 2,
  };

  Map<String, Object> _headerJson() => {
    'version': version,
    'derniereOuvertureMdp': lastPasswordUnlock!.toUtc().toIso8601String(),
    'keySlots': [for (final slot in slots) slot.toJson()],
  };

  Map<String, Object> toJson() => version == 1
      ? {
          'version': 1,
          'kdf': passwordSlot.kdf.toJson(),
          'wrappedKey': passwordSlot.wrappedKey.toJson(),
          'data': data.toJson(),
        }
      : {..._headerJson(), 'data': data.toJson()};

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Lit le texte du fichier ; lève [VaultFormatException] s'il est abîmé.
  factory VaultFile.decode(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, Object?>) {
        throw const VaultFormatException('Fichier de coffre invalide');
      }
      return switch (json['version']) {
        1 => _decodeV1(json),
        2 => _decodeV2(json),
        final version => throw VaultFormatException(
          'Version de coffre inconnue : $version',
        ),
      };
    } on VaultFormatException {
      rethrow;
    } on FormatException {
      throw const VaultFormatException('Fichier de coffre illisible');
    } on TypeError {
      throw const VaultFormatException('Fichier de coffre illisible');
    }
  }

  static VaultFile _decodeV1(Map<String, Object?> json) {
    final kdf = json['kdf'];
    if (kdf is! Map<String, Object?>) {
      throw const VaultFormatException('Paramètres de dérivation manquants');
    }
    return VaultFile(
      version: 1,
      slots: [
        PasswordSlot(
          kdf: KdfParams.fromJson(kdf),
          wrappedKey: EncryptedBlob.fromJson(json['wrappedKey']),
        ),
      ],
      data: EncryptedBlob.fromJson(json['data']),
    );
  }

  static VaultFile _decodeV2(Map<String, Object?> json) {
    final rawSlots = json['keySlots'];
    if (rawSlots is! List<Object?>) {
      throw const VaultFormatException('Emplacements de clé manquants');
    }
    final slots = [for (final slot in rawSlots) KeySlot.fromJson(slot)];
    // Exactement un mot de passe, au plus une clé de chaque autre type.
    int count<T>() => slots.whereType<T>().length;
    if (count<PasswordSlot>() != 1 ||
        count<RecoverySlot>() > 1 ||
        count<BiometricSlot>() > 1) {
      throw const VaultFormatException('Emplacements de clé invalides');
    }
    final date = json['derniereOuvertureMdp'];
    if (date is! String) {
      throw const VaultFormatException('Date de dernière ouverture manquante');
    }
    return VaultFile(
      slots: slots,
      lastPasswordUnlock: DateTime.parse(date).toUtc(),
      data: EncryptedBlob.fromJson(json['data']),
    );
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
