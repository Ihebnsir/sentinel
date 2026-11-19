import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/l10n/l10n.dart';
import 'package:sentinel/models/installed_app.dart';
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
import 'package:sentinel/services/breach/breach_checker.dart';
import 'package:sentinel/services/breach/breach_consent.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/vault/vault_crypto.dart';
import 'package:sentinel/services/vault/vault_item.dart';
import 'package:sentinel/services/vault/vault_platform.dart';
import 'package:sentinel/services/vault/vault_session.dart';
import 'package:sentinel/services/vault/vault_storage.dart';
import 'package:sentinel/theme/app_colors.dart';
import 'package:sentinel/theme/app_theme.dart';

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

/// Polices réelles : Readex Pro et les icônes Material.
Future<void> _loadFonts() async {
  final readex = File('assets/fonts/ReadexPro-Regular.ttf').readAsBytesSync();
  await (FontLoader(
    AppTheme.fontFamily,
  )..addFont(Future.value(ByteData.sublistView(readex)))).load();
  // flutter_tester est dans bin/cache/artifacts/engine/<plateforme>/.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final icons = File(
    '${artifacts.path}/material_fonts/materialicons-regular.otf',
  ).readAsBytesSync();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(icons)))).load();
}

/// Une app fictive envoyée par le faux Android.
Map<String, Object?> _appMap(
  String package,
  String label, {
  List<String> permissions = const [],
  bool overlay = false,
  bool accessibility = false,
  bool system = false,
  int targetSdk = 35,
  String? installer = 'com.android.vending',
}) => {
  'packageName': package,
  'label': label,
  'isSystemApp': system,
  'installerPackage': installer,
  'versionName': '2.4.1',
  'targetSdk': targetSdk,
  'grantedPermissions': permissions,
  'requestsOverlay': overlay,
  'accessibilityServiceEnabled': accessibility,
  'notificationListenerEnabled': false,
  'isDeviceAdmin': false,
  'signingCerts': <String>[],
  'debugCert': false,
  'hasLauncherIcon': true,
};

final _apps = [
  _appMap(
    'com.exemple.lampe',
    'Lampe Torche Pro',
    permissions: [
      'android.permission.READ_SMS',
      'android.permission.READ_CONTACTS',
      'android.permission.ACCESS_FINE_LOCATION',
    ],
    overlay: true,
    accessibility: true,
    targetSdk: 23,
    installer: null,
  ),
  _appMap(
    'com.exemple.meteo',
    'Météo du Cap',
    permissions: [
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_BACKGROUND_LOCATION',
    ],
  ),
  _appMap(
    'com.exemple.clavier',
    'Clavier Jasmin',
    permissions: ['android.permission.RECORD_AUDIO'],
  ),
  _appMap('com.exemple.notes', 'Carnet de notes'),
  _appMap('com.exemple.recettes', 'Recettes de Tunis'),
  _appMap('com.exemple.bus', 'Horaires du TGM'),
  _appMap('com.exemple.dictionnaire', 'Dictionnaire'),
  _appMap('com.android.systemui', 'Interface système', system: true),
];

/// Faux Android : téléphone verrouillé, options développeur actives,
/// Wi-Fi WPA2, pare-feu actif avec quelques blocages.
void _fakeAndroid(Directory dir, {bool firewallActive = true}) {
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  // Dossier privé de l'app : un dossier temporaire vide.
  m.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => dir.path,
  );
  void on(String channel, Future<Object?> Function(MethodCall) handler) =>
      m.setMockMethodCallHandler(
        MethodChannel('com.iheb.sentinel/$channel'),
        handler,
      );
  on(
    'device_security',
    (call) async => call.method == 'getSecurityStatus'
        ? {
            'screenLock': true,
            'biometricEnrolled': true,
            'developerOptions': true,
            'usbDebugging': true,
            'encrypted': true,
            'androidVersion': '16',
            'sdkInt': 36,
            'securityPatch': '2026-10-05',
          }
        : null,
  );
  on(
    'wifi',
    (call) async => call.method == 'getWifiStatus'
        ? {
            'connected': true,
            'security': 'wpa2',
            'sdkInt': 36,
            'privateDnsActive': false,
          }
        : null,
  );
  on('firewall', (call) async {
    switch (call.method) {
      case 'status':
        return {
          'active': firewallActive,
          'totalQueries': 4812,
          'blockedQueries': 37,
          'blockedByCategory': {'malware': 3, 'trackers': 21, 'ads': 13},
          'upstream': 'dot',
        };
      case 'config':
        return {
          'categories': [
            {
              'id': 'malware',
              'name': 'Malware',
              'enabled': true,
              'domains': 430961,
              'sources': ['Phishing.Database', 'ShadowWhisperer'],
            },
            {
              'id': 'impersonation',
              'name': 'Imitations',
              'enabled': true,
              'domains': 42,
              'sources': <String>[],
            },
            {
              'id': 'trackers',
              'name': 'Traqueurs',
              'enabled': true,
              'domains': 51230,
              'sources': ['AdGuard'],
            },
            {
              'id': 'ads',
              'name': 'Publicités',
              'enabled': false,
              'domains': 61004,
              'sources': ['AdAway'],
            },
          ],
          'allowlist': <String>[],
          'autoUpdate': true,
          'lastUpdate': DateTime(2026, 11, 17, 9).millisecondsSinceEpoch,
          'sources': <Object?>[],
        };
      case 'reports':
        return <Object?>[];
      case 'checkDomain':
        return {'allowed': false, 'dangerous': false};
    }
    return null;
  });
  on('apps', (call) async {
    switch (call.method) {
      case 'scanApps':
        return _apps;
      case 'hasUsageAccess':
        return false;
      case 'readSensitiveAccess':
        return <Object?>[];
    }
    return null;
  });
  on(
    'weekly',
    (call) async => switch (call.method) {
      'snapshot' => {
        'current': {
          'week': 20773,
          'counters': {
            'blocked_malware': 3,
            'blocked_trackers': 21,
            'blocked_ads': 13,
            'links_checked': 6,
          },
          'scoreStart': 55,
          'scoreEnd': 75,
          'gauges': {'risky_apps': 1, 'pw_weak': 1, 'pw_reused': 0},
        },
        'previous': {
          'week': 20766,
          'counters': {'blocked_trackers': 12, 'links_checked': 2},
          'scoreStart': 50,
          'scoreEnd': 55,
        },
      },
      'getNotificationsEnabled' => false,
      _ => null,
    },
  );
  on('vault', (call) async => null);
  on('share', (call) async => null);
  on('language', (call) async => null);
  on('notifications', (call) async => null);
  on('qr', (call) async => false);
}

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

