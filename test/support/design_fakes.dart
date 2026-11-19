import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/models/installed_app.dart';
import 'package:sentinel/services/breach/breach_checker.dart';
import 'package:sentinel/services/breach/breach_consent.dart';
import 'package:sentinel/services/vault/vault_crypto.dart';
import 'package:sentinel/services/vault/vault_item.dart';
import 'package:sentinel/services/vault/vault_session.dart';
import 'package:sentinel/services/vault/vault_storage.dart';
import 'package:sentinel/theme/app_theme.dart';

import 'fake_biometrics.dart';

// Faux Android et données fictives partagés par le banc de capture
// (test/design) et les tests golden (test/goldens). Aucune donnée réelle.

/// Polices réelles : Readex Pro et les icônes Material.
Future<void> loadRealFonts() async {
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

final fakeApps = [
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
void fakeAndroid(Directory dir, {bool firewallActive = true}) {
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
        return fakeApps;
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

/// Attend les lectures réelles (fichiers, assets) tant qu'une barre de
/// chargement tourne, puis laisse finir les animations.
Future<void> settleAsync(WidgetTester tester) async {
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

/// Coffre ouvert rempli d'exemples fictifs (aucun vrai mot de passe).
Future<VaultSession> sampleVault(WidgetTester tester, Directory dir) async {
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

BreachChecker sampleBreaches(Directory dir) =>
    BreachChecker(consentStore: BreachConsentStore(directory: () async => dir));

InstalledApp riskyApp() => InstalledApp.fromMap(fakeApps.first);
