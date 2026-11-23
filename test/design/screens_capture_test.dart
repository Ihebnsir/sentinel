import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/l10n/l10n.dart';
import 'package:sentinel/screens/app_analysis_screen.dart';
import 'package:sentinel/screens/app_detail_screen.dart';
import 'package:sentinel/screens/app_report_screen.dart';
import 'package:sentinel/screens/firewall_screen.dart';
import 'package:sentinel/screens/main_shell.dart';
import 'package:sentinel/screens/onboarding_screen.dart';
import 'package:sentinel/screens/qr_result_screen.dart';
import 'package:sentinel/screens/settings_screen.dart';
import 'package:sentinel/screens/spyware_advice_screen.dart';
import 'package:sentinel/screens/vault/password_health_screen.dart';
import 'package:sentinel/screens/vault/recovery_key_view.dart';
import 'package:sentinel/screens/vault/vault_item_screen.dart';
import 'package:sentinel/screens/vault_screen.dart';
import 'package:sentinel/screens/weekly_report_screen.dart';
import 'package:sentinel/services/app_analysis.dart';
import 'package:sentinel/services/app_risk_calculator.dart';
import 'package:sentinel/services/apps/stalkerware_ioc.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/vault/vault_item.dart';
import 'package:sentinel/services/vault/vault_platform.dart';
import 'package:sentinel/services/vault/vault_session.dart';
import 'package:sentinel/services/vault/vault_storage.dart';
import 'package:sentinel/theme/app_colors.dart';
import 'package:sentinel/theme/app_theme.dart';

import '../support/design_fakes.dart';
import '../support/fake_biometrics.dart';

// Banc de capture des écrans, au format d'un Pixel 8 (1080 × 2400).
// Données 100 % fictives. Ne tourne que si SENTINEL_CAPTURE donne le
// dossier de sortie, sinon les tests sont ignorés :
//   $env:SENTINEL_CAPTURE="C:\chemin\captures"; flutter test test/design
// Options : SENTINEL_CAPTURE_SCALE (2.625 par défaut, 1.3125 = moitié),
// SENTINEL_CAPTURE_TALL=1 (page entière, 2400 dp de haut),
// SENTINEL_CAPTURE_ONLY (noms séparés par des virgules),
// SENTINEL_CAPTURE_VARIANTS (ex : fr-clair,ar-sombre).

final _env = Platform.environment;
final _out = _env['SENTINEL_CAPTURE'];
final _scale = double.tryParse(_env['SENTINEL_CAPTURE_SCALE'] ?? '') ?? 2.625;
final _tall = _env['SENTINEL_CAPTURE_TALL'] == '1';
final _only = _env['SENTINEL_CAPTURE_ONLY']?.split(',').toSet();
final _variants =
    _env['SENTINEL_CAPTURE_VARIANTS']?.split(',').toSet() ??
    {'fr-clair', 'fr-sombre', 'ar-clair'};

const _dpr = 2.625; // densité du Pixel 8
const _statusBar = 32.0; // barre d'état dessinée (10:00, batterie pleine)
const _gestureBar = 20.0; // barre de gestes en bas
final _shotKey = GlobalKey();

/// Barre d'état dessinée : 10:00, Wi-Fi, réseau, batterie pleine.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final color = context.colors.encre;
    return SizedBox(
      height: _statusBar,
      // Material : style de texte de base (pas de soulignement jaune).
      child: Material(type: MaterialType.transparency, child: _row(color)),
    );
  }

  Widget _row(Color color) {
    return SizedBox(
      height: _statusBar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Text(
              '10:00',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                color: color,
              ),
            ),
            const Spacer(),
            for (final icon in [
              Icons.signal_wifi_4_bar,
              Icons.signal_cellular_4_bar,
              Icons.battery_full,
            ])
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Icon(icon, size: 16, color: color),
              ),
          ],
        ),
      ),
    );
  }
}

