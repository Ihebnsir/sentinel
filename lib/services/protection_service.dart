import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// L'état réel de la protection automatique, lu côté Android.
class ProtectionStatus {
  const ProtectionStatus({
    required this.listenerAccess,
    required this.notificationsAllowed,
    required this.enabled,
  });

  factory ProtectionStatus.fromMap(Map<Object?, Object?> map) =>
      ProtectionStatus(
        listenerAccess: map['listenerAccess'] == true,
        notificationsAllowed: map['notificationsAllowed'] == true,
        enabled: map['enabled'] == true,
      );

  final bool listenerAccess; // accès aux notifications accordé ?
  final bool notificationsAllowed; // Sentinel peut afficher ses alertes ?
  final bool enabled; // option activée dans Sentinel ?

  /// La protection tourne vraiment : option activée ET accès accordé.
  bool get isActive => enabled && listenerAccess;
}

/// Fait le lien avec MainActivity.kt pour la protection automatique.
class ProtectionService {
  // Même nom que dans MainActivity.kt, sinon les messages se perdent.
  static const _channel = MethodChannel('com.iheb.sentinel/protection');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// null si la fonctionnalité n'existe pas (Windows, web…).
  Future<ProtectionStatus?> getStatus() async {
    if (!_isAndroid) return null;
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>('getStatus');
      return map == null ? null : ProtectionStatus.fromMap(map);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('État de la protection illisible : ${e.message}');
      return null;
    }
  }

  Future<void> setEnabled(bool enabled) =>
      _call('setEnabled', {'enabled': enabled});

  /// Réglage Android « Accès aux notifications ».
  Future<void> openListenerSettings() => _call('openListenerSettings');

  /// Réglages des notifications de Sentinel.
  Future<void> openNotificationSettings() => _call('openNotificationSettings');

  /// Android 13+ : affiche la demande ; retourne true si les alertes
  /// pourront s'afficher.
  Future<bool> requestNotificationPermission() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'requestNotificationPermission',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _call(String method, [Map<String, Object>? args]) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Aucun code natif n'écoute ce canal.
    } on PlatformException catch (e) {
      debugPrint('Protection : $method a échoué (${e.message})');
    }
  }
}
