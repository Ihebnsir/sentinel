import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/screens/messages_screen.dart';
import 'package:sentinel/screens/report_screen.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/phishing/message_analyzer.dart';
import 'package:sentinel/services/phishing/phishing_model.dart';
import 'package:sentinel/services/report/report_client.dart';
import 'package:sentinel/services/report/report_limiter.dart';

import 'support/l10n.dart';

const _message =
    'Votre colis est bloqué. Appelez Ahmed au 98 123 456 ou payez ici : '
    'poste-tn-livraison.xyz/p?id=4821';
const _anonymized =
    'Votre colis est bloqué. Appelez Ahmed au [TEL] ou payez ici : '
    'poste-tn-livraison.xyz/[CHEMIN]';

const _analysis = MessageAnalysis(
  verdict: Verdict.arnaque,
  probability: 0.93,
  links: [],
);

/// Faux serveur : garde les corps reçus, répond [status].
class _FakeServer {
  _FakeServer([this.status = 201]);

  int status;
  final bodies = <Map<String, dynamic>>[];

  ReportClient client() => ReportClient(
    Uri.parse('https://api.example.org'),
    client: MockClient((request) async {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response('{}', status);
    }),
  );
}

/// Limite en mémoire (pas de fichier : tout reste dans le temps simulé).
class _MemoryLimiter extends ReportLimiter {
  int sent = 0;

  @override
  Future<bool> canSend() async => sent < limit;

  @override
  Future<void> recordSent() async => sent++;
}