/// L'app de capture : thème, langue, barres système dessinées.
Widget _app(Widget home, {required Locale locale, required ThemeData theme}) =>
    RepaintBoundary(
      key: _shotKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: locale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        builder: (context, child) => Stack(
          children: [
            child!,
            const Positioned(top: 0, left: 0, right: 0, child: _StatusBar()),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 108,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.encre.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
        home: home,
      ),
    );

/// Un écran à capturer. [prepare] agit après l'affichage (appui, saisie).
class _Scene {
  const _Scene(this.name, this.build, {this.prepare});

  final String name;
  final Future<Widget> Function(WidgetTester tester, Directory dir) build;
  final Future<void> Function(WidgetTester tester, AppLocalizations l)? prepare;
}

final _scenes = <_Scene>[
  _Scene('presentation', (_, _) async => OnboardingScreen(onDone: () {})),
  _Scene('accueil', (_, _) async => const MainShell()),
  _Scene('applications-vide', (_, _) async => const MainShell(initialIndex: 1)),
  _Scene(
    'applications',
    (_, _) async => const MainShell(initialIndex: 1),
    prepare: (tester, l) async {
      await tester.tap(find.text(l.appsStartScan));
      await settleAsync(tester);
    },
  ),
  _Scene('app-detail', (_, _) async {
    final app = riskyApp();
    return AppDetailScreen(app: app, report: calculateAppRisk(app));
  }),
  _Scene('logiciel-espion', (_, _) async {
    final app = riskyApp();
    return SpywareAdviceScreen(
      app: app,
      report: const AppRiskReport(
        score: 100,
        level: RiskLevel.eleve,
        rules: [],
        stalkerwareName: 'EspionExemple',
      ),
    );
  }),
  _Scene('liens-vide', (_, _) async => const MainShell(initialIndex: 2)),
  _Scene(
    'liens-dangereux',
    (_, _) async => const MainShell(initialIndex: 2),
    prepare: (tester, l) async {
      await tester.enterText(
        find.byType(TextField),
        'Votre colis est bloqué, payez ici : poste-tn-livraison.xyz/p',
      );
      await tester.pump();
      await tester.tap(find.text(l.linksCheck));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    },
  ),
  _Scene(
    'liens-ok',
    (_, _) async => const MainShell(initialIndex: 2),
    prepare: (tester, l) async {
      await tester.enterText(find.byType(TextField), 'https://wikipedia.org');
      await tester.pump();
      await tester.tap(find.text(l.linksCheck));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    },
  ),
  _Scene(
    'qr-wifi',
    (_, _) async => const QrResultScreen(raw: 'WIFI:T:nopass;S:Gare;;'),
  ),
  // QR code d'un faux WhatsApp à installer (.apk), adresse fictive.
  _Scene(
    'qr-apk',
    (_, _) async =>
        const QrResultScreen(raw: 'https://exemple.tn/WhatsApp-Gold.apk'),
  ),
  _Scene('coffre-vide', (tester, dir) async {
    final session = VaultSession(
      storage: VaultStorage(directory: () async => dir),
      biometrics: FakeBiometrics(),
    );
    return MainShell(
      initialIndex: 3,
      vaultBuilder: (visible) => VaultScreen(
        visible: visible,
        session: session,
        breaches: sampleBreaches(dir),
      ),
    );
  }),
  _Scene('coffre', (tester, dir) async {
    final session = await sampleVault(tester, dir);
    return MainShell(
      initialIndex: 3,
      vaultBuilder: (visible) => VaultScreen(
        visible: visible,
        session: session,
        breaches: sampleBreaches(dir),
      ),
    );
  }),
  _Scene('coffre-verrouille', (tester, dir) async {
    final session = await sampleVault(tester, dir);
    session.lock();
    return MainShell(
      initialIndex: 3,
      vaultBuilder: (visible) => VaultScreen(
        visible: visible,
        session: session,
        breaches: sampleBreaches(dir),
      ),
    );
  }),
  _Scene(
    'coffre-cle',
    (tester, dir) async => Scaffold(
      body: SafeArea(
        child: RecoveryKeyView(
          recoveryKey: 'EXEM-PLEF-ICTI-FPOU-RCAP-TURE-0000',
          clipboard: ClipboardGuard(isClipboardShared: () async => false),
          onDone: () {},
        ),
      ),
    ),
  ),
  _Scene('coffre-element', (tester, dir) async {
    final session = await sampleVault(tester, dir);
    return VaultItemScreen(
      session: session,
      clipboard: ClipboardGuard(isClipboardShared: () async => false),
      type: VaultItemType.motDePasse,
    );
  }),
  _Scene('coffre-sante', (tester, dir) async {
    final session = await sampleVault(tester, dir);
    return PasswordHealthScreen(
      session: session,
      clipboard: ClipboardGuard(isClipboardShared: () async => false),
      breaches: sampleBreaches(dir),
    );
  }),
  _Scene('pare-feu', (_, _) async => const FirewallScreen()),
  _Scene('analyse-app', (_, _) async => const AppAnalysisScreen()),
  _Scene('rapport-app', (_, _) async {
    final ended = DateTime(2026, 11, 18, 18, 30);
    return AppReportScreen(
      report: AppReport(
        id: '1',
        packageName: 'com.exemple.lampe',
        appLabel: 'Lampe Torche Pro',
        startedAt: ended.subtract(const Duration(minutes: 5)),
        endedAt: ended,
        plannedMinutes: 5,
        stoppedEarly: false,
        truncated: false,
        domains: const [
          ReportDomain(
            name: 'pub.exemple.com',
            count: 12,
            category: ReportCategory.ads,
            blocked: true,
          ),
          ReportDomain(
            name: 'collecte.exemple.net',
            count: 7,
            category: ReportCategory.trackers,
            blocked: true,
          ),
          ReportDomain(
            name: 'cdn.exemple.org',
            count: 4,
            category: ReportCategory.other,
            blocked: false,
          ),
        ],
      ),
    );
  }),
  _Scene('bilan', (_, _) async => const WeeklyReportScreen()),
  _Scene('reglages', (_, _) async => const SettingsScreen()),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _out == null;
  setUpAll(() async {
    if (skip) return;
    await loadRealFonts();
    await loadKnownBrands();
    // Chargé une fois hors des tests : le Future en cache reste utilisable.
    await StalkerwareIoc.load();
  });

  for (final scene in _scenes) {
    final only = _only;
    if (only != null && !only.contains(scene.name)) continue;
    for (final variant in _variants) {
      final arabic = variant.startsWith('ar');
      final dark = variant.endsWith('sombre');
      testWidgets('capture ${scene.name} ($variant)', skip: skip, (
        tester,
      ) async {
        final dir = Directory.systemTemp.createTempSync('capture');
        addTearDown(() => dir.deleteSync(recursive: true));
        fakeAndroid(dir);
        final height = _tall ? 2400.0 : 2400 / _dpr;
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(1080, height * _dpr);
        tester.view.padding = const FakeViewPadding(
          top: _statusBar * _dpr,
          bottom: _gestureBar * _dpr,
        );
        tester.view.viewPadding = tester.view.padding;
        addTearDown(tester.view.reset);
        final locale = Locale(arabic ? 'ar' : 'fr');
        final l = lookupAppLocalizations(locale);
        final home = await scene.build(tester, dir);
        await tester.pumpWidget(
          _app(
            home,
            locale: locale,
            theme: dark ? AppTheme.dark : AppTheme.light,
          ),
        );
        await settleAsync(tester);
        await scene.prepare?.call(tester, l);
        await settleAsync(tester);
        final boundary =
            _shotKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: _scale);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$_out/${scene.name}_$variant.png');
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
