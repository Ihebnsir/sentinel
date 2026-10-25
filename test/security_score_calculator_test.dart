import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/models/device_security_status.dart';
import 'package:sentinel/models/security_action.dart';
import 'package:sentinel/services/security_score_calculator.dart';
import 'support/l10n.dart';

// Date du jour fixe : les tests donnent le même résultat quel que soit le jour.
final today = DateTime(2026, 10, 11);

/// Un téléphone parfaitement sécurisé ; chaque test change un seul réglage.
DeviceSecurityStatus secureStatus({
  bool screenLock = true,
  bool biometricEnrolled = true,
  bool rooted = false,
  bool developerOptions = false,
  bool usbDebugging = false,
  bool encrypted = true,
  DateTime? securityPatch,
  bool unknownPatch = false,
}) {
  return DeviceSecurityStatus(
    screenLock: screenLock,
    biometricEnrolled: biometricEnrolled,
    rooted: rooted,
    developerOptions: developerOptions,
    usbDebugging: usbDebugging,
    encrypted: encrypted,
    androidVersion: '15',
    sdkInt: 35,
    securityPatch: unknownPatch ? null : securityPatch ?? DateTime(2026, 9, 5),
  );
}

void main() {
  test('tout sécurisé : 100 et aucune action', () {
    final report = calculateSecurityScore(fr, secureStatus(), today);
    expect(report.score, 100);
    expect(report.actions, isEmpty);
  });

  test('sans verrouillage : 75 et une action vers les paramètres sécurité', () {
    final report = calculateSecurityScore(fr, 
      secureStatus(screenLock: false),
      today,
    );
    expect(report.score, 75);
    expect(report.actions, hasLength(1));
    expect(report.actions.single.title, "Configurer un verrouillage d'écran");
    expect(report.actions.single.points, 25);
    expect(report.actions.single.settingsTarget, SettingsTarget.security);
  });

  test('téléphone rooté : 80 et une action sans bouton paramètres', () {
    final report = calculateSecurityScore(fr, secureStatus(rooted: true), today);
    expect(report.score, 80);
    expect(report.actions.single.points, 20);
    expect(report.actions.single.settingsTarget, isNull);
  });

  test('correctif de plus de 90 jours : 80 et action mise à jour', () {
    final report = calculateSecurityScore(fr, 
      secureStatus(securityPatch: DateTime(2026, 6, 1)),
      today,
    );
    expect(report.score, 80);
    expect(report.actions.single.settingsTarget, SettingsTarget.update);
  });

  test('correctif de 89 jours : encore valable', () {
    final patch = today.subtract(const Duration(days: 89));
    final report = calculateSecurityScore(fr, 
      secureStatus(securityPatch: patch),
      today,
    );
    expect(report.score, 100);
  });

  test('correctif de 90 jours pile : dépassé', () {
    final patch = DateTime(today.year, today.month, today.day - 90);
    final report = calculateSecurityScore(fr, 
      secureStatus(securityPatch: patch),
      today,
    );
    expect(report.score, 80);
  });

  test('date du correctif inconnue : comptée comme dépassée', () {
    final report = calculateSecurityScore(fr, 
      secureStatus(unknownPatch: true),
      today,
    );
    expect(report.score, 80);
    expect(report.actions.single.settingsTarget, SettingsTarget.update);
  });

  test('biométrie absente : 90', () {
    final report = calculateSecurityScore(fr, 
      secureStatus(biometricEnrolled: false),
      today,
    );
    expect(report.score, 90);
    expect(report.actions.single.settingsTarget, SettingsTarget.biometric);
  });

  test('options développeur + débogage USB : 80 et deux actions', () {
    final report = calculateSecurityScore(fr, 
      secureStatus(developerOptions: true, usbDebugging: true),
      today,
    );
    expect(report.score, 80);
    expect(report.actions, hasLength(2));
    expect(
      report.actions.map((a) => a.settingsTarget),
      everyElement(SettingsTarget.developer),
    );
  });

  test('stockage non chiffré : 95', () {
    final report = calculateSecurityScore(fr, 
      secureStatus(encrypted: false),
      today,
    );
    expect(report.score, 95);
  });

  test('rien de sécurisé : 0 et sept actions, les plus importantes en premier',
      () {
    final report = calculateSecurityScore(fr, 
      secureStatus(
        screenLock: false,
        biometricEnrolled: false,
        rooted: true,
        developerOptions: true,
        usbDebugging: true,
        encrypted: false,
        unknownPatch: true,
      ),
      today,
    );
    expect(report.score, 0);
    expect(report.actions.map((a) => a.points), [25, 20, 20, 10, 10, 10, 5]);
  });

  test('le score + les points des actions font toujours 100', () {
    final report = calculateSecurityScore(fr, 
      secureStatus(screenLock: false, encrypted: false, usbDebugging: true),
      today,
    );
    final missing = report.actions.fold(0, (sum, a) => sum + a.points);
    expect(report.score + missing, 100);
  });
}
