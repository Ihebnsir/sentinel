import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/models/installed_app.dart';
import 'package:sentinel/screens/app_analysis_screen.dart';
import 'package:sentinel/screens/app_detail_screen.dart';
import 'package:sentinel/screens/app_report_screen.dart';
import 'package:sentinel/screens/apps_screen.dart';
import 'package:sentinel/screens/firewall_screen.dart';
import 'package:sentinel/screens/home_screen.dart';
import 'package:sentinel/screens/messages_screen.dart';
import 'package:sentinel/screens/onboarding_screen.dart';
import 'package:sentinel/screens/privacy_policy_screen.dart';
import 'package:sentinel/screens/qr_result_screen.dart';
import 'package:sentinel/screens/settings_screen.dart';
import 'package:sentinel/screens/spyware_advice_screen.dart';
import 'package:sentinel/screens/vault/create_vault_view.dart';
import 'package:sentinel/screens/vault/password_health_screen.dart';
import 'package:sentinel/screens/vault/recovery_key_view.dart';
import 'package:sentinel/screens/vault/unlock_view.dart';
import 'package:sentinel/screens/vault/vault_item_screen.dart';
import 'package:sentinel/screens/vault/vault_list_view.dart';
import 'package:sentinel/screens/vault/vault_settings_screen.dart';
import 'package:sentinel/services/app_analysis.dart';
import 'package:sentinel/services/app_risk_calculator.dart';
import 'package:sentinel/services/breach/breach_checker.dart';
import 'package:sentinel/services/breach/breach_consent.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/phishing/phishing_model.dart';
import 'package:sentinel/services/vault/vault_crypto.dart';
import 'package:sentinel/services/vault/vault_item.dart';
import 'package:sentinel/services/vault/vault_platform.dart';
import 'package:sentinel/services/vault/vault_session.dart';
import 'package:sentinel/services/vault/vault_storage.dart';
import 'package:sentinel/theme/app_theme.dart';
import 'package:sentinel/widgets/loading_bar.dart';
import 'package:sentinel/widgets/score_arch.dart';

import 'support/fake_biometrics.dart';
import 'support/l10n.dart';

// Accessibilité des écrans principaux : zones tactiles de 48 dp, libellés
// pour TalkBack, contraste WCAG AA, et police système à 200 % sans
// débordement. Voir docs/ACCESSIBILITE.md.

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
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.iheb.sentinel/apps'),
    (call) async => call.method == 'scanApps' ? <Object?>[] : null,
  );
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

AppReport _report() {
  final ended = DateTime.now();
  return AppReport(
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
  );
}

