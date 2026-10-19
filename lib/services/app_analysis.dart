import 'dart:convert';

import '../utils/french_number.dart';

/// Durée de conservation d'un rapport (même valeur que AppReportStore.kt).
const reportMaxAge = Duration(hours: 24);

/// Durées proposées pour une analyse (même liste que AnalysisSession.kt).
const analysisMinutes = [2, 5, 15];

/// Catégorie d'un domaine dans le rapport, dans l'ordre d'affichage.
enum ReportCategory {
  malware('malware', 'Malware et hameçonnage', dangerous: true),
  impersonation('impersonation', 'Imitations de marques', dangerous: true),
  trackers('trackers', 'Traqueurs'),
  ads('ads', 'Publicités'),
  other('other', 'Autres domaines');

  const ReportCategory(this.id, this.label, {this.dangerous = false});

  final String id; // identifiant envoyé par Kotlin
  final String label;
  final bool dangerous;

  static ReportCategory fromId(Object? id) =>
      values.firstWhere((c) => c.id == id, orElse: () => other);
}

/// Un domaine demandé par l'app pendant l'analyse.
class ReportDomain {
  const ReportDomain({
    required this.name,
    required this.count,
    required this.category,
    required this.blocked,
    this.brand,
  });

  factory ReportDomain.fromMap(Map<String, Object?> map) => ReportDomain(
    name: map['name'] as String? ?? '',
    count: map['count'] as int? ?? 0,
    category: ReportCategory.fromId(map['category']),
    blocked: map['blocked'] == true,
    brand: map['brand'] as String?,
  );

  final String name;
  final int count; // nombre de requêtes DNS
  final ReportCategory category;
  final bool blocked; // bloqué au moins une fois par le pare-feu
  final String? brand; // marque imitée (catégorie imitation)
}

/// Les domaines d'une même catégorie, les plus fréquents d'abord.
class ReportGroup {
  const ReportGroup(this.category, this.domains);

  final ReportCategory category;
  final List<ReportDomain> domains;
}

/// Rapport « Analyser une application », écrit par SentinelVpnService.kt.
class AppReport {
  const AppReport({
    required this.id,
    required this.packageName,
    required this.appLabel,
    required this.startedAt,
    required this.endedAt,
    required this.plannedMinutes,
    required this.stoppedEarly,
    required this.truncated,
    required this.domains,
  });

  factory AppReport.fromMap(Map<String, Object?> map) {
    if (map['formatVersion'] != 1) {
      throw const FormatException('Rapport : version inconnue');
    }
    final packageName = map['packageName'] as String;
    return AppReport(
      id: map['id'] as String,
      packageName: packageName,
      appLabel: map['appLabel'] as String? ?? packageName,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
      endedAt: DateTime.fromMillisecondsSinceEpoch(map['endedAt'] as int),
      plannedMinutes: map['plannedMinutes'] as int? ?? 0,
      stoppedEarly: map['stoppedEarly'] == true,
      truncated: map['truncated'] == true,
      domains: List.unmodifiable([
        for (final item in map['domains'] as List? ?? const [])
          if (item is Map) ReportDomain.fromMap(item.cast<String, Object?>()),
      ]),
    );
  }

