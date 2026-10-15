import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'vault_file.dart';

/// Lit et écrit vault.json dans le dossier privé de l'app.
class VaultStorage {
  VaultStorage({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const fileName = 'vault.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async {
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// null si aucun coffre n'a encore été créé.
  /// Lève [VaultFormatException] si le fichier est abîmé.
  Future<VaultFile?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return VaultFile.decode(await file.readAsString());
  }

  /// Écriture atomique : on écrit un fichier temporaire complet, puis on
  /// le renomme. Un renommage est tout-ou-rien : si l'app s'arrête en
  /// plein milieu, l'ancien coffre reste intact.
  Future<void> write(VaultFile vault) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(vault.encode(), flush: true);
    await temp.rename(file.path);
  }
}
