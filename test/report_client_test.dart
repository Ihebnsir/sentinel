import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentinel/app_info.dart';
import 'package:sentinel/services/phishing/message_analyzer.dart';
import 'package:sentinel/services/report/report_client.dart';

import 'support/l10n.dart';

final _server = Uri.parse('https://api.example.org');

const _report = Report(
  text: 'Colis bloqué, appelez le 98 123 456 : poste-tn.xyz/suivi?id=77',
  verdict: Verdict.arnaque,
  probability: 0.91,
  feedback: UserFeedback.arnaque,
);

ReportClient _client(
  Future<http.Response> Function(http.Request) handler, {
  Duration timeout = ReportClient.defaultTimeout,
}) => ReportClient(_server, client: MockClient(handler), timeout: timeout);

Future<ReportProblem> _problemOf(Future<void> future) async {
  try {
    await future;
  } on ReportException catch (e) {
    return e.problem;
  }
  fail('ReportException attendue');
}

void main() {
  group('Adresse du serveur', () {
    test('vide (cas de la release actuelle) : pas de signalement', () {
      expect(parseServerUrl(''), isNull);
      expect(parseServerUrl('   '), isNull);
      // Les tests sont lancés sans --dart-define : bouton masqué.
      expect(sentinelApiUrl, isEmpty);
      expect(ReportClient.fromEnvironment(), isNull);
    });

    test('HTTPS accepté, en debug comme en release', () {
      for (final debug in [true, false]) {
        expect(
          parseServerUrl('https://api.example.org', debug: debug),
          Uri.parse('https://api.example.org'),
        );
      }
    });

    test('HTTP vers 10.0.2.2 : seulement en debug', () {
      const local = 'http://10.0.2.2:8000';
      expect(parseServerUrl(local, debug: true), Uri.parse(local));
      expect(parseServerUrl(local, debug: false), isNull);
    });

    test('HTTP vers un autre serveur : refusé même en debug', () {
      for (final url in [
        'http://api.example.org',
        'http://10.0.2.20:8000',
        'http://localhost:8000',
        'http://10.0.2.2.evil.com',
      ]) {
        expect(parseServerUrl(url, debug: true), isNull, reason: url);
      }
    });

    test('adresses mal formées ou avec identifiants : refusées', () {
      for (final url in [
        'api.example.org',
        'ftp://api.example.org',
        'https://user:mdp@api.example.org',
        'https://api.example.org/?x=1',
        'https://',
      ]) {
        expect(parseServerUrl(url, debug: true), isNull, reason: url);
      }
    });

    test('le client refuse le HTTP hors debug', () {
      expect(
        () => ReportClient(Uri.parse('http://10.0.2.2:8000'), debug: false),
        throwsArgumentError,
      );
      expect(
        () => ReportClient(Uri.parse('http://api.example.org'), debug: true),
        throwsArgumentError,
      );
      // En debug, l'émulateur peut joindre le backend local.
      final local = ReportClient(Uri.parse('http://10.0.2.2:8000'), debug: true);
      expect(local.host, '10.0.2.2:8000');
      local.close();
    });
  });

  group('Envoi', () {
    test('succès (201) : bon chemin, en-têtes et champs exacts', () async {
      late http.Request sent;
      await _client((request) async {
        sent = request;
        return http.Response('{"id": "x"}', 201);
      }).send(_report);

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://api.example.org/v1/reports');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      // Exactement les champs de l'API : rien sur le téléphone.
      expect(body.keys.toSet(), {
        'text',
        'verdict',
        'probability',
        'language',
        'app_version',
        'source',
        'user_feedback',
      });
      expect(
        body['text'],
        'Colis bloqué, appelez le [TEL] : poste-tn.xyz/[CHEMIN]',
      );
      expect(sent.body, isNot(contains('98 123 456')));
      expect(body['verdict'], 'arnaque');
      expect(body['probability'], 0.91);
      expect(body['language'], 'fr');
      expect(body['app_version'], appVersion);
      expect(body['source'], 'inconnue');
      expect(body['user_feedback'], 'arnaque');
    });

    test('chemin du serveur gardé (https://…/api)', () async {
      late Uri url;
      final client = ReportClient(
        Uri.parse('https://example.org/api/'),
        client: MockClient((request) async {
          url = request.url;
          return http.Response('', 201);
        }),
      );
      await client.send(_report);
      expect(url.toString(), 'https://example.org/api/v1/reports');
    });

    test('avis envoyés avec les valeurs du serveur', () {
      expect(UserFeedback.values.map((f) => f.wire), [
        'arnaque',
        'pas_arnaque',
        'ne_sait_pas',
      ]);
    });

    final cases = {
      422: ReportProblem.rejected,
      413: ReportProblem.rejected,
      429: ReportProblem.tooMany,
      500: ReportProblem.server,
      503: ReportProblem.server,
      200: ReportProblem.server, // pas « créé » : pas enregistré
    };
    cases.forEach((status, problem) {
      test('réponse $status → ${problem.name}', () async {
        final client = _client((_) async => http.Response('{}', status));
        expect(await _problemOf(client.send(_report)), problem);
      });
    });

    test('hors ligne (pas de réseau)', () async {
      final socket = _client((_) => throw const SocketException('réseau'));
      expect(await _problemOf(socket.send(_report)), ReportProblem.offline);
      final closed = _client((_) => throw http.ClientException('fermé'));
      expect(await _problemOf(closed.send(_report)), ReportProblem.offline);
    });

    test('délai dépassé (10 s par défaut)', () async {
      expect(ReportClient.defaultTimeout, const Duration(seconds: 10));
      final never = Completer<http.Response>();
      final client = _client(
        (_) => never.future,
        timeout: const Duration(milliseconds: 20),
      );
      expect(await _problemOf(client.send(_report)), ReportProblem.timeout);
    });

    test('messages clairs dans les 3 langues', () {
      for (final l in [fr, en, ar]) {
        final messages = {
          for (final p in ReportProblem.values) ReportException(p).message(l),
        };
        expect(messages.length, ReportProblem.values.length);
        expect(messages.every((m) => m.isNotEmpty), isTrue);
      }
      expect(
        const ReportException(ReportProblem.tooMany).message(fr),
        contains('5 par heure'),
      );
    });
  });

  group('Texte final', () {
    test('anonymisé une dernière fois (numéro tapé à la relecture)', () {
      expect(Report.clean('Mon cousin : 22 33 44 55'), 'Mon cousin : [TEL]');
    });

    test('caractères de contrôle retirés, retours à la ligne gardés', () {
      expect(Report.clean('a\u0000b\u001Fc\nd\te'), 'abc\nd\te');
    });

    test('2000 caractères au plus (limite du serveur)', () {
      expect(Report.clean('a' * 2500).length, 2000);
    });
  });

  group('Langue probable', () {
    final cases = {
      'Votre colis est bloqué, payez les frais ici': 'fr',
      'Your account is locked, click here to verify': 'en',
      'تم تعليق حسابك، يرجى تأكيد بياناتك': 'ar',
      'عسلامة، ابعثلي الكود متاعك توا': 'derja_arabe',
      'Aslema sahbi, ab3athli el code taw': 'derja_latin',
      'Kallemni 3la [TEL] taw': 'derja_latin',
      '[TEL] [CODE] 2026': 'autre',
    };
    cases.forEach((text, language) {
      test('$language : $text', () => expect(guessLanguage(text), language));
    });
  });
}
