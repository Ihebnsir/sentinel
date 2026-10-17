import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/models/installed_app.dart';
import 'package:sentinel/services/app_risk_calculator.dart';
import 'package:sentinel/services/apps/known_apps.dart';
import 'package:sentinel/services/apps/stalkerware_ioc.dart';

// Empreintes factices, pour les tests uniquement.
const officialSha256 =
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const otherSha256 =
    'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
const spySha1 = '0123456789ABCDEF0123456789ABCDEF01234567';

/// Une app sans signal ; chaque test change seulement ce qu'il teste.
InstalledApp app({
  String packageName = 'com.exemple.app',
  String label = 'Exemple',
  bool isSystemApp = false,
  String? installerPackage = InstalledApp.playStorePackage,
  List<String> permissions = const [],
  bool accessibility = false,
  bool notificationListener = false,
  bool deviceAdmin = false,
  List<SigningCert> certs = const [],
  bool debugCert = false,
  bool hasLauncherIcon = true,
}) {
  return InstalledApp(
    packageName: packageName,
    label: label,
    icon: null,
    isSystemApp: isSystemApp,
    installerPackage: installerPackage,
    versionName: '1.0',
    firstInstallTime: null,
    lastUpdateTime: null,
    targetSdk: 35,
    grantedPermissions: [for (final p in permissions) 'android.permission.$p'],
    requestsOverlay: false,
    accessibilityServiceEnabled: accessibility,
    notificationListenerEnabled: notificationListener,
    isDeviceAdmin: deviceAdmin,
    signingCerts: certs,
    debugCert: debugCert,
    hasLauncherIcon: hasLauncherIcon,
  );
}

SigningCert cert(String sha256, {String sha1 = ''}) =>
    SigningCert(sha256: sha256, sha1: sha1);

/// Base de test avec une empreinte connue pour WhatsApp.
const testKnown = [
  KnownApp(
    name: 'WhatsApp',
    displayNames: ['whatsapp'],
    officialPackages: ['com.whatsapp'],
    certSha256: [officialSha256],
  ),
];

final testIoc = StalkerwareIoc.fromJson({
  'source': 'test',
  'commit': '0' * 40,
  'license': 'CC BY 4.0',
  'apps': [
    {
      'name': 'EspionTest',
      'packages': ['com.android.core.spy'],
      'certificatesSha1': [spySha1],
    },
    // Entrée mal formée : ignorée sans planter.
    {'name': 'Cassé', 'packages': 'pas une liste'},
  ],
});

