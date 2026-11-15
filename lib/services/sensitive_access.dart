import 'package:flutter/foundation.dart';

// « Accès sensibles » : logique pure (sans écran ni Android), testée dans
// test/sensitive_access_test.dart.
//
// Android ne donne pas aux apps l'historique réel caméra / micro /
// localisation des autres apps (réservé au système). On croise donc :
// - les autorisations accordées (PackageManager) ;
// - les moments où l'app était ouverte ou active en arrière-plan
//   (UsageStatsManager, autorisation « Accès aux données d'utilisation »).
// Résultat : des moments où l'app POUVAIT utiliser l'accès, pas une preuve.

/// Les trois accès suivis.
enum SensitiveSensor { camera, microphone, location }

/// Événement d'utilisation, tel que traduit par SensitiveAccessReader.kt.
/// L'ordre suit les codes envoyés par Kotlin (0, 1, 2, 3).
enum UsageEventKind { foreground, background, serviceStart, serviceStop }

@immutable
class UsageEvent {
  const UsageEvent(this.time, this.kind);

  final DateTime time;
  final UsageEventKind kind;
}

/// Une app avec au moins un accès sensible autorisé, et ses événements.
@immutable
class SensitiveAccessApp {
  const SensitiveAccessApp({
    required this.packageName,
    required this.label,
    this.icon,
    this.isSystemApp = false,
    required this.sensors,
    this.backgroundLocation = false,
    this.events = const [],
  });

  /// Construit l'objet à partir de la Map reçue du MethodChannel.
  factory SensitiveAccessApp.fromMap(Map<Object?, Object?> map) {
    final packageName = map['packageName'] as String? ?? '';
    final icon = map['icon'];
    final sensors = map['sensors'];
    final times = map['eventTimes'];
    final kinds = map['eventKinds'];
    final events = <UsageEvent>[];
    if (times is List && kinds is List) {
      for (var i = 0; i < times.length && i < kinds.length; i++) {
        final t = times[i];
        final k = kinds[i];
        // Code inconnu (version future) : ignoré.
        if (t is! int || k is! int || k < 0) continue;
        if (k >= UsageEventKind.values.length) continue;
        events.add(
          UsageEvent(
            DateTime.fromMillisecondsSinceEpoch(t),
            UsageEventKind.values[k],
          ),
        );
      }
    }
    return SensitiveAccessApp(
      packageName: packageName,
      label: map['label'] as String? ?? packageName,
      icon: icon is Uint8List ? icon : null,
      isSystemApp: map['isSystemApp'] == true,
      sensors: {
        if (sensors is List)
          for (final s in sensors)
            for (final v in SensitiveSensor.values)
              if (v.name == s) v,
      },
      backgroundLocation: map['backgroundLocation'] == true,
      events: List.unmodifiable(events),
    );
  }

  final String packageName;
  final String label;
  final Uint8List? icon;
  final bool isSystemApp;
  final Set<SensitiveSensor> sensors; // autorisations accordées
  final bool backgroundLocation; // localisation « toujours » autorisée
  final List<UsageEvent> events;
}

/// App ouverte à l'écran, ou active en arrière-plan (service).
enum SessionKind { foreground, background }

/// Un moment d'activité de l'app.
@immutable
class UsageSession {
  const UsageSession(this.start, this.end, this.kind);

  final DateTime start;
  final DateTime end;
  final SessionKind kind;

  /// Chevauche la nuit (00 h – 06 h, heure du téléphone).
  bool get atNight => overlapsNight(start, end);

  @override
  bool operator ==(Object other) =>
      other is UsageSession &&
      other.start == start &&
      other.end == end &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(start, end, kind);

  @override
  String toString() => 'UsageSession($start → $end, ${kind.name})';
}

/// Pourquoi une app mérite d'être regardée.
enum UnusualReason {
  /// Active entre 00 h et 06 h.
  night,

  /// Active en arrière-plan alors que caméra ou micro sont autorisés.
  backgroundCameraMic,
}

/// Période analysée : ce qu'Android garde, au plus 7 jours.
const accessWindow = Duration(days: 7);

/// Deux moments séparés de moins d'une minute n'en font qu'un
/// (changement d'écran dans l'app, rotation…).
const mergeGap = Duration(minutes: 1);

