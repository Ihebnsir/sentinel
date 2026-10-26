import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/models/installed_app.dart';
import 'package:sentinel/screens/app_detail_screen.dart';
import 'package:sentinel/screens/app_report_screen.dart';
import 'package:sentinel/screens/firewall_screen.dart';
import 'package:sentinel/screens/home_screen.dart';
import 'package:sentinel/screens/messages_screen.dart';
import 'package:sentinel/screens/onboarding_screen.dart';
import 'package:sentinel/screens/privacy_policy_screen.dart';
import 'package:sentinel/screens/qr_result_screen.dart';
import 'package:sentinel/screens/settings_screen.dart';
import 'package:sentinel/screens/vault/create_vault_view.dart';
import 'package:sentinel/screens/vault/vault_item_screen.dart';
import 'package:sentinel/services/app_analysis.dart';
import 'package:sentinel/services/app_risk_calculator.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/phishing/phishing_model.dart';
import 'package:sentinel/services/vault/vault_crypto.dart';
import 'package:sentinel/services/vault/vault_item.dart';
import 'package:sentinel/services/vault/vault_platform.dart';
import 'package:sentinel/services/vault/vault_session.dart';
import 'package:sentinel/services/vault/vault_storage.dart';
import 'package:sentinel/theme/app_colors.dart';
import 'package:sentinel/theme/app_theme.dart';
import 'package:sentinel/widgets/wifi_alert.dart';

import 'support/fake_biometrics.dart';
import 'support/l10n.dart';

// Écrans principaux en thème sombre : fond nuit, et aucun texte resté
// dans une couleur du thème clair (couleur codée en dur oubliée).
const _nuit = AppColors.dark;

/// Faux Android : téléphone sans verrouillage, Wi-Fi ouvert, pare-feu coupé.
void _fakeAndroid() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.iheb.sentinel/device_security'),
    (call) async => {
      'screenLock': false,
      'developerOptions': true,
      'encrypted': true,
      'androidVersion': '15',
      'sdkInt': 35,
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.iheb.sentinel/wifi'),
    (call) async => call.method == 'getWifiStatus'
        ? {'connected': true, 'security': 'open', 'sdkInt': 35}
        : null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.iheb.sentinel/firewall'),
    (call) async => switch (call.method) {
      'status' => {'active': false},
      'reports' => <Object?>[],
      _ => null,
    },
  );
}

/// Couleurs de tous les textes affichés (styles imbriqués compris).
List<Color> _textColors(WidgetTester tester) {
  final colors = <Color>[];
  for (final paragraph
      in tester.allRenderObjects.whereType<RenderParagraph>()) {
    paragraph.text.visitChildren((span) {
      final color = span.style?.color;
      if (color != null) colors.add(color);
      return true;
    });
  }
  return colors;
}

/// Vérifie l'écran affiché : fond nuit et textes lisibles.
void _expectDark(WidgetTester tester) {
  final scaffolds = tester.widgetList<Scaffold>(find.byType(Scaffold));
  for (final scaffold in scaffolds) {
    final context = tester.element(find.byWidget(scaffold));
    expect(Theme.of(context).scaffoldBackgroundColor, _nuit.chaux);
  }
  const clair = AppColors.light;
  final interdites = {
    clair.encre,
    clair.secondaire,
    clair.discret,
    clair.bleu,
    clair.zitouna,
    clair.ocre,
    clair.rommen,
  };
  final colors = _textColors(tester);
  expect(colors, isNotEmpty);
  for (final color in colors) {
    expect(interdites, isNot(contains(color)), reason: 'couleur claire $color');
    // Sur le fond nuit, un texte doit ressortir (sauf texte posé sur une
    // couleur pleine : bouton bleu, bandeau rouge, arche remplie).
    if (color == _nuit.surCouleur) continue;
    final ratio = contrastRatio(
      Color.alphaBlend(color, _nuit.chaux),
      _nuit.chaux,
    );
    expect(ratio, greaterThanOrEqualTo(3), reason: 'texte peu lisible $color');
  }
}

Future<void> _show(WidgetTester tester, Widget home) async {
  // Écran haut (toute la liste construite), largeur des tests (800).
  tester.view.physicalSize = const Size(2400, 12000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(home: home, theme: AppTheme.dark));
  await tester.pumpAndSettle();
}

