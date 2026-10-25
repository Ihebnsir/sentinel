import 'dart:convert';
import 'dart:typed_data';

import 'vault_file.dart';

/// Pourquoi un fichier de sauvegarde ne peut pas être lu.
enum BackupProblem {
  vide, // fichier de 0 octet
  illisible, // pas une sauvegarde Sentinel, ou abîmée
  versionInconnue, // faite par une version plus récente de Sentinel
}

/// Le fichier choisi n'est pas une sauvegarde lisible (avant tout
/// déchiffrement : le mot de passe n'est pas en cause).
class BackupFormatException implements Exception {
  const BackupFormatException(this.problem);

  final BackupProblem problem;

  @override
  String toString() => 'BackupFormatException: ${problem.name}';
}

/// Une sauvegarde chiffrée du coffre (fichier .sentinel), en JSON :
///
/// ```json
/// { "format": "sentinel-sauvegarde", "version": 1,
///   "kdf": { Argon2id, sel neuf }, "data": { nonce, chiffré } }
/// ```
///
/// La clé vient d'Argon2id(mot de passe d'export) : aucun lien avec le
/// mot de passe maître ni la DEK du coffre. Tout sauf « data » forme
/// l'en-tête, utilisé comme AAD : le modifier fait échouer GCM.
class VaultBackup {
  const VaultBackup({
    required this.kdf,
    required this.data,
    this.version = currentVersion,
  });

  static const formatName = 'sentinel-sauvegarde';
  static const currentVersion = 1;
  static const extension = 'sentinel';

  /// Au-delà, le fichier est refusé avant même d'être décodé.
  static const maxBytes = 16 * 1024 * 1024;

  final int version;
  final KdfParams kdf;
  final EncryptedBlob data; // les éléments chiffrés

  Map<String, Object> _headerJson() => {
    'format': formatName,
    'version': version,
    'kdf': kdf.toJson(),
  };

  /// L'en-tête en octets, reconstruit toujours dans le même ordre.
  Uint8List get header => utf8.encode(jsonEncode(_headerJson()));

  VaultBackup withData(EncryptedBlob data) =>
      VaultBackup(version: version, kdf: kdf, data: data);

  Uint8List encode() => utf8.encode(
    const JsonEncoder.withIndent('  ')
        .convert({..._headerJson(), 'data': data.toJson()}),
  );

  /// Lit les octets du fichier ; lève [BackupFormatException] sinon.
  factory VaultBackup.decode(Uint8List bytes) {
    if (bytes.isEmpty) throw const BackupFormatException(BackupProblem.vide);
    if (bytes.length > maxBytes) {
      throw const BackupFormatException(BackupProblem.illisible);
    }
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, Object?> || json['format'] != formatName) {
        throw const BackupFormatException(BackupProblem.illisible);
      }
      if (json['version'] != currentVersion) {
        throw const BackupFormatException(BackupProblem.versionInconnue);
      }
      final kdf = json['kdf'];
      if (kdf is! Map<String, Object?>) {
        throw const BackupFormatException(BackupProblem.illisible);
      }
      return VaultBackup(
        kdf: KdfParams.fromJson(kdf), // bornes de bon sens incluses
        data: EncryptedBlob.fromJson(json['data']),
      );
    } on BackupFormatException {
      rethrow;
    } on VaultFormatException {
      throw const BackupFormatException(BackupProblem.illisible);
    } on FormatException {
      throw const BackupFormatException(BackupProblem.illisible);
    } on TypeError {
      throw const BackupFormatException(BackupProblem.illisible);
    }
  }
}