/// Vraie police de l'app : à 200 %, la police de test (glyphes carrés,
/// presque deux fois plus larges) déborderait là où Readex Pro tient.
Future<void> _loadFont() async {
  final bytes = File('assets/fonts/ReadexPro-Regular.ttf').readAsBytesSync();
  final loader = FontLoader(AppTheme.fontFamily)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

/// Affiche [home] sur un téléphone de 360 dp de large (très haut : toute
/// la liste est construite), police système à [scale].
Future<void> _show(
  WidgetTester tester,
  Widget home, {
  double scale = 1,
  ThemeData? theme,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(360 * 3, 2400 * 3);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(testApp(home: home, theme: theme ?? AppTheme.light));
  await tester.pumpAndSettle();
}

/// Les règles de Flutter sur l'écran affiché : zones tactiles d'au moins
/// 48 × 48, boutons nommés pour TalkBack, contraste du texte (AA).
Future<void> _expectGuidelines(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
}

/// Écran vérifié dans les deux thèmes, puis avec la police à 200 %.
void _audit(String name, Future<Widget> Function(WidgetTester) build) {
  for (final (themeName, theme) in [
    ('clair', AppTheme.light),
    ('sombre', AppTheme.dark),
  ]) {
    testWidgets('$name ($themeName) : règles d\'accessibilité', (tester) async {
      await _show(tester, await build(tester), theme: theme);
      await _expectGuidelines(tester);
    });
  }
  testWidgets('$name : police à 200 % sans débordement', (tester) async {
    await _show(tester, await build(tester), scale: 2);
    // Un débordement (bandes jaunes et noires) lève une erreur ici.
    expect(tester.takeException(), isNull);
    await _expectGuidelines(tester);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await _loadFont();
    await loadPhishingModel();
    await loadKnownBrands();
  });
  setUp(_fakeAndroid);

  group('écrans principaux', () {
    _audit('accueil', (_) async => const HomeScreen());
    _audit('applications', (_) async => const Scaffold(body: AppsScreen()));
    _audit('messages', (_) async => const Scaffold(body: MessagesScreen()));
    _audit(
      'QR code',
      (_) async => const QrResultScreen(raw: 'WIFI:T:nopass;S:Gare;;'),
    );
    _audit(
      'détail d\'une app',
      (_) async => AppDetailScreen(
        app: _app(),
        report: const AppRiskReport(
          score: 90,
          level: RiskLevel.eleve,
          rules: [],
        ),
      ),
    );
    _audit(
      'conseils logiciel espion',
      (_) async => SpywareAdviceScreen(
        app: _app(),
        report: const AppRiskReport(
          score: 100,
          level: RiskLevel.eleve,
          rules: [],
          stalkerwareName: 'EspionTest',
        ),
      ),
    );
    _audit('pare-feu', (_) async => FirewallScreen());
    _audit('analyse d\'une app', (_) async => const AppAnalysisScreen());
    _audit(
      'rapport d\'analyse',
      (_) async => AppReportScreen(report: _report()),
    );
    _audit('réglages', (_) async => const SettingsScreen());
    _audit('politique', (_) async => const PrivacyPolicyScreen());
    _audit('présentation', (_) async => OnboardingScreen(onDone: () {}));
  });

  group('coffre', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('a11y_vault'));
    tearDown(() => dir.deleteSync(recursive: true));

    VaultSession newSession() => VaultSession(
      storage: VaultStorage(directory: () async => dir),
      biometrics: FakeBiometrics(),
      kdfForNewVault: () => newKdfParams(memoryKib: 64, iterations: 2),
    );

    /// Coffre ouvert avec deux éléments.
    Future<VaultSession> openSession(WidgetTester tester) async {
      final session = newSession();
      await tester.runAsync(() async {
        await session.load();
        await session.create('cheval correct batterie');
        session.recoveryKeyNoted();
        final now = DateTime(2026, 10, 1);
        await session.save(
          VaultItem(
            id: 'a',
            type: VaultItemType.motDePasse,
            titre: 'Banque',
            identifiant: 'moi@exemple.com',
            motDePasse: 'azerty',
            creeLe: now,
            modifieLe: now,
          ),
        );
        await session.save(
          VaultItem(
            id: 'b',
            type: VaultItemType.note,
            titre: 'Note',
            creeLe: now,
            modifieLe: now,
          ),
        );
      });
      return session;
    }

    BreachChecker breaches(WidgetTester tester) {
      final checker = BreachChecker(
        consentStore: BreachConsentStore(directory: () async => dir),
      );
      addTearDown(checker.dispose);
      return checker;
    }

    ClipboardGuard clipboard() {
      final guard = ClipboardGuard();
      addTearDown(guard.dispose);
      return guard;
    }

    _audit('création du coffre', (tester) async {
      final session = newSession();
      await tester.runAsync(session.load);
      return Scaffold(
        body: CreateVaultView(session: session, onCancel: () {}),
      );
    });

    _audit('déverrouillage', (tester) async {
      final session = await openSession(tester);
      session.lock();
      return Scaffold(
        body: UnlockView(session: session, onForgotPassword: () {}),
      );
    });

    _audit(
      'clé de récupération',
      (_) async => Scaffold(
        body: RecoveryKeyView(
          recoveryKey: 'K7QM-4XPA-ABCD-EFGH-JKLM-NPQR-STUV',
          clipboard: clipboard(),
          onDone: () {},
        ),
      ),
    );

    _audit('liste du coffre', (tester) async {
      final session = await openSession(tester);
      return Scaffold(
        body: VaultListView(
          session: session,
          clipboard: clipboard(),
          breaches: breaches(tester),
        ),
      );
    });

    _audit('mot de passe : générateur et force', (tester) async {
      final session = await openSession(tester);
      return VaultItemScreen(
        session: session,
        clipboard: clipboard(),
        type: VaultItemType.motDePasse,
      );
    });

    _audit('santé des mots de passe', (tester) async {
      final session = await openSession(tester);
      return PasswordHealthScreen(
        session: session,
        clipboard: clipboard(),
        breaches: breaches(tester),
      );
    });

    _audit('réglages du coffre', (tester) async {
      final session = await openSession(tester);
      return VaultSettingsScreen(session: session, breaches: breaches(tester));
    });
  });

  group('annonces TalkBack', () {
    testWidgets('arche : une seule phrase « Score de sécurité : X sur 100 »', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _show(tester, const Scaffold(body: ScoreArch(score: 80)));
      expect(
        find.bySemanticsLabel('Score de sécurité : 80 sur 100'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byType(ScoreArch)),
        isSemantics(
          label: 'Score de sécurité : 80 sur 100',
          isLiveRegion: true,
        ),
      );
      // Ni le chiffre animé ni « sur 100 » ne sont lus à part.
      expect(find.bySemanticsLabel(fr.commonOutOf100), findsNothing);
      handle.dispose();
    });

    testWidgets('accueil : l\'arche annonce le vrai score', (tester) async {
      final handle = tester.ensureSemantics();
      await _show(tester, const HomeScreen());
      expect(
        find.bySemanticsLabel(RegExp(r'^Score de sécurité : \d+ sur 100$')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('arche vide : « Analyse en cours » annoncé', (tester) async {
      final handle = tester.ensureSemantics();
      await _show(
        tester,
        Scaffold(body: ScoreArch.empty(message: fr.homeAnalyzing)),
      );
      expect(
        tester.getSemantics(find.text(fr.homeAnalyzing)),
        isSemantics(label: fr.homeAnalyzing, isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('barre de chargement nommée et annoncée', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(home: const Scaffold(body: LoadingBar())),
      );
      expect(
        tester.getSemantics(find.byType(LinearProgressIndicator)),
        isSemantics(label: fr.commonLoading, isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('interrupteur lu avec son texte et son état', (tester) async {
      final handle = tester.ensureSemantics();
      await _show(tester, FirewallScreen());
      final node = tester.getSemantics(find.byType(Switch).first);
      // Titre et état du pare-feu dans la même phrase que l'interrupteur.
      expect(node.label, contains(fr.firewallTitle));
      expect(
        node,
        isSemantics(
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('verdict d\'un message annoncé dès qu\'il s\'affiche', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
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
      expect(
        tester.getSemantics(find.text(fr.verdictScam)),
        isSemantics(isLiveRegion: true, isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('case « J\'ai compris » lue avec son texte', (tester) async {
      final handle = tester.ensureSemantics();
      final dir = Directory.systemTemp.createTempSync('a11y_case');
      addTearDown(() => dir.deleteSync(recursive: true));
      final session = VaultSession(
        storage: VaultStorage(directory: () async => dir),
        biometrics: FakeBiometrics(),
      );
      await tester.runAsync(session.load);
      await _show(
        tester,
        Scaffold(
          body: CreateVaultView(session: session, onCancel: () {}),
        ),
      );
      expect(
        tester.getSemantics(find.byType(Checkbox)),
        isSemantics(
          label: fr.vaultUnderstood,
          hasCheckedState: true,
          isChecked: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('bouton Réglages de l\'accueil : nommé, 48 dp', (tester) async {
      final handle = tester.ensureSemantics();
      await _show(tester, const HomeScreen());
      expect(find.byTooltip(fr.settingsTitle), findsOneWidget);
      final size = tester.getSize(
        find.widgetWithIcon(IconButton, Icons.settings_outlined),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      handle.dispose();
    });
  });
}