/// Vrai si [start, end) touche une plage 00 h – 06 h.
bool overlapsNight(DateTime start, DateTime end) {
  var day = DateTime(start.year, start.month, start.day);
  while (day.isBefore(end)) {
    final nightEnd = DateTime(day.year, day.month, day.day, 6);
    if (start.isBefore(nightEnd) && end.isAfter(day)) return true;
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return false;
}

typedef _Span = ({DateTime start, DateTime end});

/// Transforme les événements en moments d'activité, du plus récent au
/// plus ancien, limités à [from, now].
List<UsageSession> buildSessions(
  List<UsageEvent> events,
  DateTime from,
  DateTime now,
) {
  final sorted = [...events]..sort((a, b) => a.time.compareTo(b.time));
  final foreground = _merge(_foregroundSpans(sorted, from, now));
  final services = _merge(_serviceSpans(sorted, from, now));
  final sessions = <UsageSession>[
    for (final s in foreground)
      UsageSession(s.start, s.end, SessionKind.foreground),
    // Arrière-plan : service actif pendant que l'app n'est pas à l'écran.
    for (final s in _subtract(services, foreground))
      UsageSession(s.start, s.end, SessionKind.background),
  ];
  return [
    for (final s in sessions)
      if (s.end.isAfter(from) && s.start.isBefore(now))
        UsageSession(
          s.start.isBefore(from) ? from : s.start,
          s.end.isAfter(now) ? now : s.end,
          s.kind,
        ),
  ]..sort((a, b) => b.start.compareTo(a.start));
}

// Ouverture → fermeture. Une fermeture sans ouverture, en tout premier :
// l'app était déjà ouverte au début de la période.
List<_Span> _foregroundSpans(
  List<UsageEvent> events,
  DateTime from,
  DateTime now,
) {
  final spans = <_Span>[];
  DateTime? open;
  var seen = false;
  for (final e in events) {
    if (e.kind == UsageEventKind.foreground) {
      open ??= e.time;
      seen = true;
    } else if (e.kind == UsageEventKind.background) {
      if (open != null) {
        spans.add((start: open, end: e.time));
        open = null;
      } else if (!seen) {
        spans.add((start: from, end: e.time));
      }
      seen = true;
    }
  }
  if (open != null) spans.add((start: open, end: now));
  return spans;
}

// Services au premier plan : plusieurs peuvent tourner en même temps.
List<_Span> _serviceSpans(
  List<UsageEvent> events,
  DateTime from,
  DateTime now,
) {
  final spans = <_Span>[];
  DateTime? open;
  var running = 0;
  var seen = false;
  for (final e in events) {
    if (e.kind == UsageEventKind.serviceStart) {
      if (running == 0) open = e.time;
      running++;
      seen = true;
    } else if (e.kind == UsageEventKind.serviceStop) {
      if (running > 0) {
        running--;
        if (running == 0) spans.add((start: open!, end: e.time));
      } else if (!seen) {
        spans.add((start: from, end: e.time));
      }
      seen = true;
    }
  }
  if (running > 0) spans.add((start: open!, end: now));
  return spans;
}

/// Trie et fusionne les plages qui se touchent ou sont proches.
List<_Span> _merge(List<_Span> spans) {
  final sorted = [...spans]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <_Span>[];
  for (final s in sorted) {
    if (!s.end.isAfter(s.start)) continue;
    if (merged.isNotEmpty && !s.start.isAfter(merged.last.end.add(mergeGap))) {
      final last = merged.removeLast();
      merged.add((
        start: last.start,
        end: s.end.isAfter(last.end) ? s.end : last.end,
      ));
    } else {
      merged.add(s);
    }
  }
  return merged;
}

/// [spans] moins [holes] (les deux triées et fusionnées).
List<_Span> _subtract(List<_Span> spans, List<_Span> holes) {
  final result = <_Span>[];
  for (final s in spans) {
    var start = s.start;
    for (final h in holes) {
      if (!h.end.isAfter(start) || !h.start.isBefore(s.end)) continue;
      if (h.start.isAfter(start)) result.add((start: start, end: h.start));
      if (h.end.isAfter(start)) start = h.end;
    }
    if (s.end.isAfter(start)) result.add((start: start, end: s.end));
  }
  return result;
}

/// Résumé affiché pour une app.
@immutable
class AppAccessSummary {
  const AppAccessSummary({
    required this.app,
    required this.sessions,
    required this.count24h,
    required this.reasons,
  });

  final SensitiveAccessApp app;
  final List<UsageSession> sessions; // du plus récent au plus ancien
  final int count24h;
  final Set<UnusualReason> reasons;

  int get count7d => sessions.length;
  DateTime? get lastUse => sessions.isEmpty ? null : sessions.first.end;
  int get nightCount => sessions.where((s) => s.atNight).length;
  int get backgroundCount =>
      sessions.where((s) => s.kind == SessionKind.background).length;
  bool get unusual => reasons.isNotEmpty;
}

/// Résume une app sur les 7 derniers jours.
AppAccessSummary summarizeApp(SensitiveAccessApp app, DateTime now) {
  final sessions = buildSessions(app.events, now.subtract(accessWindow), now);
  final dayStart = now.subtract(const Duration(hours: 24));
  final cameraOrMic =
      app.sensors.contains(SensitiveSensor.camera) ||
      app.sensors.contains(SensitiveSensor.microphone);
  return AppAccessSummary(
    app: app,
    sessions: List.unmodifiable(sessions),
    count24h: sessions.where((s) => s.end.isAfter(dayStart)).length,
    reasons: {
      if (sessions.any((s) => s.atNight)) UnusualReason.night,
      if (cameraOrMic && sessions.any((s) => s.kind == SessionKind.background))
        UnusualReason.backgroundCameraMic,
    },
  );
}

/// Apps à afficher : actives ces 7 jours, ou localisation « toujours ».
/// Tri : inhabituelles d'abord (plus de raisons en tête), puis la plus
/// récente activité, puis le nom.
List<AppAccessSummary> summarizeAccess(
  Iterable<SensitiveAccessApp> apps,
  DateTime now,
) {
  final summaries = [
    for (final app in apps)
      if (app.sensors.isNotEmpty) summarizeApp(app, now),
  ].where((s) => s.sessions.isNotEmpty || s.app.backgroundLocation).toList();
  summaries.sort((a, b) {
    final byReasons = b.reasons.length.compareTo(a.reasons.length);
    if (byReasons != 0) return byReasons;
    final aLast = a.lastUse;
    final bLast = b.lastUse;
    if (aLast != bLast) {
      if (aLast == null) return 1;
      if (bLast == null) return -1;
      return bLast.compareTo(aLast);
    }
    return a.app.label.toLowerCase().compareTo(b.app.label.toLowerCase());
  });
  return summaries;
}
