import '../l10n/l10n.dart';
import '../models/installed_app.dart';
import 'apps/known_apps.dart';
import 'apps/stalkerware_ioc.dart';

/// Les niveaux de risque.
/// « Système » : app d'Android ou du fabricant, permissions non évaluées.
enum RiskLevel {
  systeme,
  faible,
  modere,
  eleve;

  /// Libellé affiché, ex : « Élevé ».
  String label(AppLocalizations l) => switch (this) {
    systeme => l.riskLevelSystem,
    faible => l.riskLevelLow,
    modere => l.riskLevelModerate,
    eleve => l.riskLevelHigh,
  };
}

/// Les règles qui peuvent s'appliquer à une app. L'explication est écrite
/// à l'affichage, dans la langue de l'app ([AppRiskReport.reasons]).
enum AppRiskRule {
  stalkerware,
  modifiedCopy,
  impersonation,
  knownMod,
  spyProfile,
  bankingCombo,
  accessibility,
  unknownSource,
  deviceAdmin,
  debugCert,
  sms,
  notifications,
  microphone,
  callLog,
  overlay,
  backgroundLocation,
  oldTarget,
  otherStore,
  contacts,
  camera;

  /// [brand] : nom de l'app imitée (règles sur l'identité).
  String reason(AppLocalizations l, String brand) => switch (this) {
    stalkerware => l.riskStalkerware,
    modifiedCopy => l.riskModifiedCopy(brand),
    impersonation => l.riskImpersonation(brand),
    knownMod => l.riskKnownMod(brand),
    spyProfile => l.riskSpyProfile,
    bankingCombo => l.riskBankingCombo,
    accessibility => l.riskAccessibility,
    unknownSource => l.riskUnknownSource,
    deviceAdmin => l.riskDeviceAdmin,
    debugCert => l.riskDebugCert,
    sms => l.riskSms,
    notifications => l.riskNotifications,
    microphone => l.riskMicrophone,
    callLog => l.riskCallLog,
    overlay => l.riskOverlay,
    backgroundLocation => l.riskBackgroundLocation,
    oldTarget => l.riskOldTarget,
    otherStore => l.riskOtherStore,
    contacts => l.riskContacts,
    camera => l.riskCamera,
  };
}

/// Résultat de l'analyse d'une app : score, niveau et explications.
class AppRiskReport {
  const AppRiskReport({
    required this.score,
    required this.level,
    required this.rules,
    this.identity = AppIdentity.unknown,
    this.stalkerwareName,
    this.spyProfile = false,
  });

  final int score; // de 0 à 100
  final RiskLevel level;
  final List<AppRiskRule> rules; // de la plus grave à la moins grave
  final AppIdentity identity; // comparaison avec les apps officielles
  final String? stalkerwareName; // nom du stalkerware connu, sinon null
  final bool spyProfile; // icône cachée + accès typiques d'un espion

  /// Logiciel espion connu ou probable : conseils spécifiques à afficher.
  bool get spywareSuspected => stalkerwareName != null || spyProfile;

  /// Une app « à vérifier » : niveau modéré ou élevé (jamais « Système »).
  bool get needsReview =>
      level == RiskLevel.modere || level == RiskLevel.eleve;

  /// Les explications, de la plus grave à la moins grave.
  List<String> reasons(AppLocalizations l) => [
    for (final rule in rules) rule.reason(l, identity.brand ?? ''),
  ];

  /// La raison la plus grave, ou null si aucune.
  String? mainReason(AppLocalizations l) =>
      rules.isEmpty ? null : rules.first.reason(l, identity.brand ?? '');
}

/// Score maximal, même si plusieurs règles s'additionnent au-delà.
const maxAppRiskScore = 100;

/// En dessous de cette version (Android 8), l'app échappe à des protections.
const minSafeTargetSdk = 26;

/// Niveau correspondant à un score : 0-29 faible, 30-59 modéré, 60+ élevé.
RiskLevel riskLevelFor(int score) {
  if (score >= 60) return RiskLevel.eleve;
  if (score >= 30) return RiskLevel.modere;
  return RiskLevel.faible;
}

/// Nombre minimal d'accès d'espion, en plus de l'icône cachée.
const minSpyAccesses = 2;

/// Icône cachée ET au moins [minSpyAccesses] accès typiques d'un espion.
bool hasSpyProfile(InstalledApp app) {
  if (app.hasLauncherIcon) return false;
  bool has(String p) => app.hasPermission('android.permission.$p');
  final accesses = [
    app.accessibilityServiceEnabled,
    has('ACCESS_BACKGROUND_LOCATION'),
    has('READ_SMS') || has('RECEIVE_SMS'),
    has('READ_CALL_LOG'),
    app.notificationListenerEnabled,
    app.isDeviceAdmin,
  ];
  return accesses.where((a) => a).length >= minSpyAccesses;
}