void main() {
  late _MemoryLimiter limiter;

  // Écran haut : toute la liste est construite (ListView paresseuse).
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  setUp(() => limiter = _MemoryLimiter());

  Future<void> pumpScreen(
    WidgetTester tester,
    _FakeServer server, {
    Locale locale = const Locale('fr'),
  }) async {
    tallScreen(tester);
    await tester.pumpWidget(
      testApp(
        locale: locale,
        home: ReportScreen(
          text: _message,
          analysis: _analysis,
          client: server.client(),
          limiter: limiter,
        ),
      ),
    );
  }

  String preview(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const ValueKey('report-preview')))
      .controller!
      .text;

  FilledButton sendButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, fr.reportSend));

  Future<void> tapSend(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('aperçu déjà anonymisé, original jamais affiché', (
    tester,
  ) async {
    await pumpScreen(tester, _FakeServer());
    expect(preview(tester), _anonymized);
    expect(find.textContaining('98 123 456'), findsNothing);
    expect(find.text(fr.reportReminder), findsOneWidget);
    expect(find.text(fr.reportNotSentText), findsOneWidget);
    // Où part le signalement : le nom du serveur est écrit.
    expect(find.textContaining('api.example.org'), findsOneWidget);
  });

  testWidgets('« Envoyer » désactivé tant qu\'aucun avis n\'est choisi', (
    tester,
  ) async {
    await pumpScreen(tester, _FakeServer());
    expect(sendButton(tester).onPressed, isNull);
    await tester.tap(find.text(fr.reportFeedbackUnsure));
    await tester.pump();
    expect(sendButton(tester).onPressed, isNotNull);
    // Texte effacé : plus rien à envoyer.
    await tester.enterText(find.byKey(const ValueKey('report-preview')), ' ');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNull);
  });

  testWidgets('modification + choix : le texte modifié et l\'avis partent', (
    tester,
  ) async {
    final server = _FakeServer();
    await pumpScreen(tester, server);
    // L'utilisateur retire le prénom que l'anonymisation n'a pas vu.
    await tester.enterText(
      find.byKey(const ValueKey('report-preview')),
      _anonymized.replaceFirst('Ahmed ', ''),
    );
    await tester.tap(find.text(fr.reportFeedbackScam));
    await tester.pump();
    await tapSend(tester, fr.reportSend);

    expect(server.bodies, hasLength(1));
    expect(limiter.sent, 1); // compté seulement après le succès
    final body = server.bodies.single;
    expect(body['text'], isNot(contains('Ahmed')));
    expect(body['text'], startsWith('Votre colis est bloqué. Appelez au [TEL]'));
    expect(body['user_feedback'], 'arnaque');
    expect(body['verdict'], 'arnaque');
    expect(body['probability'], 0.93);
    // Écran fermé après le succès.
    expect(find.byType(ReportScreen), findsNothing);
  });

  testWidgets('avis « Ce n\'est pas une arnaque » envoyé', (tester) async {
    final server = _FakeServer();
    await pumpScreen(tester, server);
    await tester.tap(find.text(fr.reportFeedbackNotScam));
    await tester.pump();
    await tapSend(tester, fr.reportSend);
    expect(server.bodies.single['user_feedback'], 'pas_arnaque');
  });

  testWidgets('échec : message clair, écran gardé pour réessayer', (
    tester,
  ) async {
    final server = _FakeServer(429);
    await pumpScreen(tester, server);
    await tester.tap(find.text(fr.reportFeedbackScam));
    await tester.pump();
    await tapSend(tester, fr.reportSend);
    expect(find.text(fr.reportErrorTooMany), findsOneWidget);
    expect(find.byType(ReportScreen), findsOneWidget);
    // Pas de nouvel essai automatique.
    expect(server.bodies, hasLength(1));
    // L'utilisateur réessaie lui-même.
    server.status = 201;
    await tapSend(tester, fr.reportSend);
    expect(server.bodies, hasLength(2));
    expect(find.byType(ReportScreen), findsNothing);
  });

  testWidgets('limite de l\'app : 6e signalement de l\'heure bloqué', (
    tester,
  ) async {
    limiter.sent = 5;
    final server = _FakeServer();
    await pumpScreen(tester, server);
    await tester.tap(find.text(fr.reportFeedbackScam));
    await tester.pump();
    await tapSend(tester, fr.reportSend);
    expect(find.text(fr.reportErrorTooMany), findsOneWidget);
    expect(server.bodies, isEmpty); // rien n'est parti
    expect(limiter.sent, 5);
  });

  testWidgets('« Annuler » : rien n\'est envoyé', (tester) async {
    final server = _FakeServer();
    await pumpScreen(tester, server);
    await tester.tap(find.text(fr.reportFeedbackScam));
    await tester.ensureVisible(find.text(fr.commonCancel));
    await tester.tap(find.text(fr.commonCancel));
    await tester.pumpAndSettle();
    expect(server.bodies, isEmpty);
    expect(find.byType(ReportScreen), findsNothing);
  });

  testWidgets('traduit : arabe de droite à gauche, anglais', (tester) async {
    await pumpScreen(tester, _FakeServer(), locale: const Locale('ar'));
    expect(find.text(ar.reportFeedbackScam), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text(ar.reportTitle))),
      TextDirection.rtl,
    );
    await pumpScreen(tester, _FakeServer(), locale: const Locale('en'));
    expect(find.text(en.reportSend), findsOneWidget);
  });

  group('Bouton « Signaler » dans l\'onglet Messages', () {
    setUpAll(() async {
      await loadPhishingModel();
      await loadKnownBrands();
    });

    Future<void> analyze(WidgetTester tester, {ReportClient? client}) async {
      tallScreen(tester);
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: MessagesScreen(reportClient: client, reportLimiter: limiter),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), _message);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, fr.messagesAnalyze));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('URL vide : bouton masqué, note « rien n\'est envoyé »', (
      tester,
    ) async {
      await analyze(tester);
      expect(find.text(fr.reportButton), findsNothing);
      expect(find.text(fr.messagesLocalNote), findsOneWidget);
    });

    testWidgets('serveur configuré : bouton sous le résultat, puis merci', (
      tester,
    ) async {
      final server = _FakeServer();
      await analyze(tester, client: server.client());
      expect(find.text(fr.messagesLocalNoteReport), findsOneWidget);
      await tester.ensureVisible(find.text(fr.reportButton));
      await tester.tap(find.text(fr.reportButton));
      await tester.pumpAndSettle();
      expect(find.byType(ReportScreen), findsOneWidget);
      expect(preview(tester), _anonymized);

      await tester.tap(find.text(fr.reportFeedbackScam));
      await tester.pump();
      await tapSend(tester, fr.reportSend);
      expect(server.bodies, hasLength(1));
      expect(find.text(fr.reportThanks), findsOneWidget);
    });
  });
}
