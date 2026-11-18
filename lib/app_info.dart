import 'package:flutter/services.dart' show appFlavor;

/// Version affichée dans Réglages. Doit suivre `version:` de pubspec.yaml
/// (vérifié par test/settings_screen_test.dart).
const appVersion = '1.0.1';

/// Variante Android, donnée par `flutter build apk --flavor standard|complete`
/// (voir android/app/build.gradle.kts et docs/RELEASE.md) :
/// - standard : APK GitHub, sans la protection automatique (lecteur de
///   notifications), que Google Play Protect bloque hors du Play Store ;
/// - complete : version Google Play.
/// Sans --flavor (flutter test, Windows) : comme complete.
const isStandardFlavor = appFlavor == 'standard';

/// La protection automatique existe-t-elle dans cette variante ?
const autoProtectionAvailable = !isStandardFlavor;

/// Nom du paquet Android (applicationIdSuffix de la variante standard).
const ownPackageName = isStandardFlavor
    ? 'com.iheb.sentinel.standard'
    : 'com.iheb.sentinel';

/// Dépôt public du projet (GitHub ignore la casse du nom de compte).
const repoUrl = 'https://github.com/ihebnsir/sentinel';

/// Rapport d'audit complet, en français.
const auditReportUrl = '$repoUrl/blob/main/docs/audit/RAPPORT_AUDIT.md';

/// Procédure pour signaler une faille en privé.
const securityPolicyUrl = '$repoUrl/blob/main/SECURITY.md';
