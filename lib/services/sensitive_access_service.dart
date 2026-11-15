import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/debug_log.dart';
import 'sensitive_access.dart';

/// Fait le lien avec SensitiveAccessReader.kt (canal des apps).
class SensitiveAccessService {
  // Même nom que dans MainActivity.kt.
  static const _channel = MethodChannel('com.iheb.sentinel/apps');

  static bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// « Accès aux données d'utilisation » accordé à Sentinel ?
  Future<bool> hasUsageAccess() async {
    if (!isAvailable) return false;
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Apps ayant caméra, micro ou localisation, et leurs événements.
  /// Lève une PlatformException si Android signale une erreur.
  Future<List<SensitiveAccessApp>> read() async {
    if (!isAvailable) return const [];
    try {
      final list = await _channel.invokeListMethod<Object?>(
        'readSensitiveAccess',
      );
      return [
        for (final item in list ?? const [])
          if (item is Map) SensitiveAccessApp.fromMap(item.cast()),
      ];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Ouvre le réglage « Accès aux données d'utilisation ».
  Future<void> openUsageAccessSettings() => _invoke('openUsageAccessSettings');

  /// Ouvre le tableau de bord de confidentialité d'Android (12+).
  Future<void> openPrivacyDashboard() => _invoke('openPrivacyDashboard');

  Future<void> _invoke(String method) async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (e) {
      debugLog(() => 'Action « $method » impossible : ${e.message}');
    } on MissingPluginException {
      // Pas de code natif.
    }
  }
}
