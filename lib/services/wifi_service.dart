import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/wifi_status.dart';

/// Fait le lien avec WifiSecurityChecker.kt via un MethodChannel.
class WifiService {
  // Même nom que dans WifiSecurityChecker.kt.
  static const _channel = MethodChannel('com.iheb.sentinel/wifi');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// L'état du Wi-Fi actuel ; null hors Android.
  /// Lève une PlatformException si Android signale une erreur.
  Future<WifiStatus?> getWifiStatus() async {
    if (!isSupported) return null;
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>(
        'getWifiStatus',
      );
      return map == null ? null : WifiStatus.fromMap(map);
    } on MissingPluginException {
      return null;
    }
  }

  /// Prévient [onChanged] à chaque changement de réseau, jusqu'à
  /// [stopListening].
  Future<void> startListening(void Function(WifiStatus) onChanged) async {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (call.method == 'onWifiChanged' && args is Map) {
        onChanged(WifiStatus.fromMap(args));
      }
    });
    await _invoke('startListening');
  }

  Future<void> stopListening() async {
    if (!isSupported) return;
    _channel.setMethodCallHandler(null);
    await _invoke('stopListening');
  }

  /// Ouvre les réglages réseau, où se trouve le DNS privé.
  Future<void> openPrivateDnsSettings() async {
    if (!isSupported) return;
    await _invoke('openPrivateDnsSettings');
  }

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (e) {
      debugPrint('Wi-Fi : $method a échoué (${e.message})');
    } on MissingPluginException {
      // Pas de code natif.
    }
  }
}
