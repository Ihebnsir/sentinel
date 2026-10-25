import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/app_analysis.dart';
import 'package:sentinel/services/firewall_service.dart';
import 'package:sentinel/utils/french_number.dart';
import 'support/l10n.dart';

/// Un domaine du rapport, au format envoyé par AppReport.kt.
Map<String, Object?> domain(
  String name,
  String category, {
  int count = 1,
  bool blocked = false,
  String? brand,
}) => {
  'name': name,
  'count': count,
  'category': category,
  'blocked': blocked,
  'brand': ?brand,
};

final start = DateTime(2026, 10, 19, 14, 0);

/// Un rapport comme celui écrit par SentinelVpnService.kt.
AppReport report(
  List<Map<String, Object?>> domains, {
  String label = 'TikTok',
  Duration length = const Duration(minutes: 5),
  int planned = 5,
  bool stoppedEarly = false,
}) {
  final json = jsonEncode({
    'formatVersion': 1,
    'id': '${start.millisecondsSinceEpoch}',
    'packageName': 'com.zhiliaoapp.musically',
    'appLabel': label,
    'startedAt': start.millisecondsSinceEpoch,
    'endedAt': start.add(length).millisecondsSinceEpoch,
    'plannedMinutes': planned,
    'stoppedEarly': stoppedEarly,
    'truncated': false,
    'domains': domains,
  });
  return AppReport.tryParse(json)!;
}

