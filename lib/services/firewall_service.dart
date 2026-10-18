import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/french_date.dart';
import '../utils/french_number.dart';

/// L'état du pare-feu DNS, lu côté Android.
class FirewallStatus {
  const FirewallStatus({
    required this.active,
    required this.totalQueries,
    required this.blockedQueries,
    this.blockedByCategory = const {},
    this.listsLoading = false,
  });

  factory FirewallStatus.fromMap(Map<Object?, Object?> map) => FirewallStatus(
    active: map['active'] == true,
    totalQueries: _int(map['totalQueries']),
    blockedQueries: _int(map['blockedQueries']),
    blockedByCategory: {
      for (final entry in _map(map['blockedByCategory']).entries)
        if (entry.key is String) entry.key as String: _int(entry.value),
    },
    listsLoading: map['listsLoading'] == true,
  );

  final bool active; // le filtrage tourne ?
  final int totalQueries; // requêtes DNS vues depuis le démarrage
  final int blockedQueries; // dont bloquées
  final Map<String, int> blockedByCategory; // « malware » → 12
  final bool listsLoading; // listes en cours de chargement

  /// Ligne courte pour l'accueil, ex : « Activé · 12 requêtes bloquées ».
  String get summary {
    if (!active) return 'Désactivé';
    final n = formatFrenchNumber(blockedQueries);
    return blockedQueries > 1
        ? 'Activé · $n requêtes bloquées'
        : 'Activé · $n requête bloquée';
  }
}

/// Une catégorie de listes (Malware et hameçonnage, Traqueurs, Publicités).
class BlocklistCategory {
  const BlocklistCategory({
    required this.id,
    required this.name,
    required this.enabled,
    required this.domains,
    required this.sources,
  });

  factory BlocklistCategory.fromMap(Map<Object?, Object?> map) =>
      BlocklistCategory(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        enabled: map['enabled'] == true,
        domains: _int(map['domains']),
        sources: _strings(map['sources']),
      );

  final String id;
  final String name;
  final bool enabled;
  final int domains;
  final List<String> sources; // noms courts, ex : « ShadowWhisperer »

  /// Ex : « 430 961 domaines · Phishing.Database, ShadowWhisperer ».
  String get subtitle {
    final n = formatFrenchNumber(domains);
    final count = domains > 1 ? '$n domaines' : '$n domaine';
    return sources.isEmpty ? count : '$count · ${sources.join(', ')}';
  }
}

/// Une source de listes, pour la section « Sources et licences ».
class BlocklistSourceInfo {
  const BlocklistSourceInfo({
    required this.name,
    required this.license,
    required this.licenseUrl,
    required this.homepage,
    required this.attribution,
  });

  factory BlocklistSourceInfo.fromMap(Map<Object?, Object?> map) =>
      BlocklistSourceInfo(
        name: map['name'] as String? ?? '',
        license: map['license'] as String? ?? '',
        licenseUrl: map['licenseUrl'] as String? ?? '',
        homepage: map['homepage'] as String? ?? '',
        attribution: map['attribution'] as String? ?? '',
      );

  final String name;
  final String license;
  final String licenseUrl;
  final String homepage;
  final String attribution;
}

/// Les réglages des listes : catégories, liste blanche, mises à jour.
class FirewallConfig {
  const FirewallConfig({
    required this.categories,
    required this.allowlist,
    required this.autoUpdate,
    required this.lastUpdate,
    required this.lastUpdateFailed,
    required this.updating,
    required this.sources,
  });

  factory FirewallConfig.fromMap(Map<Object?, Object?> map) {
    final last = map['lastUpdate'];
    return FirewallConfig(
      categories: [
        for (final item in _list(map['categories']))
          if (item is Map) BlocklistCategory.fromMap(item),
      ],
      allowlist: _strings(map['allowlist']),
      autoUpdate: map['autoUpdate'] == true,
      lastUpdate: last is int && last > 0
          ? DateTime.fromMillisecondsSinceEpoch(last)
          : null,
      lastUpdateFailed: map['lastUpdateFailed'] == true,
      updating: map['updating'] == true,
      sources: [
        for (final item in _list(map['sources']))
          if (item is Map) BlocklistSourceInfo.fromMap(item),
      ],
    );
  }

  final List<BlocklistCategory> categories;
  final List<String> allowlist;
  final bool autoUpdate;
  final DateTime? lastUpdate; // null : listes livrées avec l'app
  final bool lastUpdateFailed;
  final bool updating;
  final List<BlocklistSourceInfo> sources;

