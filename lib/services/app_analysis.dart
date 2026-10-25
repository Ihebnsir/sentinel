import 'dart:convert';

import '../l10n/l10n.dart';

/// Durée de conservation d'un rapport (même valeur que AppReportStore.kt).
const reportMaxAge = Duration(hours: 24);

/// Durées proposées pour une analyse (même liste que AnalysisSession.kt).
const analysisMinutes = [2, 5, 15];

/// Catégorie d'un domaine dans le rapport, dans l'ordre d'affichage.
enum ReportCategory {
  malware('malware', dangerous: true),
  impersonation('impersonation', dangerous: true),
  trackers('trackers'),
  ads('ads'),
  other('other');

  const ReportCategory(this.id, {this.dangerous = false});

  final String id; // identifiant envoyé par Kotlin
  final bool dangerous;

  String label(AppLocalizations l) => switch (this) {
    malware => l.categoryMalware,
    impersonation => l.categoryImpersonation,
    trackers => l.categoryTrackers,
    ads => l.categoryAds,
    other => l.categoryOther,
  };

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
  String durationLabel(AppLocalizations l) {
    final planned = l.durationMinutes(plannedMinutes, l.number(plannedMinutes));
    if (!stoppedEarly) return planned;
    return l.reportStoppedEarly(_formatDuration(l, duration), planned);
  }

  // « 1 min 40 s », « 3 min », « 45 s » : secondes arrondies vers le bas.
  static String _formatDuration(AppLocalizations l, Duration d) {
    final seconds = d.isNegative ? 0 : d.inSeconds;
    if (seconds < 1) return l.durationLessThanSecond;
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes == 0) return l.durationSeconds('$rest');
    return rest == 0
        ? l.durationMinutesOnly('$minutes')
        : l.durationMinutesSeconds('$minutes', '$rest');
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
  String summary(AppLocalizations l) {
    final total = domains.length;
    if (total == 0) return l.reportNoDomain(appLabel);
    final domainsText = l.domainsCount(total, l.number(total));
    final start = l.reportContacted(appLabel, domainsText);
    final trackers = countOf(ReportCategory.trackers);
    final ads = countOf(ReportCategory.ads);
    final parts = [
      if (dangerousCount > 0)
        l.reportDangerousCount(dangerousCount, l.number(dangerousCount)),
      if (trackers > 0) l.reportTrackersCount(trackers, l.number(trackers)),
      if (ads > 0) l.reportAdsCount(ads, l.number(ads)),
    ];
    if (parts.isEmpty) return l.reportNothingKnown(start);
    return l.reportIncluding(start, _join(l, parts));
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
  String progressAt(AppLocalizations l, DateTime now) {
    final left = endsAt.difference(now);
    final minutes = left.isNegative ? 0 : (left.inSeconds / 60).ceil();
    final time = minutes <= 1
        ? l.analysisLessThanMinuteLeft
        : l.analysisMinutesLeft(minutes, l.number(minutes));
    return '$time · ${l.analysisDomainsSeen(domains, l.number(domains))}';
  }
}

// « a », « a et b », « a, b et c ».
String _join(AppLocalizations l, List<String> parts) => parts.length == 1
    ? parts.single
    : parts.sublist(0, parts.length - 1).join(l.listSeparator) +
          l.listLastSeparator +
          parts.last;
