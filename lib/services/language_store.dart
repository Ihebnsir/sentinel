import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/l10n.dart';

/// Mémorise la langue choisie dans Réglages (null : celle du téléphone).
/// Même modèle que OnboardingStore : un petit fichier, rien de secret.
class LanguageStore {
  LanguageStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const fileName = 'language.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async {
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  /// Code de la langue choisie (« ar »), null si aucune ou fichier abîmé.
  Future<String?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      final code = json is Map ? json['language'] : null;
      return _isSupported(code) ? code as String : null;
    } on Exception {
      return null;
    }
  }

  Future<void> save(String? languageCode) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'language': languageCode}),
      flush: true,
    );
  }

  static bool _isSupported(Object? code) =>
      appSupportedLocales.any((l) => l.languageCode == code);
}

/// La langue de l'app, écoutée par SentinelApp (null : celle du téléphone).
/// Le choix est aussi envoyé à Android, pour les notifications.
class LanguageController extends ValueNotifier<Locale?> {
  LanguageController({LanguageStore? store})
    : _store = store ?? LanguageStore(),
      super(null);

  // Même nom que dans MainActivity.kt.
  static const _channel = MethodChannel('com.iheb.sentinel/language');

  final LanguageStore _store;

  /// Lit le choix enregistré (au démarrage).
  Future<void> load() async {
    final code = await _store.load();
    value = code == null ? null : Locale(code);
    await _tellAndroid(code);
  }

  /// [languageCode] null : revenir à la langue du téléphone.
  Future<void> choose(String? languageCode) async {
    value = languageCode == null ? null : Locale(languageCode);
    try {
      await _store.save(languageCode);
    } on Exception {
      // Pas grave : le choix vaut jusqu'à la fermeture de l'app.
    }
    await _tellAndroid(languageCode);
  }

  static Future<void> _tellAndroid(String? languageCode) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setLanguage', {
        'language': languageCode,
      });
    } on MissingPluginException {
      // Pas de code natif (tests).
    } on PlatformException {
      // Les notifications resteront dans la langue du téléphone.
    }
  }
}

/// Donne le LanguageController aux écrans (Réglages).
class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  /// null si l'écran est affiché sans SentinelApp (tests).
  static LanguageController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.notifier;
}
