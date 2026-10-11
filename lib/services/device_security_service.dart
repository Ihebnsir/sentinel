import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/device_security_status.dart';
import '../models/security_action.dart';

/// Fait le lien avec le code Kotlin (MainActivity.kt) via un MethodChannel.
class DeviceSecurityService {
  // Même nom que dans MainActivity.kt, sinon les messages se perdent.
  static const _channel = MethodChannel('com.iheb.sentinel/device_security');

  /// Lance l'audit côté Android.
  /// Retourne null si l'analyse n'est pas disponible (Windows, web…).
  /// Lève une PlatformException si Android signale une erreur.
  Future<DeviceSecurityStatus?> getSecurityStatus() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>(
        'getSecurityStatus',
      );
      return map == null ? null : DeviceSecurityStatus.fromMap(map);
    } on MissingPluginException {
      // Aucun code natif n'écoute ce canal.
      return null;
    }
  }

  /// Ouvre l'écran des paramètres Android correspondant.
  Future<void> openSettings(SettingsTarget target) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('openSettings', {'target': target.name});
    } on PlatformException catch (e) {
      debugPrint('Impossible d\'ouvrir les paramètres : ${e.message}');
    } on MissingPluginException {
      // Rien à faire : pas de code natif.
    }
  }
}