  /// Ex : « Dernière mise à jour : 19 octobre 2026 ».
  String get updateSummary {
    final last = lastUpdate;
    final base = last == null
        ? "Listes livrées avec l'application"
        : 'Dernière mise à jour : ${formatFrenchDate(last)}';
    return lastUpdateFailed ? '$base · dernière tentative échouée' : base;
  }
}

final _asciiLabel = RegExp(r'^[a-z0-9_]([a-z0-9_-]{0,61}[a-z0-9_])?$');

/// Nettoie ce que l'utilisateur tape pour la liste blanche : accepte une
/// adresse complète (« https://www.site.fr/page ») et garde le domaine.
/// Renvoie null si ce n'est pas un domaine valide. Android refait la
/// vérification et convertit les accents (punycode).
String? normalizeDomainInput(String input) {
  var text = input.trim().toLowerCase();
  final scheme = text.indexOf('://');
  if (scheme >= 0) text = text.substring(scheme + 3);
  for (final separator in ['/', '?', '#']) {
    final index = text.indexOf(separator);
    if (index >= 0) text = text.substring(0, index);
  }
  final at = text.lastIndexOf('@');
  if (at >= 0) text = text.substring(at + 1); // « user@site.fr »
  final colon = text.indexOf(':');
  if (colon >= 0) text = text.substring(0, colon); // port
  while (text.endsWith('.')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.isEmpty || text.length > 253) return null;
  final labels = text.split('.');
  if (labels.length < 2) return null;
  if (RegExp(r'^[0-9]+$').hasMatch(labels.last)) return null; // adresse IP
  for (final label in labels) {
    if (label.isEmpty || label.length > 63) return null;
    final ascii = label.codeUnits.every((c) => c < 128);
    if (ascii && !_asciiLabel.hasMatch(label)) return null;
    // Label accentué : pas d'espace ni de ponctuation, Android convertit.
    if (!ascii && RegExp(r'[\s!-,/:-@\[-^`{-~]').hasMatch(label)) return null;
  }
  return text;
}

int _int(Object? value) => value is int ? value : 0;

List<Object?> _list(Object? value) => value is List ? value : const [];

Map<Object?, Object?> _map(Object? value) => value is Map ? value : const {};

List<String> _strings(Object? value) => [
  for (final item in _list(value))
    if (item is String) item,
];

/// Fait le lien avec FirewallChannel.kt via un MethodChannel.
class FirewallService {
  // Même nom que dans FirewallChannel.kt.
  static const _channel = MethodChannel('com.iheb.sentinel/firewall');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// null hors Android ou si Android ne répond pas.
  Future<FirewallStatus?> getStatus() async {
    final map = await _invokeMap('status');
    return map == null ? null : FirewallStatus.fromMap(map);
  }

  /// Réglages des listes ; null hors Android.
  Future<FirewallConfig?> getConfig() async {
    final map = await _invokeMap('config');
    return map == null ? null : FirewallConfig.fromMap(map);
  }

  /// Active ou coupe une catégorie ; s'applique sans redémarrer le VPN.
  Future<FirewallConfig?> setCategoryEnabled(String id, bool enabled) async {
    final map = await _invokeMap('setCategoryEnabled', {
      'id': id,
      'enabled': enabled,
    });
    return map == null ? null : FirewallConfig.fromMap(map);
  }

  /// Ajoute un domaine à la liste blanche. Renvoie le domaine enregistré
  /// (normalisé par Android), ou null s'il est refusé.
  Future<String?> addAllowed(String domain) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('addAllowed', {
        'domain': domain,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null; // domaine invalide ou liste pleine
    }
  }

  Future<void> removeAllowed(String domain) =>
      _call('removeAllowed', {'domain': domain});

  Future<void> setAutoUpdate(bool enabled) =>
      _call('setAutoUpdate', {'enabled': enabled});

  /// Télécharge les listes maintenant. true si tout a réussi.
  Future<bool> updateNow() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('updateNow') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('Pare-feu : mise à jour impossible (${e.message})');
      return false;
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

  static Future<Map<Object?, Object?>?> _invokeMap(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMapMethod<Object?, Object?>(
        method,
        arguments,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Pare-feu : $method a échoué (${e.message})');
      return null;
    }
  }

  static Future<void> _call(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Pas de code natif.
    } on PlatformException catch (e) {
      debugPrint('Pare-feu : $method a échoué (${e.message})');
    }
  }
}