/// Attend les lectures réelles (fichiers, assets) tant qu'une barre de
/// chargement tourne, puis laisse finir les animations.
Future<void> _settleAsync(WidgetTester tester) async {
  for (var i = 0; i < 120; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(LinearProgressIndicator).evaluate().isEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        i > 4) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

/// Un écran à capturer. [prepare] agit après l'affichage (appui, saisie).
class _Scene {
  const _Scene(this.name, this.build, {this.prepare});

  final String name;
  final Future<Widget> Function(WidgetTester tester, Directory dir) build;
  final Future<void> Function(WidgetTester tester, AppLocalizations l)? prepare;
}

/// Coffre ouvert rempli d'exemples fictifs (aucun vrai mot de passe).
Future<VaultSession> _sampleVault(WidgetTester tester, Directory dir) async {
  final session = VaultSession(
    storage: VaultStorage(directory: () async => dir),
    biometrics: FakeBiometrics(),
    kdfForNewVault: () => newKdfParams(memoryKib: 64, iterations: 2),
  );
  await tester.runAsync(() async {
    await session.load();
    await session.create('exemple fictif pour capture');
    session.recoveryKeyNoted();
    final now = DateTime(2026, 11, 2);
    var n = 0;
    Future<void> add(
      VaultItemType type,
      String titre, {
      String id = '',
      String mdp = '',
      String site = '',
    }) => session.save(
      VaultItem(
        id: 'ex${n++}',
        type: type,
        titre: titre,
        identifiant: id,
        motDePasse: mdp,
        siteWeb: site,
        creeLe: now,
        modifieLe: now.add(Duration(days: n)),
      ),
    );
    await add(
      VaultItemType.motDePasse,
      'Banque Exemple',
      id: 'prenom.nom@exemple.tn',
      mdp: 'Fictif-Jasmin-2026!',
      site: 'banque.exemple.tn',
    );
    await add(
      VaultItemType.motDePasse,
      'Messagerie',
      id: 'contact@exemple.tn',
      mdp: 'Exemple-Porte-Bleue-7',
      site: 'mail.exemple.tn',
    );
    await add(
      VaultItemType.motDePasse,
      'Wi-Fi maison',
      id: 'Maison',
      mdp: 'azerty12',
    );
    await add(VaultItemType.note, 'Codes du portail');
    await add(
      VaultItemType.motDePasse,
      'Boutique en ligne',
      id: 'acheteur@exemple.tn',
      mdp: 'Moucharabieh-Fictif-31',
      site: 'boutique.exemple.tn',
    );
  });
  return session;
}

BreachChecker _breaches(Directory dir) =>
    BreachChecker(consentStore: BreachConsentStore(directory: () async => dir));

InstalledApp _risky() => InstalledApp.fromMap(_apps.first);

final _scenes = <_Scene>[
  _Scene('presentation', (_, _) async => OnboardingScreen(onDone: () {})),
  _Scene('accueil', (_, _) async => const MainShell()),
  _Scene('applications-vide', (_, _) async => const MainShell(initialIndex: 1)),
  _Scene(
    'applications',
    (_, _) async => const MainShell(initialIndex: 1),
    prepare: (tester, l) async {
      await tester.tap(find.text(l.appsStartScan));
      await _settleAsync(tester);
    },
  ),
  _Scene('app-detail', (_, _) async {
    final app = _risky();
    return AppDetailScreen(app: app, report: calculateAppRisk(app));
  }),
  _Scene('logiciel-espion', (_, _) async {
    final app = _risky();
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
        breaches: _breaches(dir),
      ),
    );
  }),
  _Scene('coffre', (tester, dir) async {
    final session = await _sampleVault(tester, dir);
    return MainShell(
      initialIndex: 3,
      vaultBuilder: (visible) => VaultScreen(
        visible: visible,
        session: session,
        breaches: _breaches(dir),
      ),
    );
  }),
  _Scene('coffre-verrouille', (tester, dir) async {
    final session = await _sampleVault(tester, dir);
    session.lock();
    return MainShell(
      initialIndex: 3,
      vaultBuilder: (visible) => VaultScreen(
        visible: visible,
        session: session,
        breaches: _breaches(dir),
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
    final session = await _sampleVault(tester, dir);
    return VaultItemScreen(
      session: session,
      clipboard: ClipboardGuard(isClipboardShared: () async => false),
      type: VaultItemType.motDePasse,
    );
  }),
  _Scene('coffre-sante', (tester, dir) async {
    final session = await _sampleVault(tester, dir);
    return PasswordHealthScreen(
      session: session,
      clipboard: ClipboardGuard(isClipboardShared: () async => false),
      breaches: _breaches(dir),
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
    await _loadFonts();
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
        _fakeAndroid(dir);
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
        await _settleAsync(tester);
        await scene.prepare?.call(tester, l);
        await _settleAsync(tester);
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
