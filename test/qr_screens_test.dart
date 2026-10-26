import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/screens/messages_screen.dart';
import 'package:sentinel/screens/qr_result_screen.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/phishing/phishing_model.dart';
import 'package:sentinel/services/qr/qr_content.dart';
import 'package:sentinel/services/qr/qr_safety.dart';
import 'package:sentinel/services/qr/qr_scanner_service.dart';

import 'support/l10n.dart';

// Écran de résultat et bouton « Scanner un QR code » : un faux canal joue
// QrScanner.kt. On vérifie surtout que rien ne s'ouvre sans confirmation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKnownBrands);

  const channel = MethodChannel('com.iheb.sentinel/qr');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  void android(Object? Function(MethodCall call) answer) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer(call);
    });
  }

  setUp(() => calls = []);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  // Faux modèle : probabilité fixe.
  PredictorLoader ai(double p) =>
      () async =>
          (_) => PhishingPrediction(
            probability: p,
            suspiciousNgrams: const [],
            suspiciousWords: const [],
          );

  Future<void> showResult(
    WidgetTester tester,
    String raw, {
    double p = 0.05,
  }) async {
    // Écran haut : toute la liste est construite (boutons compris).
    tester.view.physicalSize = const Size(1080, 4000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        home: QrResultScreen(raw: raw, loadPredictor: ai(p)),
      ),
    );
    await tester.pumpAndSettle();
  }

  FilledButton button(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

  group('QrResultScreen', () {
    testWidgets('lien sain : contenu brut, puis confirmation avant d\'ouvrir', (
      tester,
    ) async {
      android((call) => null);
      await showResult(tester, 'https://www.exemple.tn');
      expect(find.text(fr.qrRawContent), findsOneWidget);
      expect(find.text('https://www.exemple.tn'), findsOneWidget);
      expect(find.text(fr.verdictNothing), findsOneWidget);

      // Annuler : rien n'est ouvert.
      await tester.tap(find.text(fr.qrActionOpenLink));
      await tester.pumpAndSettle();
      expect(find.text(fr.qrConfirmLink('https://www.exemple.tn')), findsOne);
      await tester.tap(find.text(fr.commonCancel));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);

      // Continuer : le lien part vers Android.
      await tester.tap(find.text(fr.qrActionOpenLink));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.commonContinue));
      await tester.pumpAndSettle();
      expect(calls.single.method, 'openLink');
      expect(calls.single.arguments, {'url': 'https://www.exemple.tn'});
    });

    testWidgets('arnaque probable : « Ouvrir quand même » désactivé', (
      tester,
    ) async {
      android((call) => null);
      await showResult(tester, 'http://192.168.4.1/login');
      expect(find.text(fr.verdictScam), findsOneWidget);
      expect(button(tester, fr.qrActionOpenAnyway).onPressed, isNull);
      expect(find.text(fr.qrActionBlocked), findsOneWidget);
      await tester.tap(find.text(fr.qrActionOpenAnyway));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(calls, isEmpty);
    });

    testWidgets('suspect : « Ouvrir quand même » possible', (tester) async {
      await showResult(tester, 'http://www.exemple.tn');
      expect(find.text(fr.verdictSuspect), findsOneWidget);
      expect(button(tester, fr.qrActionOpenAnyway).onPressed, isNotNull);
    });

    testWidgets('Wi-Fi ouvert : alerte, protection, aucune action', (
      tester,
    ) async {
      await showResult(tester, 'WIFI:T:nopass;S:Gare centrale;;');
      expect(find.text(fr.qrKindWifi), findsOneWidget);
      expect(find.text('Gare centrale'), findsOneWidget);
      expect(find.text(fr.wifiSecurityOpen), findsOneWidget);
      expect(find.text(fr.wifiLevelDanger), findsOneWidget);
      expect(find.text(fr.qrWarningWifiOpen), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('code USSD : appel affiché mais interdit', (tester) async {
      await showResult(tester, 'tel:*2767*3855%23');
      expect(find.text(fr.qrWarningUssd), findsOneWidget);
      expect(button(tester, fr.qrActionCall).onPressed, isNull);
    });

    testWidgets('SMS : numéro et texte affichés, confirmation', (tester) async {
      android((call) => null);
      await showResult(tester, 'SMSTO:+21698000000:Bonjour');
      expect(find.text('+21698000000'), findsOneWidget);
      await tester.tap(find.text(fr.qrActionSms));
      await tester.pumpAndSettle();
      expect(find.text(fr.qrConfirmSms('+21698000000')), findsOneWidget);
      await tester.tap(find.text(fr.commonContinue));
      await tester.pumpAndSettle();
      expect(calls.single.method, 'composeSms');
      expect(calls.single.arguments, {
        'number': '+21698000000',
        'body': 'Bonjour',
      });
    });

    testWidgets('action refusée par Android : message', (tester) async {
      android((call) => throw PlatformException(code: 'NO_APP'));
      await showResult(tester, 'tel:+21671123456');
      await tester.tap(find.text(fr.qrActionCall));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.commonContinue));
      await tester.pumpAndSettle();
      expect(find.text(fr.qrActionFailed), findsOneWidget);
    });

    testWidgets('en arabe, de droite à gauche, sans débordement', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('ar'),
          home: QrResultScreen(
            raw: 'bitcoin:bc1qxyz?amount=1',
            loadPredictor: ai(0.05),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(ar.qrKindPayment), findsOneWidget);
      expect(find.text(ar.qrActionPayment), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text(ar.qrResultTitle))),
        TextDirection.rtl,
      );
    });

    testWidgets('IA introuvable : échec affiché, aucune action', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          home: QrResultScreen(
            raw: 'https://exemple.tn',
            loadPredictor: () => Future.error(StateError('modèle absent')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(fr.messagesFailed), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('QrScannerService', () {
    final service = QrScannerService();

    test('scan : texte, annulation, erreurs', () async {
      android((call) => 'WIFI:S:X;;');
      expect((await service.scan('Visez')).text, 'WIFI:S:X;;');
      expect(calls.single.arguments, {'prompt': 'Visez'});

      android((call) => null);
      final cancelled = await service.scan('');
      expect(cancelled.text, isNull);
      expect(cancelled.error, isNull);

      const codes = {
        'NO_CAMERA': QrScanError.noCamera,
        'PERMISSION_DENIED': QrScanError.permissionDenied,
        'PERMISSION_BLOCKED': QrScanError.permissionBlocked,
        'BUSY': QrScanError.failed,
      };
      for (final MapEntry(key: code, value: error) in codes.entries) {
        android((call) => throw PlatformException(code: code));
        expect((await service.scan('')).error, error);
      }
    });

    test('sans code Android : Android seulement', () async {
      expect((await service.scan('')).error, QrScanError.androidOnly);
      expect(await service.hasCameraPermission(), isFalse);
    });

    test('action interdite : jamais envoyée à Android', () async {
      android((call) => null);
      final scam = assessQr(
        parseQr('tel:*#06#'),
        (_) => throw StateError('pas de texte'),
      );
      expect(await service.perform(scam), isFalse);
      expect(calls, isEmpty);
    });

    test('chaque erreur a un message', () {
      for (final l in [fr, en, ar]) {
        final texts = {for (final e in QrScanError.values) e.message(l)};
        expect(texts, hasLength(QrScanError.values.length));
      }
    });
  });

  group('onglet Messages', () {
    Future<void> tapScan(WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(home: const Scaffold(body: MessagesScreen())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.qrScanButton));
      await tester.pumpAndSettle();
    }

    testWidgets('explique la caméra avant de la demander ; Annuler', (
      tester,
    ) async {
      android((call) => call.method == 'hasCameraPermission' ? false : null);
      await tapScan(tester);
      expect(find.text(fr.qrCameraText), findsOneWidget);
      await tester.tap(find.text(fr.commonCancel));
      await tester.pumpAndSettle();
      expect([for (final c in calls) c.method], ['hasCameraPermission']);
    });

    testWidgets('caméra déjà permise : scan puis résultat', (tester) async {
      android(
        (call) => switch (call.method) {
          'hasCameraPermission' => true,
          'scan' => 'tel:+21671123456',
          _ => null,
        },
      );
      await tapScan(tester);
      expect(find.text(fr.qrCameraText), findsNothing);
      expect(find.text(fr.qrResultTitle), findsOneWidget);
      expect(find.text(fr.qrKindPhone), findsOneWidget);
      // Rien n'est ouvert tout seul.
      expect(calls.map((c) => c.method), isNot(contains('dial')));
    });

    testWidgets('refus définitif : message et bouton Réglages', (tester) async {
      android(
        (call) => call.method == 'scan'
            ? throw PlatformException(code: 'PERMISSION_BLOCKED')
            : true,
      );
      await tapScan(tester);
      expect(find.text(fr.qrErrorPermissionBlocked), findsOneWidget);
      expect(find.text(fr.qrOpenSettings), findsOneWidget);
    });
  });
}