void main() {
  group('Regroupement du rapport', () {
    final r = report([
      domain('cdn.exemple.com', 'other', count: 3),
      domain('t.traqueur.net', 'trackers', count: 2, blocked: true),
      domain('a.traqueur.net', 'trackers', count: 9, blocked: true),
      domain('b.traqueur.net', 'trackers', count: 2),
      domain('pub.ads.net', 'ads'),
      domain(
        'poste-tn.xyz',
        'impersonation',
        blocked: true,
        brand: 'La Poste Tunisienne',
      ),
      domain('virus.xyz', 'malware', blocked: true),
      domain('bizarre.net', 'categorie-inconnue'),
    ]);

    test('ordre des catégories : dangereux, traqueurs, pubs, autres', () {
      expect(r.groups.map((g) => g.category), [
        ReportCategory.malware,
        ReportCategory.impersonation,
        ReportCategory.trackers,
        ReportCategory.ads,
        ReportCategory.other,
      ]);
    });

    test('les plus fréquents d\'abord, puis par ordre alphabétique', () {
      final trackers = r.groups.firstWhere(
        (g) => g.category == ReportCategory.trackers,
      );
      expect(trackers.domains.map((d) => d.name), [
        'a.traqueur.net',
        'b.traqueur.net',
        't.traqueur.net',
      ]);
    });

    test('catégorie inconnue rangée dans « Autres »', () {
      final other = r.groups.last;
      expect(other.domains.map((d) => d.name), [
        'cdn.exemple.com',
        'bizarre.net',
      ]);
    });

    test('compteurs et marque imitée', () {
      expect(r.countOf(ReportCategory.trackers), 3);
      expect(r.countOf(ReportCategory.ads), 1);
      expect(r.dangerousCount, 2); // malware + imitation
      final imitation = r.domains.firstWhere((d) => d.name == 'poste-tn.xyz');
      expect(imitation.brand, 'La Poste Tunisienne');
      expect(imitation.blocked, isTrue);
    });

    test('catégorie vide : pas de groupe', () {
      final only = report([domain('a.com', 'other')]);
      expect(only.groups.map((g) => g.category), [ReportCategory.other]);
    });
  });

  group('Phrase de résumé', () {
    List<Map<String, Object?>> many(int n, String category, String prefix) => [
      for (var i = 0; i < n; i++) domain('$prefix$i.net', category),
    ];

    test('exemple de la demande : traqueurs seulement', () {
      final r = report([
        ...many(18, 'trackers', 't'),
        ...many(29, 'other', 'o'),
      ]);
      expect(r.summary(fr), 'TikTok a contacté 47 domaines, dont 18 traqueurs.');
    });

    test('dangereux, traqueurs et publicités', () {
      final r = report([
        ...many(1, 'malware', 'm'),
        ...many(1, 'impersonation', 'i'),
        ...many(1, 'trackers', 't'),
        ...many(5, 'ads', 'a'),
      ]);
      expect(
        r.summary(fr),
        'TikTok a contacté 8 domaines, dont 2 sites dangereux, '
        '1 traqueur et 5 publicités.',
      );
    });

    test('singuliers', () {
      final r = report([domain('a.ads.net', 'ads')], label: 'Météo');
      expect(r.summary(fr), 'Météo a contacté 1 domaine, dont 1 publicité.');
      final danger = report([domain('virus.xyz', 'malware')]);
      expect(danger.summary(fr), contains('dont 1 site dangereux.'));
    });

    test('rien de connu', () {
      final r = report([domain('a.com', 'other'), domain('b.com', 'other')]);
      expect(
        r.summary(fr),
        'TikTok a contacté 2 domaines, aucun connu comme traqueur, '
        'publicité ou site dangereux.',
      );
    });

    test('aucun domaine', () {
      expect(
        report(const []).summary(fr),
        "TikTok n'a contacté aucun domaine pendant l'analyse.",
      );
    });

    test('grands nombres à la française', () {
      final r = report(many(1200, 'trackers', 't'));
      // Espace insécable entre les milliers (formatFrenchNumber).
      final n = formatFrenchNumber(1200);
      expect(n, isNot('1200'));
      expect(r.summary(fr), 'TikTok a contacté $n domaines, dont $n traqueurs.');
    });
  });

  group('Expiration à 24 h', () {
    final r = report(const []); // fin à 14 h 05
    final end = start.add(const Duration(minutes: 5));

    test('expire 24 h après la fin de l\'analyse', () {
      expect(r.expiresAt, end.add(const Duration(hours: 24)));
      expect(reportMaxAge, const Duration(hours: 24));
    });

    test('limites', () {
      expect(r.isExpiredAt(end), isFalse);
      expect(
        r.isExpiredAt(end.add(const Duration(hours: 23, minutes: 59))),
        isFalse,
      );
      expect(r.isExpiredAt(end.add(const Duration(hours: 24))), isTrue);
      expect(r.isExpiredAt(end.add(const Duration(days: 3))), isTrue);
    });

    test('horloge du téléphone reculée de plus de 24 h : expiré', () {
      expect(r.isExpiredAt(end.subtract(const Duration(hours: 25))), isTrue);
    });
  });

  group('Lecture du rapport', () {
    test('analyse menée jusqu\'au bout : durée prévue', () {
      expect(report(const []).durationLabel(fr), '5 min');
      // Fin un peu tardive (réveil d'Android) : pas « 3 min ».
      final late = report(
        const [],
        length: const Duration(minutes: 2, milliseconds: 200),
        planned: 2,
      );
      expect(late.durationLabel(fr), '2 min');
    });

    test('analyse arrêtée avant la fin : durée réelle', () {
      String early(Duration length, {int planned = 2}) => report(
            const [],
            length: length,
            planned: planned,
            stoppedEarly: true,
          ).durationLabel(fr);
      expect(
        early(const Duration(minutes: 1, seconds: 40)),
        '1 min 40 s (arrêtée avant les 2 min prévues)',
      );
      expect(
        early(const Duration(minutes: 3), planned: 15),
        '3 min (arrêtée avant les 15 min prévues)',
      );
      expect(
        early(const Duration(seconds: 45, milliseconds: 900)),
        '45 s (arrêtée avant les 2 min prévues)',
      );
      expect(early(Duration.zero), startsWith("moins d'1 s"));
      // Heure du téléphone reculée pendant l'analyse : pas de durée négative.
      expect(early(const Duration(seconds: -30)), startsWith("moins d'1 s"));
    });

    test('texte illisible ou version inconnue : ignoré', () {
      expect(AppReport.tryParse('pas du json'), isNull);
      expect(AppReport.tryParse('{"formatVersion": 2}'), isNull);
      expect(AppReport.tryParse('[]'), isNull);
    });

    test('durées proposées (comme AnalysisSession.kt)', () {
      expect(analysisMinutes, [2, 5, 15]);
    });
  });

  group('Analyse en cours', () {
    test('lue dans l\'état du pare-feu', () {
      final status = FirewallStatus.fromMap({
        'active': true,
        'totalQueries': 3,
        'blockedQueries': 0,
        'analysis': {
          'packageName': 'com.exemple',
          'appLabel': 'Exemple',
          'startedAt': 0,
          'endsAt': start.millisecondsSinceEpoch,
          'domains': 12,
        },
      });
      final analysis = status.analysis!;
      expect(analysis.appLabel, 'Exemple');
      expect(
        analysis.progressAt(fr, 
          start.subtract(const Duration(minutes: 2, seconds: 30)),
        ),
        'Reste 3 min · 12 domaines vus',
      );
      expect(
        analysis.progressAt(fr, start.add(const Duration(seconds: 5))),
        "Reste moins d'1 min · 12 domaines vus",
      );
    });

    test('absente ou invalide : null', () {
      expect(FirewallStatus.fromMap({'active': true}).analysis, isNull);
      expect(
        FirewallStatus.fromMap({
          'analysis': {'packageName': 3},
        }).analysis,
        isNull,
      );
    });
  });

  group('Catégorie « Imitations de marques »', () {
    test('sous-titre : marques surveillées, sans sources', () {
      final category = BlocklistCategory.fromMap({
        'id': 'impersonation',
        'name': 'Imitations de marques',
        'enabled': true,
        'domains': 22,
        'sources': <String>[],
      });
      expect(category.isBrandRule, isTrue);
      expect(
        category.subtitle(fr),
        '22 marques surveillées · sites qui les imitent',
      );
    });
  });
}
