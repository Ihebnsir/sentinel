import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Mémorise l'accord de l'utilisateur pour Have I Been Pwned.
/// Un simple oui / non dans le dossier privé de l'app (rien de secret).
class BreachConsentStore {
  BreachConsentStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const fileName = 'breach_consent.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async {
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// false si l'utilisateur n'a jamais accepté (ou si le fichier est abîmé).
  Future<bool> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return false;
      final json = jsonDecode(await file.readAsString());
      return json is Map && json['accepted'] == true;
    } on Exception {
      return false;
    }
  }

  Future<void> write(bool accepted) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({'accepted': accepted}), flush: true);
  }
}