  /// null si le texte n'est pas un rapport lisible.
  static AppReport? tryParse(String json) {
    try {
      return AppReport.fromMap(jsonDecode(json) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  final String id;
  final String packageName;
  final String appLabel;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedMinutes;
  final bool stoppedEarly; // arrêtée avant la fin prévue
  final bool truncated; // trop de domaines : liste incomplète
  final List<ReportDomain> domains;

  /// Le rapport est supprimé 24 h après la fin de l'analyse.
  DateTime get expiresAt => endedAt.add(reportMaxAge);

  bool isExpiredAt(DateTime now) =>
      !now.isBefore(expiresAt) || endedAt.isAfter(now.add(reportMaxAge));

  Duration get duration => endedAt.difference(startedAt);

  /// Ex : « 5 min » (durée prévue, analyse menée jusqu'au bout) ou
  /// « 1 min 40 s (arrêtée avant les 2 min prévues) » (durée réelle).
  String get durationLabel => stoppedEarly
      ? '${_formatDuration(duration)} '
          '(arrêtée avant les $plannedMinutes min prévues)'
      : '$plannedMinutes min';

  // « 1 min 40 s », « 3 min », « 45 s » : secondes arrondies vers le bas.
  static String _formatDuration(Duration d) {
    final seconds = d.isNegative ? 0 : d.inSeconds;
    if (seconds < 1) return "moins d'1 s";
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes == 0) return '$rest s';
    return rest == 0 ? '$minutes min' : '$minutes min $rest s';
  }

  int countOf(ReportCategory category) =>
      domains.where((d) => d.category == category).length;

  int get dangerousCount => domains.where((d) => d.category.dangerous).length;

  /// Groupes non vides, dans l'ordre de [ReportCategory].
  List<ReportGroup> get groups {
    final result = <ReportGroup>[];
    for (final category in ReportCategory.values) {
      final list = _sorted(category);
      if (list.isNotEmpty) result.add(ReportGroup(category, list));
    }
    return result;
  }

  List<ReportDomain> _sorted(ReportCategory category) {
    final list = domains.where((d) => d.category == category).toList();
    list.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
    return list;
  }

  /// Ex : « TikTok a contacté 47 domaines, dont 18 traqueurs. »
  String get summary {
    final total = domains.length;
    if (total == 0) {
      return "$appLabel n'a contacté aucun domaine pendant l'analyse.";
    }
    final start = '$appLabel a contacté ${_plural(total, 'domaine')}';
    final parts = [
      if (dangerousCount > 0)
        _plural(dangerousCount, 'site dangereux', 'sites dangereux'),
      if (countOf(ReportCategory.trackers) > 0)
        _plural(countOf(ReportCategory.trackers), 'traqueur'),
      if (countOf(ReportCategory.ads) > 0)
        _plural(countOf(ReportCategory.ads), 'publicité'),
    ];
    if (parts.isEmpty) {
      return '$start, aucun connu comme traqueur, publicité ou site dangereux.';
    }
    return '$start, dont ${_joinFrench(parts)}.';
  }
}

/// L'analyse en cours, lue dans l'état du pare-feu.
class AnalysisStatus {
  const AnalysisStatus({
    required this.packageName,
    required this.appLabel,
    required this.endsAt,
    required this.domains,
  });

  static AnalysisStatus? fromMap(Object? value) {
    if (value is! Map) return null;
    final packageName = value['packageName'];
    final endsAt = value['endsAt'];
    if (packageName is! String || endsAt is! int) return null;
    return AnalysisStatus(
      packageName: packageName,
      appLabel: value['appLabel'] as String? ?? packageName,
      endsAt: DateTime.fromMillisecondsSinceEpoch(endsAt),
      domains: value['domains'] as int? ?? 0,
    );
  }

  final String packageName;
  final String appLabel;
  final DateTime endsAt;
  final int domains; // domaines différents vus jusqu'ici

  /// Ex : « Reste 3 min · 12 domaines vus ».
  String progressAt(DateTime now) {
    final left = endsAt.difference(now);
    final minutes = left.isNegative ? 0 : (left.inSeconds / 60).ceil();
    final time = minutes <= 1 ? "Reste moins d'1 min" : 'Reste $minutes min';
    final seen = domains > 1 ? 'domaines vus' : 'domaine vu';
    return '$time · ${formatFrenchNumber(domains)} $seen';
  }
}

String _plural(int n, String singular, [String? plural]) =>
    '${formatFrenchNumber(n)} ${n > 1 ? plural ?? '${singular}s' : singular}';

// « a », « a et b », « a, b et c ».
String _joinFrench(List<String> parts) => parts.length == 1
    ? parts.single
    : '${parts.sublist(0, parts.length - 1).join(', ')} et ${parts.last}';
