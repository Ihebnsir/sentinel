import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/installed_app.dart';

/// Fait le lien avec le scanner Kotlin (InstalledAppsScanner.kt).
class AppsScannerService {
  // Même nom que dans MainActivity.kt, sinon les messages se perdent.
  static const _channel = MethodChannel('com.iheb.sentinel/apps');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Liste les applications installées.
  /// Retourne null si l'analyse n'est pas disponible (Windows, web…).
  /// Lève une PlatformException si Android signale une erreur.
  Future<List<InstalledApp>?> scanApps() async {
    if (!_isAndroid) return null;
    try {
      final list = await _channel.invokeListMethod<Object?>('scanApps');
      if (list == null) return null;
      return [
        for (final item in list)
          if (item is Map) InstalledApp.fromMap(item.cast()),
      ];
    } on MissingPluginException {
      // Aucun code natif n'écoute ce canal.
      return null;
    }
  }

  /// Ouvre la page « Infos sur l'application » d'Android.
  Future<void> openAppSettings(String packageName) =>
      _invoke('openAppSettings', packageName);

  /// Ouvre la confirmation de désinstallation d'Android.
  Future<void> uninstallApp(String packageName) =>
      _invoke('uninstallApp', packageName);

  /// Ouvre une page d'aide (https) dans le navigateur.
  Future<void> openWebPage(String url) => _invoke('openWebPage', url, 'url');

  Future<void> _invoke(
    String method,
    String value, [
    String argument = 'packageName',
  ]) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method, {argument: value});
    } on PlatformException catch (e) {
      debugPrint('Action « $method » impossible : ${e.message}');
    } on MissingPluginException {
      // Rien à faire : pas de code natif.
    }
  }
}
