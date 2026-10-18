import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/french_number.dart';

/// L'état du pare-feu DNS, lu côté Android.
class FirewallStatus {
  const FirewallStatus({
    required this.active,
    required this.totalQueries,
    required this.blockedQueries,
  });

  factory FirewallStatus.fromMap(Map<Object?, Object?> map) => FirewallStatus(
    active: map['active'] == true,
    totalQueries: _int(map['totalQueries']),
    blockedQueries: _int(map['blockedQueries']),
  );

  final bool active; // le filtrage tourne ?
  final int totalQueries; // requêtes DNS vues depuis le démarrage
  final int blockedQueries; // dont bloquées

  /// Ligne courte pour l'accueil, ex : « Activé · 12 requêtes bloquées ».
  String get summary {
    if (!active) return 'Désactivé';
    final n = formatFrenchNumber(blockedQueries);
    return blockedQueries > 1
        ? 'Activé · $n requêtes bloquées'
        : 'Activé · $n requête bloquée';
  }

  static int _int(Object? value) => value is int ? value : 0;
}

/// Fait le lien avec FirewallChannel.kt via un MethodChannel.
class FirewallService {
  // Même nom que dans FirewallChannel.kt.
  static const _channel = MethodChannel('com.iheb.sentinel/firewall');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// null hors Android ou si Android ne répond pas.
  Future<FirewallStatus?> getStatus() async {
    if (!isSupported) return null;
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>('status');
      return map == null ? null : FirewallStatus.fromMap(map);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Pare-feu : état illisible (${e.message})');
      return null;
    }
  }

  /// Affiche si besoin l'écran de consentement VPN d'Android.
  /// Retourne true si l'autorisation est accordée.
  Future<bool> prepare() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('prepare') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('Pare-feu : prepare a échoué (${e.message})');
      return false;
    }
  }

  Future<void> start() => _call('start');

  Future<void> stop() => _call('stop');

  static Future<void> _call(String method) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Pas de code natif.
    } on PlatformException catch (e) {
      debugPrint('Pare-feu : $method a échoué (${e.message})');
    }
  }
}
