import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/firewall_service.dart';

void main() {
  group('FirewallStatus : compteurs par catégorie', () {
    test('lit blockedByCategory et listsLoading', () {
      final status = FirewallStatus.fromMap({
        'active': true,
        'blockedByCategory': {'malware': 3, 'trackers': 40, 'ads': 'x'},
        'listsLoading': true,
      });
      expect(status.blockedByCategory, {
        'malware': 3,
        'trackers': 40,
        'ads': 0,
      });
      expect(status.listsLoading, isTrue);
    });

    test('ancienne Map sans détail : vide', () {
      final status = FirewallStatus.fromMap({'active': true});
      expect(status.blockedByCategory, isEmpty);
      expect(status.listsLoading, isFalse);
    });
  });

  group('FirewallConfig.fromMap', () {
    final map = <Object?, Object?>{
      'categories': [
        {
          'id': 'malware',
          'name': 'Malware et hameçonnage',
          'enabled': true,
          'domains': 430961,
          'sources': ['Phishing.Database', 'ShadowWhisperer'],
        },
        {
          'id': 'ads',
          'name': 'Publicités',
          'enabled': false,
          'domains': 1,
          'sources': <Object?>[],
        },
        'pas une map',
      ],
      'allowlist': ['exemple.fr', 42],
      'autoUpdate': true,
      'lastUpdate': DateTime(2026, 10, 19, 8).millisecondsSinceEpoch,
      'lastUpdateFailed': false,
      'updating': false,
      'sources': [
        {
          'name': 'AdAway',
          'license': 'CC BY 3.0',
          'licenseUrl': 'https://creativecommons.org/licenses/by/3.0/',
          'homepage': 'https://github.com/AdAway/adaway.github.io',
          'attribution': 'AdAway default blocklist…',
        },
      ],
    };

    test('lit catégories, liste blanche, mises à jour et sources', () {
      final config = FirewallConfig.fromMap(map);
      expect(config.categories, hasLength(2));
      expect(config.categories.first.id, 'malware');
      expect(config.categories.first.enabled, isTrue);
      expect(config.categories.last.enabled, isFalse);
      expect(config.allowlist, ['exemple.fr']);
      expect(config.autoUpdate, isTrue);
      expect(config.lastUpdate, DateTime(2026, 10, 19, 8));
      expect(config.sources.single.license, 'CC BY 3.0');
    });

    test('sous-titre de catégorie : nombre et sources', () {
      final config = FirewallConfig.fromMap(map);
      // Espace insécable entre les milliers.
      expect(
        config.categories.first.subtitle,
        '430 961 domaines · Phishing.Database, ShadowWhisperer',
      );
      expect(config.categories.last.subtitle, '1 domaine');
    });

    test('résumé de mise à jour', () {
      expect(
        FirewallConfig.fromMap(map).updateSummary,
        'Dernière mise à jour : 19 octobre 2026',
      );
      final never = FirewallConfig.fromMap({'lastUpdateFailed': true});
      expect(
        never.updateSummary,
        "Listes livrées avec l'application · dernière tentative échouée",
      );
    });

    test('Map vide : valeurs par défaut sûres', () {
      final config = FirewallConfig.fromMap({});
      expect(config.categories, isEmpty);
      expect(config.allowlist, isEmpty);
      expect(config.autoUpdate, isFalse); // désactivé par défaut
      expect(config.lastUpdate, isNull);
      expect(config.sources, isEmpty);
    });
  });

  group('normalizeDomainInput (liste blanche)', () {
    test('garde le domaine d’une adresse complète', () {
      expect(normalizeDomainInput('  Exemple.FR  '), 'exemple.fr');
      expect(
        normalizeDomainInput('https://www.site.fr/page?x=1'),
        'www.site.fr',
      );
      expect(normalizeDomainInput('site.fr:8443'), 'site.fr');
      expect(normalizeDomainInput('site.fr.'), 'site.fr');
    });

    test('accents acceptés (Android convertit en punycode)', () {
      expect(normalizeDomainInput('café.fr'), 'café.fr');
    });

    test('refuse ce qui n’est pas un domaine', () {
      for (final bad in [
        '',
        'localhost',
        '192.168.1.1',
        'deux mots.fr',
        '-debut.fr',
        'a..b.fr',
        'sit€!.fr',
        '${'x' * 64}.fr',
      ]) {
        expect(normalizeDomainInput(bad), isNull, reason: bad);
      }
    });
  });
}
