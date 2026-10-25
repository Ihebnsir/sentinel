import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentinel/services/breach/breach_checker.dart';
import 'package:sentinel/services/breach/breach_consent.dart';
import 'package:sentinel/services/breach/pwned_passwords.dart';
import 'package:sentinel/services/vault/vault_item.dart';
import 'support/l10n.dart';

// SHA-1 de « password » (vecteur connu).
const _hash = '5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8';
const _suffix = '1E4C9B93F3F0682250B6CF8331B7EE68FD8';

// Réponse type : une vraie ligne, d'autres suffixes, et du remplissage.
const _body =
    '0018A45C4D1DEF81644B54AB7F969B88D65:10\r\n'
    '$_suffix:3861\r\n'
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF:0\r\n'
    'EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE:0';

void main() {
  group('empreinte', () {
    test('SHA-1 de « password » en majuscules', () {
      expect(sha1Hex('password'), _hash);
    });

    test('découpage : 5 caractères envoyés, 35 gardés', () {
      final (prefix, suffix) = splitHash(_hash);
      expect(prefix, '5BAA6');
      expect(suffix, _suffix);
      expect(suffix.length, 35);
    });
  });

  group('lecture de la réponse', () {
    test('ignore le remplissage (nombre 0) et les lignes abîmées', () {
      final counts = parseRangeResponse('$_body\r\npas une ligne\r\n:\r\n');
      expect(counts, {
        '0018A45C4D1DEF81644B54AB7F969B88D65': 10,
        _suffix: 3861,
      });
    });
  });

  group('requête', () {
    test("n'envoie QUE les 5 premiers caractères, avec les en-têtes", () async {
      late http.Request sent;
      final client = PwnedPasswordsClient(
        client: MockClient((request) async {
          sent = request;
          return http.Response(_body, 200);
        }),
      );
      await client.breachCount('password');
      expect(sent.method, 'GET');
      expect(sent.url.toString(), 'https://api.pwnedpasswords.com/range/5BAA6');
      expect(sent.url.pathSegments.last.length, 5);
      expect(sent.headers['Add-Padding'], 'true');
      expect(sent.headers['User-Agent'], 'Sentinel-App');
      // Ni le mot de passe, ni la suite de l'empreinte (le nom du site
      // « pwnedpasswords » contient « password » : on regarde le reste).
      expect(sent.url.path, '/range/5BAA6');
      expect(sent.url.query, isEmpty);
      expect(sent.body, isEmpty);
      final headers = sent.headers.values.join(' ');
      for (final secret in ['password', _hash, _suffix]) {
        expect(headers, isNot(contains(secret)));
      }
    });

    test('mot de passe trouvé : nombre de fois vu', () async {
      final client = PwnedPasswordsClient(
        client: MockClient((_) async => http.Response(_body, 200)),
      );
      expect(await client.breachCount('password'), 3861);
    });

    test('mot de passe non trouvé : 0', () async {
      final client = PwnedPasswordsClient(
        client: MockClient((_) async => http.Response(_body, 200)),
      );
      expect(await client.breachCount('Zq9!long-et-unique-42'), 0);
    });

    test('cache par préfixe pendant une analyse', () async {
      var calls = 0;
      final client = PwnedPasswordsClient(
        client: MockClient((_) async {
          calls++;
          return http.Response(_body, 200);
        }),
      );
      await client.breachCount('password');
      await client.breachCount('password');
      expect(calls, 1);
      client.clearCache();
      await client.breachCount('password');
      expect(calls, 2);
    });
  });

  group('erreurs', () {
    Future<String> messageFor(
      MockClientHandler handler, {
      Duration timeout = PwnedPasswordsClient.defaultTimeout,
    }) async {
      final client = PwnedPasswordsClient(
        client: MockClient(handler),
        timeout: timeout,
      );
      try {
        await client.breachCount('password');
      } on BreachCheckException catch (e) {
        return e.message(fr);
      }
      fail('Une BreachCheckException était attendue');
    }

    test('pas de réseau', () async {
      expect(
        await messageFor((_) => throw http.ClientException('hors ligne')),
        contains('Pas de connexion Internet'),
      );
      expect(
        await messageFor((_) => throw const SocketException('hors ligne')),
        contains('Pas de connexion Internet'),
      );
    });

    test('délai dépassé', () async {
      expect(
        await messageFor(
          (_) => Completer<http.Response>().future, // ne répond jamais
          timeout: const Duration(milliseconds: 20),
        ),
        contains('ne répond pas'),
      );
    });

    test('erreur serveur et trop de demandes', () async {
      expect(
        await messageFor((_) async => http.Response('', 503)),
        contains('erreur 503'),
      );
      expect(
        await messageFor((_) async => http.Response('', 429)),
        contains('Trop de demandes'),
      );
    });
  });

  group('BreachChecker', () {
    late Directory dir;
    var calls = 0;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('fuites_test');
      calls = 0;
    });
    tearDown(() => dir.deleteSync(recursive: true));

    BreachChecker newChecker() => BreachChecker(
      consentStore: BreachConsentStore(directory: () async => dir),
      client: PwnedPasswordsClient(
        client: MockClient((_) async {
          calls++;
          return http.Response(_body, 200);
        }),
      ),
    );

    final items = [
      VaultItem(
        id: 'a',
        type: VaultItemType.motDePasse,
        titre: 'Mail',
        motDePasse: 'password',
        creeLe: DateTime(2026),
        modifieLe: DateTime(2026),
      ),
    ];

    test('sans accord : aucune requête', () async {
      final checker = newChecker();
      await checker.loadConsent();
      await checker.check(items);
      expect(calls, 0);
      expect(checker.countFor('password'), isNull);
    });

    test('avec accord : résultat, mémorisé, effacé au verrouillage', () async {
      final checker = newChecker();
      await checker.setConsent(true);
      await checker.check(items);
      expect(checker.countFor('password'), 3861);
      expect(checker.isUpToDate(items), isTrue);

      // L'accord est retrouvé au prochain lancement.
      final again = newChecker();
      await again.loadConsent();
      expect(again.consent, isTrue);

      checker.clear();
      expect(checker.countFor('password'), isNull);
    });

    test("retirer l'accord efface les résultats", () async {
      final checker = newChecker();
      await checker.setConsent(true);
      await checker.check(items);
      await checker.setConsent(false);
      expect(checker.countFor('password'), isNull);
      final again = newChecker();
      await again.loadConsent();
      expect(again.consent, isFalse);
    });
  });
}