void main() {
  group('normalisation des noms', () {
    test('« WhatsApp », « whatsapp  », « WHATSAPP » sont identiques', () {
      expect(normalizeAppName('WhatsApp'), 'whatsapp');
      expect(normalizeAppName('whatsapp '), 'whatsapp');
      expect(normalizeAppName('WHATSAPP'), 'whatsapp');
      expect(normalizeAppName(' Whats  App\n'), 'whatsapp');
    });

    test('les caractères invisibles sont retirés', () {
      expect(normalizeAppName('Whats\u200BApp'), 'whatsapp');
      expect(normalizeAppName('\uFEFFWhatsApp'), 'whatsapp');
    });

    test('« WhatsApp Business » ne devient pas « WhatsApp »', () {
      expect(normalizeAppName('WhatsApp Business'), isNot('whatsapp'));
    });
  });

  group('usurpation', () {
    for (final label in ['WhatsApp', 'whatsapp ', 'WHATSAPP']) {
      test('« $label » avec un autre package : +60', () {
        final report = calculateAppRisk(
          app(packageName: 'com.whatsapp.faux', label: label),
        );
        expect(report.score, 60);
        expect(report.level, RiskLevel.eleve);
        expect(
          report.mainReason,
          "Se fait passer pour WhatsApp, mais ce n'est pas l'application "
          'officielle',
        );
        expect(report.identity.verdict, IdentityVerdict.impersonation);
      });
    }

    test('vraie app officielle du Play Store : non signalée', () {
      final report = calculateAppRisk(
        app(packageName: 'com.whatsapp', label: 'WhatsApp'),
      );
      expect(report.score, 0);
      expect(report.reasons, isEmpty);
      // Base réelle sans empreinte : on ne conclut rien sur la signature.
      expect(report.identity.verdict, IdentityVerdict.officialUnchecked);
    });

    test('emplacement sans package (apps tunisiennes) : ignoré', () {
      final report = calculateAppRisk(
        app(packageName: 'com.exemple.d17', label: 'D17'),
      );
      expect(report.reasons, isEmpty);
    });

    test("app système : pas de règle d'usurpation", () {
      final report = calculateAppRisk(
        app(
          packageName: 'com.oem.whatsapp',
          label: 'WhatsApp',
          isSystemApp: true,
        ),
      );
      expect(report.level, RiskLevel.systeme);
    });
  });

  group('signature', () {
    test('package officiel, empreinte différente : +80', () {
      final report = calculateAppRisk(
        app(
          packageName: 'com.whatsapp',
          label: 'WhatsApp',
          certs: [cert(otherSha256)],
        ),
        known: testKnown,
      );
      expect(report.score, 80);
      expect(
        report.mainReason,
        "Copie modifiée de WhatsApp (signature différente de l'éditeur "
        'officiel)',
      );
      expect(report.identity.verdict, IdentityVerdict.modifiedCopy);
    });

    test('package officiel, bonne empreinte : vérifiée, 0', () {
      final report = calculateAppRisk(
        app(
          packageName: 'com.whatsapp',
          label: 'WhatsApp',
          // Ancien certificat d'abord : une correspondance suffit.
          certs: [cert(otherSha256), cert(officialSha256.toLowerCase())],
        ),
        known: testKnown,
      );
      expect(report.score, 0);
      expect(report.identity.verdict, IdentityVerdict.verified);
      expect(report.identity.brand, 'WhatsApp');
    });

    test("liste d'empreintes vide : règle inactive", () {
      final report = calculateAppRisk(
        app(
          packageName: 'com.whatsapp',
          label: 'WhatsApp',
          certs: [cert(otherSha256)],
        ),
      );
      expect(report.score, 0);
    });

    test('signature illisible : pas de conclusion', () {
      final report = calculateAppRisk(
        app(packageName: 'com.whatsapp', label: 'WhatsApp'),
        known: testKnown,
      );
      expect(report.identity.verdict, IdentityVerdict.officialUnchecked);
      expect(report.score, 0);
    });

    test('certificat de test sur une app non système : +15', () {
      final report = calculateAppRisk(app(debugCert: true));
      expect(report.score, 15);
      expect(report.reasons, ['Signée avec un certificat de test']);
    });

    test('certificat de test sur une app système : ignoré', () {
      final report = calculateAppRisk(app(debugCert: true, isSystemApp: true));
      expect(report.level, RiskLevel.systeme);
    });

    test('empreinte abrégée et sujet lisible', () {
      final c = SigningCert(
        sha256: '3AF109C2${'0' * 48}7C2E11B0',
        sha1: '',
        subjectCn: 'Exemple Inc.',
        subjectO: 'Exemple',
      );
      expect(c.shortSha256, '3A:F1:09:C2…7C:2E:11:B0');
      expect(c.subject, 'Exemple Inc. (Exemple)');
      expect(const SigningCert(sha256: '', sha1: '').subject, isNull);
    });
  });

  group('versions modifiées', () {
    test('« GB WhatsApp » : +45', () {
      final report = calculateAppRisk(
        app(packageName: 'com.exemple.gb', label: 'GB WhatsApp'),
      );
      expect(report.score, 45);
      expect(
        report.mainReason,
        'Version modifiée non officielle de WhatsApp : elle peut lire vos '
        'messages',
      );
    });

    test("package d'un mod avec le nom « WhatsApp » : mod, pas usurpation", () {
      final report = calculateAppRisk(
        app(packageName: 'com.gbwhatsapp', label: 'WhatsApp'),
      );
      expect(report.identity.verdict, IdentityVerdict.knownMod);
      expect(report.score, 45);
    });

    test('« WhatsApp Plus » avec le package officiel : mod', () {
      final report = calculateAppRisk(
        app(packageName: 'com.whatsapp', label: 'WhatsApp Plus'),
      );
      expect(report.identity.verdict, IdentityVerdict.knownMod);
    });
  });

  group('profil espion', () {
    test('icône cachée + accessibilité + SMS : +40 en premier', () {
      final report = calculateAppRisk(
        app(
          hasLauncherIcon: false,
          accessibility: true,
          permissions: ['READ_SMS'],
        ),
      );
      expect(report.spyProfile, isTrue);
      expect(report.spywareSuspected, isTrue);
      expect(report.score, 85); // 40 + 30 + 15
      expect(
        report.mainReason,
        "Icône cachée et accès typiques d'un logiciel espion",
      );
    });

    test('icône cachée + un seul accès : non signalé', () {
      final report = calculateAppRisk(
        app(hasLauncherIcon: false, permissions: ['READ_CALL_LOG']),
      );
      expect(report.spyProfile, isFalse);
      expect(report.spywareSuspected, isFalse);
    });

    test('icône visible + nombreux accès : pas de profil espion', () {
      final report = calculateAppRisk(
        app(
          accessibility: true,
          notificationListener: true,
          deviceAdmin: true,
          permissions: ['ACCESS_BACKGROUND_LOCATION'],
        ),
      );
      expect(report.spyProfile, isFalse);
    });

    test('icône cachée + localisation + administrateur : signalé', () {
      expect(
        hasSpyProfile(
          app(
            hasLauncherIcon: false,
            deviceAdmin: true,
            permissions: ['ACCESS_BACKGROUND_LOCATION'],
          ),
        ),
        isTrue,
      );
    });
  });

  group('indicateurs de stalkerware', () {
    test('app système avec un package connu : 100, élevé', () {
      final report = calculateAppRisk(
        app(packageName: 'com.android.core.spy', isSystemApp: true),
        ioc: testIoc,
      );
      expect(report.score, 100);
      expect(report.level, RiskLevel.eleve);
      expect(report.mainReason, 'Logiciel espion connu (stalkerware)');
      expect(report.stalkerwareName, 'EspionTest');
      expect(report.spywareSuspected, isTrue);
    });

    test('certificat connu (SHA-1, casse et « : » ignorés) : 100', () {
      final lower = [
        for (var i = 0; i < spySha1.length; i += 2)
          spySha1.substring(i, i + 2).toLowerCase(),
      ].join(':');
      final report = calculateAppRisk(
        app(
          certs: [
            SigningCert.fromMap({'sha256': '', 'sha1': lower}),
          ],
        ),
        ioc: testIoc,
      );
      expect(report.score, 100);
      expect(report.reasons.first, stalkerwareReason);
    });

    test('app sans indicateur : score habituel', () {
      final report = calculateAppRisk(app(), ioc: testIoc);
      expect(report.score, 0);
      expect(report.stalkerwareName, isNull);
    });

    test('recherche directe par package et par certificat', () {
      expect(testIoc.matchPackage('com.android.core.spy'), 'EspionTest');
      expect(testIoc.matchPackage('com.android.core.SPY'), isNull);
      expect(testIoc.matchCertificate(spySha1.toLowerCase()), 'EspionTest');
      expect(testIoc.matchCertificate('00'), isNull);
      expect(testIoc.packageCount, 1);
    });
  });

  group('fichier des indicateurs', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('chargé une seule fois, avec source et licence', () async {
      final first = await StalkerwareIoc.load();
      final second = await StalkerwareIoc.load();
      expect(identical(first, second), isTrue);
      expect(
        first.source,
        'https://github.com/AssoEchap/stalkerware-indicators',
      );
      expect(first.commit, hasLength(40));
      expect(first.license, 'CC BY 4.0');
      expect(first.attribution, contains('Echap'));
      expect(first.packageCount, greaterThan(100));
      expect(first.certificateCount, greaterThan(100));
      // Exemple réel tiré de ioc.yaml.
      expect(first.matchPackage('com.thetruth'), 'TheTruthSpy');
    });
  });
}