/// Calcule le risque d'une app à partir de règles simples et explicables.
/// Fonction « pure » : mêmes entrées = même résultat, aucun appel à Android.
/// [ioc] : indicateurs de stalkerware (null = pas encore chargés).
/// [known] / [mods] : remplaçables dans les tests.
AppRiskReport calculateAppRisk(
  InstalledApp app, {
  StalkerwareIoc? ioc,
  List<KnownApp> known = knownApps,
  List<ModdedApp> mods = knownModdedApps,
}) {
  final report = _rulesReport(app, known, mods);
  // Stalkerware connu : score maximal, même pour une app système
  // (certains se déguisent en composant du système).
  final stalkerware = ioc?.match(app);
  if (stalkerware == null) return report;
  return AppRiskReport(
    score: maxAppRiskScore,
    level: RiskLevel.eleve,
    rules: List.unmodifiable([AppRiskRule.stalkerware, ...report.rules]),
    identity: report.identity,
    stalkerwareName: stalkerware,
    spyProfile: report.spyProfile,
  );
}

/// Les règles rangées de la plus grave à la moins grave : identité de l'app
/// et profil espion d'abord, puis la combinaison accessibilité + source
/// inconnue.
AppRiskReport _rulesReport(
  InstalledApp app,
  List<KnownApp> known,
  List<ModdedApp> mods,
) {
  var score = 0;
  final rules = <AppRiskRule>[];

  // Ajoute les points et la règle si elle s'applique.
  void rule(bool applies, int points, AppRiskRule appRule) {
    if (!applies) return;
    score += points;
    rules.add(appRule);
  }

  bool has(String permission) =>
      app.hasPermission('android.permission.$permission');

  void accessibilityRule() =>
      rule(app.accessibilityServiceEnabled, 30, AppRiskRule.accessibility);

  void deviceAdminRule() =>
      rule(app.isDeviceAdmin, 20, AppRiskRule.deviceAdmin);

  // App système : ses permissions étendues sont normales, on ne les compte
  // pas. On garde seulement l'accessibilité et l'administration, car des
  // applications malveillantes préinstallées existent sur certains téléphones.
  if (app.isSystemApp) {
    accessibilityRule();
    deviceAdminRule();
    if (rules.isEmpty) {
      return const AppRiskReport(
        score: 0,
        level: RiskLevel.systeme,
        rules: [],
      );
    }
    return AppRiskReport(
      score: score,
      level: riskLevelFor(score),
      rules: List.unmodifiable(rules),
    );
  }

  final unknownSource = !app.isFromOfficialStore;
  final otherStore = app.isFromOfficialStore && !app.isFromPlayStore;
  final identity = identifyApp(app, known: known, mods: mods);
  final spyProfile = hasSpyProfile(app);

  // Identité : copie repackagée, usurpation de nom, mod connu.
  rule(
    identity.verdict == IdentityVerdict.modifiedCopy,
    80,
    AppRiskRule.modifiedCopy,
  );
  rule(
    identity.verdict == IdentityVerdict.impersonation,
    60,
    AppRiskRule.impersonation,
  );
  rule(
    identity.verdict == IdentityVerdict.knownMod,
    45,
    AppRiskRule.knownMod,
  );
  rule(spyProfile, 40, AppRiskRule.spyProfile);

  // Règle de combinaison, toujours affichée en premier :
  // c'est le schéma des chevaux de Troie bancaires.
  rule(
    app.accessibilityServiceEnabled && unknownSource,
    15,
    AppRiskRule.bankingCombo,
  );
  accessibilityRule();
  rule(unknownSource, 25, AppRiskRule.unknownSource);
  deviceAdminRule();
  rule(app.debugCert, 15, AppRiskRule.debugCert);
  rule(has('READ_SMS') || has('RECEIVE_SMS'), 15, AppRiskRule.sms);
  rule(app.notificationListenerEnabled, 15, AppRiskRule.notifications);
  rule(has('RECORD_AUDIO'), 10, AppRiskRule.microphone);
  rule(has('READ_CALL_LOG'), 10, AppRiskRule.callLog);
  rule(app.requestsOverlay, 10, AppRiskRule.overlay);
  rule(
    has('ACCESS_BACKGROUND_LOCATION'),
    10,
    AppRiskRule.backgroundLocation,
  );
  // targetSdk à 0 : valeur inconnue, on ne pénalise pas.
  rule(
    app.targetSdk > 0 && app.targetSdk < minSafeTargetSdk,
    10,
    AppRiskRule.oldTarget,
  );
  // Boutique d'un fabricant (AppGallery, Galaxy Store…) : petit signal.
  rule(otherStore, 5, AppRiskRule.otherStore);
  rule(has('READ_CONTACTS'), 5, AppRiskRule.contacts);
  rule(has('CAMERA'), 5, AppRiskRule.camera);

  final capped = score > maxAppRiskScore ? maxAppRiskScore : score;
  return AppRiskReport(
    score: capped,
    level: riskLevelFor(capped),
    rules: List.unmodifiable(rules),
    identity: identity,
    spyProfile: spyProfile,
  );
}

/// Résumé de l'analyse, ex : « 34 applications analysées, dont 2 à vérifier. »
/// Les apps « Système » comptent dans le total, jamais dans « à vérifier ».
String appsScanSummary(AppLocalizations l, List<AppRiskReport> reports) {
  final total = reports.length;
  final toReview = reports.where((r) => r.needsReview).length;
  final analyzed = l.appsAnalyzed(total, l.number(total));
  if (toReview == 0) return l.appsSummaryNoneToReview(analyzed);
  return l.appsSummaryToReview(analyzed, l.number(toReview));
}
