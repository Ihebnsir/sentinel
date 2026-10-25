import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/l10n/l10n.dart';
import 'package:sentinel/screens/home_screen.dart';
import 'package:sentinel/screens/messages_screen.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/phishing/phishing_model.dart';

import 'support/l10n.dart';

/// Faux Android : téléphone sans verrouillage et Wi-Fi ouvert, pour que
/// l'accueil affiche des actions et l'alerte Wi-Fi (textes des règles).
void _fakeAndroid() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.iheb.sentinel/device_security'),
    (call) async => {
      'screenLock': false,
      'biometricEnrolled': false,
      'rooted': false,
      'developerOptions': true,
      'usbDebugging': false,
      'encrypted': true,
      'androidVersion': '15',
      'sdkInt': 35,
      'securityPatch': '', // date inconnue : score stable (35)
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.iheb.sentinel/wifi'),
    (call) async => call.method == 'getWifiStatus'
        ? {'connected': true, 'security': 'open', 'sdkInt': 35}
        : null,
  );
}

TextDirection _direction(WidgetTester tester, Finder finder) =>
    Directionality.of(tester.element(finder));

Future<void> _pumpHome(WidgetTester tester, Locale locale) async {
  _fakeAndroid();
  await tester.pumpWidget(testApp(home: const HomeScreen(), locale: locale));
  await tester.pumpAndSettle(); // fin de l'animation de l'arche
}

Future<void> _analyzeScam(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    testApp(
      home: const Scaffold(body: MessagesScreen()),
      locale: locale,
    ),
  );
  await tester.enterText(
    find.byType(TextField),
    'Votre colis est bloqué, payez ici : poste-tn-livraison.xyz/p',
  );
  await tester.pump();
  await tester.tap(find.byType(FilledButton));
  // Le modèle a été chargé hors du temps simulé : on laisse passer le vrai.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Chargés une fois hors du temps simulé des tests widget.
  setUpAll(() async {
    await loadPhishingModel();
    await loadKnownBrands();
  });

  group('arabe (de droite à gauche)', () {
    const locale = Locale('ar');

    testWidgets('accueil : textes, règles du score et du Wi-Fi', (
      tester,
    ) async {
      await _pumpHome(tester, locale);

      expect(_direction(tester, find.byType(HomeScreen)), TextDirection.rtl);
      expect(find.text(ar.homeGreeting), findsOneWidget);
      expect(find.text(ar.homeTitleExposed), findsOneWidget);
      expect(find.text(ar.commonOutOf100), findsOneWidget);
      expect(find.text(ar.homeAndroidVersion('15')), findsOneWidget);
      expect(find.text(ar.homeToGainPoints), findsOneWidget);
      // Actions produites par les règles du score.
      expect(find.text(ar.scoreLockTitle), findsOneWidget);
      expect(find.text(ar.scoreDevOptionsDesc), findsOneWidget);
      // Wi-Fi ouvert : titre et niveau traduits.
      expect(find.text(ar.wifiOpenTitle), findsOneWidget);
      expect(find.text(ar.wifiLevelDanger), findsOneWidget);
      // Aucun reste de français.
      expect(find.text(fr.homeGreeting), findsNothing);
      expect(find.text(fr.scoreLockTitle), findsNothing);
      // Mise en page miroir : « مرحبًا » à droite, réglages à gauche.
      final greeting = tester.getCenter(find.text(ar.homeGreeting));
      final settings = tester.getCenter(find.byIcon(Icons.settings_outlined));
      expect(greeting.dx, greaterThan(settings.dx));
    });

    testWidgets('Messages : verdict, raisons et conseil en arabe', (
      tester,
    ) async {
      await _analyzeScam(tester, locale);

      expect(_direction(tester, find.byType(TextField)), TextDirection.rtl);
      expect(find.text(ar.navMessages), findsOneWidget);
      expect(find.text(ar.messagesAnalyze), findsOneWidget);
      expect(find.text(ar.verdictScam), findsOneWidget);
      expect(find.textContaining('احتمال الاحتيال'), findsOneWidget);
      // Raison produite par la règle sur les liens.
      expect(
        find.textContaining('«poste-tn-livraison.xyz» ينتحل صفة'),
        findsOneWidget,
      );
      expect(find.text(ar.reasonLinkTld('xyz')), findsOneWidget);
      expect(find.text(ar.adviceScam), findsOneWidget);
      expect(find.text(fr.verdictScam), findsNothing);
    });
  });

  group('anglais', () {
    const locale = Locale('en');

    testWidgets('accueil : textes, règles du score et du Wi-Fi', (
      tester,
    ) async {
      await _pumpHome(tester, locale);

      expect(_direction(tester, find.byType(HomeScreen)), TextDirection.ltr);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Your phone is at risk'), findsOneWidget);
      expect(find.text('To earn points'), findsOneWidget);
      expect(find.text('Set up a screen lock'), findsOneWidget);
      expect(find.text('Open Wi-Fi'), findsOneWidget);
      expect(find.text('Android 15'), findsOneWidget);
      expect(find.text('Install the security update'), findsOneWidget);
      expect(find.text(fr.homeGreeting), findsNothing);
    });

    testWidgets('Messages : verdict, raisons et conseil en anglais', (
      tester,
    ) async {
      await _analyzeScam(tester, locale);

      expect(find.text('Likely scam'), findsOneWidget);
      expect(find.textContaining('Scam probability:'), findsOneWidget);
      expect(
        find.textContaining('"poste-tn-livraison.xyz" imitates'),
        findsOneWidget,
      );
      expect(find.text(en.adviceScam), findsOneWidget);
      expect(find.text(fr.adviceScam), findsNothing);
    });
  });

  test('français par défaut si la langue du téléphone est absente', () {
    expect(appSupportedLocales.first, const Locale('fr'));
    expect(
      basicLocaleListResolution(const [Locale('de')], appSupportedLocales),
      const Locale('fr'),
    );
    expect(
      basicLocaleListResolution(const [
        Locale('ar', 'TN'),
      ], appSupportedLocales),
      const Locale('ar'),
    );
  });
}
