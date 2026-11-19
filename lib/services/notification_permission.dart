import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Autorisation d'afficher des notifications (alertes du pare-feu,
/// rappel du bilan de la semaine). Lien avec MainActivity.kt.
class NotificationPermission {
  const NotificationPermission();

  // Même nom que dans MainActivity.kt.
  static const _channel = MethodChannel('com.iheb.sentinel/notifications');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Android 13+ : affiche la demande. true si les notifications pourront
  /// s'afficher. false hors Android.
  Future<bool> request() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
