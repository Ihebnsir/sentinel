import 'dart:io';
import 'dart:typed_data';

import 'vault_backup.dart';
import 'vault_crypto.dart';
import 'vault_file.dart';

/// Taille maximale d'un document (après recompression d'une image).
const maxDocumentBytes = 10 * 1024 * 1024;

/// Le document dépasse [maxDocumentBytes].
class DocumentTooLargeException implements Exception {
  const DocumentTooLargeException();
}

/// Ni une image (JPEG, PNG, WebP) ni un PDF.
class UnsupportedDocumentException implements Exception {
  const UnsupportedDocumentException();
}

/// Type d'un document d'après ses premiers octets (on ne croit pas le
/// sélecteur sur parole). null : type refusé.
String? detectDocumentMime(Uint8List bytes) {
  bool startsWith(List<int> magic, [int offset = 0]) {
    if (bytes.length < offset + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[offset + i] != magic[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8)) {
    return 'image/webp';
  }
  if (startsWith('%PDF-'.codeUnits)) return 'application/pdf';
  return null;
}

/// Les documents du coffre : un fichier chiffré par document, dans le
/// dossier privé de l'app (`vault_docs/<id>.bin`). Format du fichier :
/// « SDOC », version (1 octet), nonce (12 octets), chiffré + tag.
/// Rien n'est jamais écrit en clair : le fichier temporaire de
/// l'écriture atomique est déjà chiffré.
class VaultDocumentStore {
  VaultDocumentStore({required this.directory});

  static const folderName = 'vault_docs';
  static const _magic = [0x53, 0x44, 0x4F, 0x43]; // « SDOC »
  static const _version = 1;
  static const _headerLength = 5;

  /// Dossier privé de l'app (le même que celui du coffre).
  final Future<Directory> Function() directory;

  Future<Directory> folder() async {
    final dir = await directory();
    return Directory('${dir.path}${Platform.pathSeparator}$folderName');
  }

  Future<File> _fileFor(String id) async {
    // L'id vient aussi d'une sauvegarde importée : jamais de « ../ ».
    if (!isSafeDocumentId(id)) throw ArgumentError('id de document invalide');
    final dir = await folder();
    return File('${dir.path}${Platform.pathSeparator}$id.bin');
  }

  /// Chiffre [clear] avec la DEK et l'écrit (remplace l'ancien).
  Future<void> write(String id, Uint8List dek, Uint8List clear) async {
    final file = await _fileFor(id);
    final blob = await encryptDocument(clear, dek, id);
    final bytes = BytesBuilder(copy: false)
      ..add(_magic)
      ..addByte(_version)
      ..add(blob.nonce)
      ..add(blob.cipherText);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes.takeBytes(), flush: true);
    await temp.rename(file.path);
  }

  /// Déchiffre le document. Lève [VaultCorruptedException] si le fichier
  /// manque, a été modifié ou appartient à un autre document.
  Future<Uint8List> read(String id, Uint8List dek) async {
    final file = await _fileFor(id);
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on FileSystemException {
      throw const VaultCorruptedException();
    }
    const minLength =
        _headerLength + EncryptedBlob.nonceLength + EncryptedBlob.tagLength;
    if (bytes.length < minLength ||
        bytes[0] != _magic[0] ||
        bytes[1] != _magic[1] ||
        bytes[2] != _magic[2] ||
        bytes[3] != _magic[3] ||
        bytes[4] != _version) {
      throw const VaultCorruptedException();
    }
    const nonceEnd = _headerLength + EncryptedBlob.nonceLength;
    return decryptDocument(
      EncryptedBlob(
        nonce: Uint8List.sublistView(bytes, _headerLength, nonceEnd),
        cipherText: Uint8List.sublistView(bytes, nonceEnd),
      ),
      dek,
      id,
    );
  }

  /// Efface le fichier chiffré (et un éventuel temporaire).
  Future<void> delete(String id) async {
    final file = await _fileFor(id);
    for (final f in [file, File('${file.path}.tmp')]) {
      if (await f.exists()) await f.delete();
    }
  }

  /// Efface tous les documents (coffre supprimé ou recréé).
  Future<void> deleteAll() async {
    final dir = await folder();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Efface les fichiers qu'aucun élément ne référence plus (suppression
  /// interrompue, écriture abandonnée).
  Future<void> removeOrphans(Set<String> keep) async {
    final dir = await folder();
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      final id = name.endsWith('.bin')
          ? name.substring(0, name.length - 4)
          : null;
      if (id == null || !keep.contains(id)) await entity.delete();
    }
  }
}
