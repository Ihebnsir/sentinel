import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/firewall_service.dart';

import 'support/l10n.dart';

// FirewallService parle à FirewallChannel.kt : ici, un faux canal joue
// le rôle d'Android pour vérifier les réponses et surtout les erreurs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.iheb.sentinel/firewall');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final service = FirewallService();

  // Appels reçus par le faux Android.
  late List<MethodCall> calls;

  void android(Object? Function(MethodCall call) answer) {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer(call);
    });
  }

  Never refuse(String code) => throw PlatformException(code: code);

  setUp(() => calls = []);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  // Rapport au format de SentinelVpnService.kt, terminé à [endedAt].
  String report(String id, DateTime endedAt) => jsonEncode({
    'formatVersion': 1,
    'id': id,
    'packageName': 'com.exemple.app',
    'startedAt': endedAt
        .subtract(const Duration(minutes: 2))
        .millisecondsSinceEpoch,
    'endedAt': endedAt.millisecondsSinceEpoch,
    'plannedMinutes': 2,
    'domains': <Object?>[],
  });

  group('sans code Android (MissingPluginException)', () {
    test('lectures : null ou vide, jamais d\'exception', () async {
      expect(await service.getStatus(), isNull);
      expect(await service.getConfig(), isNull);
      expect(await service.addAllowed('exemple.com'), isNull);
      expect(await service.updateNow(), isFalse);
      expect(await service.prepare(), isFalse);
      expect(await service.openApp('com.exemple.app'), isFalse);
      expect(await service.getReports(), isEmpty);
      expect(
        await service.startAnalysis('com.exemple.app', 2),
        AnalysisStartError.androidOnly,
      );
    });

    test('commandes : ignorées sans erreur', () async {
      await service.start();
      await service.stop();
      await service.removeAllowed('exemple.com');
      await service.setAutoUpdate(true);
      await service.setPlainDnsAllowed(false);
      await service.stopAnalysis();
      await service.deleteReport('1');
    });
  });

  group('Android répond', () {
    test('état et réglages lus depuis la Map', () async {
      android(
        (call) => switch (call.method) {
          'status' => {'active': true, 'blockedQueries': 3},
          'config' => {
            'categories': [
              {'id': 'ads', 'enabled': true, 'domains': 10},
            ],
          },
          _ => null,
        },
      );
      final status = await service.getStatus();
      expect(status!.active, isTrue);
      expect(status.blockedQueries, 3);
      final config = await service.getConfig();
      expect(config!.categories.single.id, 'ads');
    });

    test(
      'changer une catégorie envoie son id et renvoie les réglages',
      () async {
        android((call) => {'autoUpdate': true});
        final config = await service.setCategoryEnabled('trackers', false);
        expect(config!.autoUpdate, isTrue);
        expect(calls.single.arguments, {'id': 'trackers', 'enabled': false});
      },
    );

    test('commandes : nom et arguments transmis', () async {
      android((call) => null);
      await service.removeAllowed('exemple.com');
      await service.setAutoUpdate(false);
      await service.setPlainDnsAllowed(true);
      await service.deleteReport('42');
      await service.start();
      expect(
        [for (final c in calls) c.method],
        [
          'removeAllowed',
          'setAutoUpdate',
          'setPlainDnsAllowed',
          'deleteReport',
          'start',
        ],
      );
      expect(calls[0].arguments, {'domain': 'exemple.com'});
      expect(calls[2].arguments, {'allowed': true});
      expect(calls[3].arguments, {'id': '42'});
    });

    test('liste blanche : domaine normalisé par Android', () async {
      android((call) => 'exemple.com');
      expect(await service.addAllowed('WWW.Exemple.com'), 'exemple.com');
    });

    test('réponse vide d\'Android : false, pas null', () async {
      android((call) => null);
      expect(await service.updateNow(), isFalse);
      expect(await service.prepare(), isFalse);
      expect(await service.openApp('com.exemple.app'), isFalse);
    });

    test('analyse lancée : null et arguments transmis', () async {
      android((call) => null);
      expect(await service.startAnalysis('com.exemple.app', 5), isNull);
      expect(calls.single.arguments, {
        'packageName': 'com.exemple.app',
        'minutes': 5,
      });
    });
  });

  group('Android refuse (PlatformException)', () {
    test('lectures : null, false ou vide', () async {
      android((call) => refuse('ERROR'));
      expect(await service.getStatus(), isNull);
      expect(await service.getConfig(), isNull);
      expect(await service.setCategoryEnabled('ads', true), isNull);
      expect(await service.addAllowed('pas un domaine'), isNull);
      expect(await service.updateNow(), isFalse);
      expect(await service.prepare(), isFalse);
      expect(await service.openApp('com.exemple.app'), isFalse);
      expect(await service.getReports(), isEmpty);
    });

    test('commandes : l\'erreur ne remonte pas', () async {
      android((call) => refuse('ERROR'));
      await service.start();
      await service.stopAnalysis();
      expect(calls, hasLength(2));
    });

    test('analyse : chaque code donne sa raison', () async {
      const attendu = {
        'NOT_RUNNING': AnalysisStartError.firewallOff,
        'ALREADY_RUNNING': AnalysisStartError.alreadyRunning,
        'UNKNOWN_APP': AnalysisStartError.unknownApp,
        'AUTRE': AnalysisStartError.failed,
      };
      for (final MapEntry(key: code, value: erreur) in attendu.entries) {
        android((call) => refuse(code));
        expect(await service.startAnalysis('com.exemple.app', 2), erreur);
      }
    });
  });

  group('rapports', () {
    test('garde les rapports lisibles de moins de 24 h', () async {
      final now = DateTime.now();
      android(
        (call) => [
          report('récent', now.subtract(const Duration(hours: 1))),
          report('expiré', now.subtract(const Duration(hours: 25))),
          'pas du JSON',
          jsonEncode({'formatVersion': 2}), // version inconnue
          12, // pas un texte
          null,
        ],
      );
      final reports = await service.getReports();
      expect([for (final r in reports) r.id], ['récent']);
    });

    test('liste absente : aucun rapport', () async {
      android((call) => null);
      expect(await service.getReports(), isEmpty);
    });
  });

  test('chaque raison d\'échec a un message', () {
    for (final erreur in AnalysisStartError.values) {
      expect(erreur.message(fr), isNotEmpty);
    }
    expect(
      AnalysisStartError.firewallOff.message(en),
      isNot(AnalysisStartError.firewallOff.message(fr)),
    );
  });

  group('BlocklistCategory.displayName', () {
    BlocklistCategory category(String id) => BlocklistCategory(
      id: id,
      name: 'Nom envoyé par Kotlin',
      enabled: true,
      domains: 0,
      sources: const [],
    );

    test('catégories connues : nom traduit', () {
      expect(category('malware').displayName(fr), fr.categoryMalware);
      expect(category('trackers').displayName(en), en.categoryTrackers);
      expect(category('ads').displayName(ar), ar.categoryAds);
      expect(
        category('impersonation').displayName(fr),
        fr.categoryImpersonation,
      );
    });

    test('catégorie inconnue : nom reçu d\'Android', () {
      expect(category('nouvelle').displayName(fr), 'Nom envoyé par Kotlin');
    });
  });
}
