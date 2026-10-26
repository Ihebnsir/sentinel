import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

/// Mémorise le thème choisi dans Réglages : clair, sombre ou système.
/// Même modèle que LanguageStore : un petit fichier, rien de secret.
class ThemeStore {
  ThemeStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const fileName = 'theme.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async {
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// Le choix enregistré ; celui du téléphone si aucun ou fichier abîmé.
  Future<ThemeMode> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return ThemeMode.system;
      final json = jsonDecode(await file.readAsString());
      final name = json is Map ? json['theme'] : null;
      return ThemeMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => ThemeMode.system,
      );
    } on Exception {
      return ThemeMode.system;
    }
  }

  Future<void> save(ThemeMode mode) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({'theme': mode.name}), flush: true);
  }
}

/// Le thème de l'app, écouté par SentinelApp (system : celui du téléphone).
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController({ThemeStore? store})
    : _store = store ?? ThemeStore(),
      super(ThemeMode.system);

  final ThemeStore _store;

  /// Lit le choix enregistré (au démarrage).
  Future<void> load() async => value = await _store.load();

  Future<void> choose(ThemeMode mode) async {
    value = mode;
    try {
      await _store.save(mode);
    } on Exception {
      // Pas grave : le choix vaut jusqu'à la fermeture de l'app.
    }
  }
}

/// Donne le ThemeController aux écrans (Réglages).
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// null si l'écran est affiché sans SentinelApp (tests).
  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}