InstalledApp _app() => InstalledApp(
  packageName: 'com.whatsapp.gb',
  label: 'GB WhatsApp',
  icon: null,
  isSystemApp: false,
  installerPackage: null,
  versionName: '1.0',
  firstInstallTime: null,
  lastUpdateTime: null,
  targetSdk: 22,
  grantedPermissions: const ['android.permission.READ_SMS'],
  requestsOverlay: true,
  accessibilityServiceEnabled: true,
  notificationListenerEnabled: false,
  isDeviceAdmin: false,
  signingCerts: const [],
  debugCert: true,
  hasLauncherIcon: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadPhishingModel();
    await loadKnownBrands();
  });
  setUp(_fakeAndroid);

  testWidgets('accueil : arche du score, actions, Wi-Fi', (tester) async {
    await _show(tester, const HomeScreen());
    _expectDark(tester);
  });

  testWidgets('alerte Wi-Fi : texte lisible sur le rouge', (tester) async {
    await _show(tester, const Scaffold(body: Text('x')));
    showWifiAlert(
      tester.element(find.text('x')),
      message: fr.wifiOpenSummary,
      onDetails: () {},
    );
    await tester.pumpAndSettle();
    final banner = tester.widget<MaterialBanner>(find.byType(MaterialBanner));
    expect(banner.backgroundColor, _nuit.rommen);
    final text = tester.widget<Text>(find.text(fr.wifiOpenSummary));
    expect(
      contrastRatio(text.style!.color!, _nuit.rommen),
      greaterThanOrEqualTo(4.5),
    );
    _expectDark(tester);
    await tester.pump(wifiAlertDuration);
  });

  testWidgets('Messages : verdict « Arnaque probable » en rouge nuit', (
    tester,
  ) async {
    await _show(tester, const Scaffold(body: MessagesScreen()));
    await tester.enterText(
      find.byType(TextField),
      'Votre colis est bloqué, payez ici : poste-tn-livraison.xyz/p',
    );
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final verdict = tester.widget<Text>(find.text(fr.verdictScam));
    expect(verdict.style!.color, _nuit.rommen);
    _expectDark(tester);
  });

  testWidgets('QR code : Wi-Fi ouvert', (tester) async {
    await _show(tester, const QrResultScreen(raw: 'WIFI:T:nopass;S:Gare;;'));
    _expectDark(tester);
  });

  testWidgets('rapport d\'analyse d\'une app', (tester) async {
    final ended = DateTime.now();
    await _show(
      tester,
      AppReportScreen(
        report: AppReport(
          id: '1',
          packageName: 'com.exemple.app',
          appLabel: 'Exemple',
          startedAt: ended.subtract(const Duration(minutes: 2)),
          endedAt: ended,
          plannedMinutes: 2,
          stoppedEarly: false,
          truncated: true,
          domains: const [
            ReportDomain(
              name: 'pub.exemple.com',
              count: 12,
              category: ReportCategory.ads,
              blocked: true,
            ),
            ReportDomain(
              name: 'malware.exemple.xyz',
              count: 3,
              category: ReportCategory.malware,
              blocked: true,
            ),
          ],
        ),
      ),
    );
    _expectDark(tester);
  });

  testWidgets('détail d\'une app à risque', (tester) async {
    await _show(
      tester,
      AppDetailScreen(
        app: _app(),
        report: const AppRiskReport(
          score: 90,
          level: RiskLevel.eleve,
          rules: [],
        ),
      ),
    );
    _expectDark(tester);
  });

  testWidgets('pare-feu', (tester) async {
    await _show(tester, FirewallScreen());
    _expectDark(tester);
  });

  testWidgets('Réglages, politique de confidentialité, présentation', (
    tester,
  ) async {
    await _show(tester, const SettingsScreen());
    _expectDark(tester);
    await _show(tester, const PrivacyPolicyScreen());
    _expectDark(tester);
    await _show(tester, OnboardingScreen(onDone: () {}));
    _expectDark(tester);
  });

  group('coffre', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('dark_vault'));
    tearDown(() => dir.deleteSync(recursive: true));

    VaultSession newSession() => VaultSession(
      storage: VaultStorage(directory: () async => dir),
      biometrics: FakeBiometrics(),
      kdfForNewVault: () => newKdfParams(memoryKib: 64, iterations: 2),
    );

    testWidgets('création du coffre', (tester) async {
      final session = newSession();
      await tester.runAsync(session.load);
      await _show(
        tester,
        Scaffold(
          body: CreateVaultView(session: session, onCancel: () {}),
        ),
      );
      _expectDark(tester);
    });

    testWidgets('mot de passe : générateur et force', (tester) async {
      final session = newSession();
      await tester.runAsync(() async {
        await session.load();
        await session.create('cheval correct batterie');
        session.recoveryKeyNoted();
      });
      final clipboard = ClipboardGuard();
      addTearDown(clipboard.dispose);
      await _show(
        tester,
        VaultItemScreen(
          session: session,
          clipboard: clipboard,
          type: VaultItemType.motDePasse,
        ),
      );
      _expectDark(tester);
    });
  });
}
