import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/models/installed_app.dart';
import 'package:sentinel/services/app_risk_calculator.dart';
import 'support/l10n.dart';

/// Une app sans aucun signal ; chaque test change seulement ce qu'il teste.
InstalledApp cleanApp({
  bool isSystemApp = false,
  String? installerPackage = InstalledApp.playStorePackage,
  int targetSdk = 35,
  List<String> permissions = const [],
  bool requestsOverlay = false,
  bool accessibility = false,
  bool notificationListener = false,
  bool deviceAdmin = false,
}) {
  return InstalledApp(
    packageName: 'com.exemple.app',
    label: 'Exemple',
    icon: null,
    isSystemApp: isSystemApp,
    installerPackage: installerPackage,
    versionName: '1.0',
    firstInstallTime: DateTime(2026, 1, 1),
    lastUpdateTime: DateTime(2026, 9, 1),
    targetSdk: targetSdk,
    grantedPermissions: [
      for (final p in permissions) 'android.permission.$p',
    ],
    requestsOverlay: requestsOverlay,
    accessibilityServiceEnabled: accessibility,
    notificationListenerEnabled: notificationListener,
    isDeviceAdmin: deviceAdmin,
  );
}

void main() {
  test('app propre du Play Store : 0, faible, aucune raison', () {
    final report = calculateAppRisk(cleanApp());
    expect(report.score, 0);
    expect(report.level, RiskLevel.faible);
    expect(report.reasons(fr), isEmpty);
    expect(report.mainReason(fr), isNull);
    expect(report.needsReview, isFalse);
  });

  test('accessibilité + source inconnue : 70, élevé, combinaison en premier',
      () {
    final report = calculateAppRisk(
      cleanApp(accessibility: true, installerPackage: null),
    );
    expect(report.score, 70); // 30 + 25 + 15
    expect(report.level, RiskLevel.eleve);
    expect(report.reasons(fr), [
      'Combinaison typique des applications qui volent les comptes bancaires',
      "Peut lire tout ce qui s'affiche à l'écran et agir à votre place",
      'Installée en dehors du Play Store',
    ]);
  });

  test('accessibilité + AppGallery : pas de combinaison, 35, modéré', () {
    final report = calculateAppRisk(
      cleanApp(accessibility: true, installerPackage: 'com.huawei.appmarket'),
    );
    expect(report.score, 35); // 30 + 5
    expect(report.level, RiskLevel.modere);
    expect(
      report.mainReason(fr),
      "Peut lire tout ce qui s'affiche à l'écran et agir à votre place",
    );
  });

  test('app système avec accessibilité active : toujours évaluée', () {
    final report = calculateAppRisk(
      cleanApp(
        accessibility: true,
        isSystemApp: true,
        installerPackage: null,
        permissions: ['READ_SMS', 'CAMERA'],
      ),
    );
    // Pas de combinaison, et les permissions ne comptent pas.
    expect(report.score, 30);
    expect(report.level, RiskLevel.modere);
    expect(report.reasons(fr), [
      "Peut lire tout ce qui s'affiche à l'écran et agir à votre place",
    ]);
    expect(report.needsReview, isTrue);
  });

  test('app système administrateur + accessibilité : 50, modéré', () {
    final report = calculateAppRisk(
      cleanApp(isSystemApp: true, accessibility: true, deviceAdmin: true),
    );
    expect(report.score, 50);
    expect(report.level, RiskLevel.modere);
    expect(report.reasons(fr), hasLength(2));
  });

  test('app système avec SMS, appels, micro : niveau Système', () {
    final report = calculateAppRisk(
      cleanApp(
        isSystemApp: true,
        installerPackage: null,
        notificationListener: true,
        requestsOverlay: true,
        targetSdk: 23,
        permissions: [
          'READ_SMS',
          'RECEIVE_SMS',
          'READ_CALL_LOG',
          'RECORD_AUDIO',
          'ACCESS_BACKGROUND_LOCATION',
        ],
      ),
    );
    expect(report.score, 0);
    expect(report.level, RiskLevel.systeme);
    expect(report.level.label(fr), 'Système');
    expect(report.reasons(fr), isEmpty);
    expect(report.needsReview, isFalse);
  });

  test('chaque boutique de fabricant : +5', () {
    for (final store in [
      'com.huawei.appmarket',
      'com.sec.android.app.samsungapps',
      'com.xiaomi.market',
      'com.xiaomi.mipicks',
    ]) {
      final report = calculateAppRisk(cleanApp(installerPackage: store));
      expect(report.score, 5, reason: store);
    }
  });

  test('tous les signaux : plafonné à 100', () {
    final report = calculateAppRisk(
      cleanApp(
        accessibility: true,
        installerPackage: 'com.inconnu.store',
        deviceAdmin: true,
        notificationListener: true,
        requestsOverlay: true,
        targetSdk: 23,
        permissions: [
          'READ_SMS',
          'RECEIVE_SMS',
          'RECORD_AUDIO',
          'READ_CALL_LOG',
          'ACCESS_BACKGROUND_LOCATION',
          'READ_CONTACTS',
          'CAMERA',
        ],
      ),
    );
    expect(report.score, 100);
    expect(report.level, RiskLevel.eleve);
    expect(report.reasons(fr), hasLength(13)); // 12 règles + la combinaison
  });

  test('app système sans installateur : pas pénalisée', () {
    final report = calculateAppRisk(
      cleanApp(isSystemApp: true, installerPackage: null),
    );
    expect(report.score, 0);
    expect(report.level, RiskLevel.systeme);
  });

  test('app système installée par un autre store : pas pénalisée', () {
    final report = calculateAppRisk(
      cleanApp(isSystemApp: true, installerPackage: 'com.autre.store'),
    );
    expect(report.score, 0);
    expect(report.level, RiskLevel.systeme);
  });

  group('résumé', () {
    AppRiskReport reportOf(RiskLevel level) =>
        AppRiskReport(score: 0, level: level, rules: const []);

    test('les apps système ne sont jamais « à vérifier »', () {
      final summary = appsScanSummary(fr, [
        reportOf(RiskLevel.eleve),
        reportOf(RiskLevel.modere),
        reportOf(RiskLevel.faible),
        reportOf(RiskLevel.systeme),
        reportOf(RiskLevel.systeme),
      ]);
      expect(summary, '5 applications analysées, dont 2 à vérifier.');
    });

    test('seulement des apps système : aucune à vérifier', () {
      final summary = appsScanSummary(fr, [
        reportOf(RiskLevel.systeme),
        reportOf(RiskLevel.systeme),
      ]);
      expect(summary, '2 applications analysées, aucune à vérifier.');
    });

    test('une seule app : singulier', () {
      expect(
        appsScanSummary(fr, [reportOf(RiskLevel.faible)]),
        '1 application analysée, aucune à vérifier.',
      );
    });
  });

  test('targetSdk 26 : pas pénalisé ; 0 (inconnu) : pas pénalisé', () {
    expect(calculateAppRisk(cleanApp(targetSdk: 26)).score, 0);
    expect(calculateAppRisk(cleanApp(targetSdk: 0)).score, 0);
  });

  test('READ_SMS + RECEIVE_SMS : comptés une seule fois', () {
    final report = calculateAppRisk(
      cleanApp(permissions: ['READ_SMS', 'RECEIVE_SMS']),
    );
    expect(report.score, 15);
    expect(report.reasons(fr), hasLength(1));
  });

  test('permission sans règle (internet) : aucun point', () {
    final report = calculateAppRisk(cleanApp(permissions: ['INTERNET']));
    expect(report.score, 0);
  });

  test('niveaux : 0-29 faible, 30-59 modéré, 60+ élevé', () {
    expect(riskLevelFor(0), RiskLevel.faible);
    expect(riskLevelFor(29), RiskLevel.faible);
    expect(riskLevelFor(30), RiskLevel.modere);
    expect(riskLevelFor(59), RiskLevel.modere);
    expect(riskLevelFor(60), RiskLevel.eleve);
    expect(riskLevelFor(100), RiskLevel.eleve);
  });

  // Chaque règle seule : les points attendus et la raison affichée.
  group('chaque règle isolée', () {
    final cases = <String, (InstalledApp, int, String)>{
      'accessibilité': (
        cleanApp(accessibility: true),
        30,
        "Peut lire tout ce qui s'affiche à l'écran et agir à votre place",
      ),
      "source inconnue (pas d'installateur)": (
        cleanApp(installerPackage: null),
        25,
        'Installée en dehors du Play Store',
      ),
      'source inconnue (boutique non reconnue)': (
        cleanApp(installerPackage: 'com.autre.store'),
        25,
        'Installée en dehors du Play Store',
      ),
      'AppGallery': (
        cleanApp(installerPackage: 'com.huawei.appmarket'),
        5,
        'Installée depuis une boutique autre que le Play Store '
            '(contrôles différents)',
      ),
      'administrateur': (
        cleanApp(deviceAdmin: true),
        20,
        "Est administrateur de l'appareil et peut compliquer sa désinstallation",
      ),
      'READ_SMS': (
        cleanApp(permissions: ['READ_SMS']),
        15,
        'Peut lire vos SMS, y compris les codes de vérification bancaires',
      ),
      'RECEIVE_SMS': (
        cleanApp(permissions: ['RECEIVE_SMS']),
        15,
        'Peut lire vos SMS, y compris les codes de vérification bancaires',
      ),
      'notifications': (
        cleanApp(notificationListener: true),
        15,
        'Peut lire toutes vos notifications, y compris vos messages',
      ),
      'micro': (
        cleanApp(permissions: ['RECORD_AUDIO']),
        10,
        'Peut utiliser le micro',
      ),
      "journal d'appels": (
        cleanApp(permissions: ['READ_CALL_LOG']),
        10,
        "Peut consulter l'historique de vos appels",
      ),
      'superposition': (
        cleanApp(requestsOverlay: true),
        10,
        "Peut s'afficher par-dessus les autres applications",
      ),
      'localisation en arrière-plan': (
        cleanApp(permissions: ['ACCESS_BACKGROUND_LOCATION']),
        10,
        "Peut connaître votre position même quand vous ne l'utilisez pas",
      ),
      'targetSdk 25': (
        cleanApp(targetSdk: 25),
        10,
        "Conçue pour une ancienne version d'Android, avec moins de protections",
      ),
      'contacts': (
        cleanApp(permissions: ['READ_CONTACTS']),
        5,
        'Peut lire vos contacts',
      ),
      'caméra': (
        cleanApp(permissions: ['CAMERA']),
        5,
        "Peut utiliser l'appareil photo",
      ),
    };

    cases.forEach((name, testCase) {
      final (app, points, reason) = testCase;
      test('$name : +$points', () {
        final report = calculateAppRisk(app);
        expect(report.score, points);
        expect(report.reasons(fr), [reason]);
      });
    });
  });
}
