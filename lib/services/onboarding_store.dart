import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Mémorise que la présentation du premier lancement a été vue.
/// Un simple oui / non dans le dossier privé de l'app (rien de secret).
class OnboardingStore {
  OnboardingStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const fileName = 'onboarding.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async {
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// false si la présentation n'a jamais été terminée (ou fichier abîmé).
  Future<bool> isDone() async {
    try {
      final file = await _file();
      if (!await file.exists()) return false;
      final json = jsonDecode(await file.readAsString());
      return json is Map && json['done'] == true;
    } on Exception {
      return false;
    }
  }

  Future<void> markDone() async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({'done': true}), flush: true);
  }
}
