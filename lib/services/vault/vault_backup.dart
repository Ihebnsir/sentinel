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
/// { "format": "sentinel-sauvegarde", "version": 2,
///   "kdf": { Argon2id, sel neuf }, "data": { nonce, chiffré },
///   "documents": [ { "id", nonce, chiffré } ] }
/// ```
///
/// La clé vient d'Argon2id(mot de passe d'export) : aucun lien avec le
/// mot de passe maître ni la DEK du coffre. format + version + kdf
/// forment l'en-tête, utilisé comme AAD : le modifier fait échouer GCM.
/// Chaque document a pour AAD l'en-tête suivi de son id.
/// Version 1 : sans « documents » (toujours lue).
class VaultBackup {
  const VaultBackup({
    required this.kdf,
    required this.data,
    this.documents = const {},
    this.version = currentVersion,
  });

  static const formatName = 'sentinel-sauvegarde';
  static const currentVersion = 2;
  static const extension = 'sentinel';

  /// Versions lues (1 : avant les documents).
  static const readableVersions = {1, 2};

  /// Au-delà, le fichier est refusé avant même d'être décodé.
  /// Assez pour une dizaine de documents de 10 Mo (base64 : +33 %).
  static const maxBytes = 128 * 1024 * 1024;

  final int version;
  final KdfParams kdf;
  final EncryptedBlob data; // les éléments chiffrés

  /// Contenu chiffré des documents, par id (version 2).
  final Map<String, EncryptedBlob> documents;

  Map<String, Object> _headerJson() => {
    'format': formatName,
    'version': version,
    'kdf': kdf.toJson(),
  };

  /// L'en-tête en octets, reconstruit toujours dans le même ordre.
  Uint8List get header => utf8.encode(jsonEncode(_headerJson()));

  VaultBackup withData(EncryptedBlob data) =>
      VaultBackup(version: version, kdf: kdf, data: data, documents: documents);

  Uint8List encode() => utf8.encode(
    const JsonEncoder.withIndent('  ').convert({
      ..._headerJson(),
      'data': data.toJson(),
      if (version >= 2)
        'documents': [
          for (final entry in documents.entries)
            {'id': entry.key, ...entry.value.toJson()},
        ],
    }),
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
      final version = json['version'];
      if (version is! int || !readableVersions.contains(version)) {
        throw const BackupFormatException(BackupProblem.versionInconnue);
      }
      final kdf = json['kdf'];
      if (kdf is! Map<String, Object?>) {
        throw const BackupFormatException(BackupProblem.illisible);
      }
      return VaultBackup(
        version: version,
        kdf: KdfParams.fromJson(kdf), // bornes de bon sens incluses
        data: EncryptedBlob.fromJson(json['data']),
        documents: version >= 2 ? _decodeDocuments(json['documents']) : {},
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

  // Liste [{id, nonce, chiffre}] ; id sûr (devient un nom de fichier) et
  // unique.
  static Map<String, EncryptedBlob> _decodeDocuments(Object? json) {
    if (json is! List<Object?>) {
      throw const BackupFormatException(BackupProblem.illisible);
    }
    final documents = <String, EncryptedBlob>{};
    for (final entry in json) {
      if (entry is! Map<String, Object?>) {
        throw const BackupFormatException(BackupProblem.illisible);
      }
      final id = entry['id'];
      if (id is! String || !isSafeDocumentId(id) || documents.containsKey(id)) {
        throw const BackupFormatException(BackupProblem.illisible);
      }
      documents[id] = EncryptedBlob.fromJson(entry);
    }
    return documents;
  }
}

/// Un id utilisable comme nom de fichier : ni « / », ni « .. ».
bool isSafeDocumentId(String id) =>
    RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id);
