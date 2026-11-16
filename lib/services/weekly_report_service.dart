import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/debug_log.dart';

/// Compteurs qui s'additionnent pendant la semaine (liste fermée, mêmes
/// clés que WeeklyLedger.kt). Le pare-feu compte ses blocages côté Kotlin.
enum WeeklyCounter {
  messages('messages'),
  scamAlerts('scam_alerts');

  const WeeklyCounter(this.key);

  final String key;
}

/// Dernière valeur vue dans la semaine.
enum WeeklyGauge {
  riskyApps('risky_apps'),
  passwordsWeak('pw_weak'),
  passwordsReused('pw_reused'),
  passwordsBreached('pw_breached');

  const WeeklyGauge(this.key);

  final String key;
}

/// Catégories du pare-feu, dans l'ordre affiché (mêmes id que Kotlin).
const weeklyFirewallCategories = [
  'malware',
  'impersonation',
  'trackers',
  'ads',
];

/// Les compteurs d'une semaine. Que des nombres : jamais de domaine,
/// de texte de message ni de nom de réseau.
class WeekSummary {
  const WeekSummary({
    required this.start,
    this.blocked = const {},
    this.messages = 0,
    this.scamAlerts = 0,
    this.scoreStart,
    this.scoreEnd,
    this.gauges = const {},
  });

  /// Envoyé par WeeklyLedger.snapshot (Kotlin) ; valeurs inattendues ignorées.
  factory WeekSummary.fromMap(Map<Object?, Object?> map) {
    final counters = _ints(map['counters']);
    final days = map['week'];
    return WeekSummary(
      start: DateTime(1970, 1, 1 + (days is int ? days : 0)),
      blocked: {
        for (final id in weeklyFirewallCategories)
          if ((counters['blocked_$id'] ?? 0) > 0) id: counters['blocked_$id']!,
      },
      messages: counters[WeeklyCounter.messages.key] ?? 0,
      scamAlerts: counters[WeeklyCounter.scamAlerts.key] ?? 0,
      scoreStart: _score(map['scoreStart']),
      scoreEnd: _score(map['scoreEnd']),
      gauges: {
        for (final gauge in WeeklyGauge.values)
          if (_ints(map['gauges'])[gauge.key] case final int value)
            gauge: value,
      },
    );
  }

  /// Lundi de la semaine (heure locale).
  final DateTime start;

  /// Requêtes bloquées par catégorie du pare-feu (absente = 0).
  final Map<String, int> blocked;
  final int messages;
  final int scamAlerts;
  final int? scoreStart;
  final int? scoreEnd;

  /// null pour une jauge : pas mesurée cette semaine.
  final Map<WeeklyGauge, int> gauges;

  /// Dimanche de la semaine.
  DateTime get end => DateTime(start.year, start.month, start.day + 6);

  int blockedIn(String category) => blocked[category] ?? 0;

  int get blockedTotal => blocked.values.fold(0, (a, b) => a + b);

  static Map<String, int> _ints(Object? value) => {
    if (value is Map)
      for (final MapEntry(:key, :value) in value.entries)
        if (key is String && value is int && value >= 0) key: value,
  };

  static int? _score(Object? value) =>
      value is int && value >= 0 && value <= 100 ? value : null;
}

/// Semaine en cours et précédente.
class WeeklyReport {
  const WeeklyReport({required this.current, this.previous});

  factory WeeklyReport.fromMap(Map<Object?, Object?> map) {
    final current = map['current'];
    final previous = map['previous'];
    return WeeklyReport(
      current: current is Map
          ? WeekSummary.fromMap(current)
          : WeekSummary(start: DateTime.now()),
      previous: previous is Map ? WeekSummary.fromMap(previous) : null,
    );
  }

  final WeekSummary current;
  final WeekSummary? previous;
}

/// Lien avec WeeklyChannel.kt. Les envois ne lèvent jamais d'erreur :
/// le bilan ne doit pas gêner le reste de l'app.
class WeeklyReportService {
  const WeeklyReportService();

  // Même nom que dans WeeklyChannel.kt.
  static const _channel = MethodChannel('com.iheb.sentinel/weekly');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> count(WeeklyCounter counter, [int n = 1]) =>
      _call('count', {'key': counter.key, 'n': n});

  Future<void> setGauge(WeeklyGauge gauge, int value) =>
      _call('setGauge', {'key': gauge.key, 'value': value});

  Future<void> recordScore(int score) => _call('recordScore', {'score': score});

  /// null hors Android ou si Android ne répond pas.
  Future<WeeklyReport?> load() async {
    if (!isSupported) return null;
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>('snapshot');
      return map == null ? null : WeeklyReport.fromMap(map);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugLog(() => 'Bilan illisible : ${e.code}');
      return null;
    }
  }

  /// null : option indisponible (hors Android).
  Future<bool?> notificationsEnabled() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<bool>('getNotificationsEnabled');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) =>
      _call('setNotificationsEnabled', {'enabled': enabled});

  Future<void> _call(String method, Map<String, Object> args) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Aucun code natif n'écoute ce canal.
    } on PlatformException catch (e) {
      debugLog(() => 'Bilan : $method a échoué (${e.code})');
    }
  }
}
