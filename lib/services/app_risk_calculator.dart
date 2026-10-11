import '../models/installed_app.dart';

/// Les niveaux de risque, avec leur libellé affiché.
/// « Système » : app d'Android ou du fabricant, permissions non évaluées.
enum RiskLevel {
  systeme('Système'),
  faible('Faible'),
  modere('Modéré'),
  eleve('Élevé');

  const RiskLevel(this.label);

  final String label;
}

/// Résultat de l'analyse d'une app : score, niveau et explications.
class AppRiskReport {
  const AppRiskReport({
    required this.score,
    required this.level,
    required this.reasons,
  });

  final int score; // de 0 à 100
  final RiskLevel level;
  final List<String> reasons; // de la plus grave à la moins grave

  /// Une app « à vérifier » : niveau modéré ou élevé (jamais « Système »).
  bool get needsReview =>
      level == RiskLevel.modere || level == RiskLevel.eleve;

  /// La raison la plus grave, ou null si aucune.
  String? get mainReason => reasons.isEmpty ? null : reasons.first;
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

/// Calcule le risque d'une app à partir de règles simples et explicables.
/// Fonction « pure » : mêmes entrées = même résultat, aucun appel à Android.
/// Les règles sont rangées de la plus grave à la moins grave,
/// la combinaison accessibilité + source inconnue en tête.
AppRiskReport calculateAppRisk(InstalledApp app) {
  var score = 0;
  final reasons = <String>[];

  // Ajoute les points et l'explication si la règle s'applique.
  void rule(bool applies, int points, String reason) {
    if (!applies) return;
    score += points;
    reasons.add(reason);
  }

  bool has(String permission) =>
      app.hasPermission('android.permission.$permission');

  void accessibilityRule() => rule(
        app.accessibilityServiceEnabled,
        30,
        "Peut lire tout ce qui s'affiche à l'écran et agir à votre place",
      );

  void deviceAdminRule() => rule(
        app.isDeviceAdmin,
        20,
        "Est administrateur de l'appareil et peut compliquer sa "
            'désinstallation',
      );

  // App système : ses permissions étendues sont normales, on ne les compte
  // pas. On garde seulement l'accessibilité et l'administration, car des
  // applications malveillantes préinstallées existent sur certains téléphones.
  if (app.isSystemApp) {
    accessibilityRule();
    deviceAdminRule();
    if (reasons.isEmpty) {
      return const AppRiskReport(
        score: 0,
        level: RiskLevel.systeme,
        reasons: [],
      );
    }
    return AppRiskReport(
      score: score,
      level: riskLevelFor(score),
      reasons: List.unmodifiable(reasons),
    );
  }

  final unknownSource = !app.isFromOfficialStore;
  final otherStore = app.isFromOfficialStore && !app.isFromPlayStore;

  // Règle de combinaison, toujours affichée en premier :
  // c'est le schéma des chevaux de Troie bancaires.
  rule(
    app.accessibilityServiceEnabled && unknownSource,
    15,
    'Combinaison typique des applications qui volent les comptes bancaires',
  );
  accessibilityRule();
  rule(unknownSource, 25, 'Installée en dehors du Play Store');
  deviceAdminRule();
  rule(
    has('READ_SMS') || has('RECEIVE_SMS'),
    15,
    'Peut lire vos SMS, y compris les codes de vérification bancaires',
  );
  rule(
    app.notificationListenerEnabled,
    15,
    'Peut lire toutes vos notifications, y compris vos messages',
  );
  rule(has('RECORD_AUDIO'), 10, 'Peut utiliser le micro');
  rule(has('READ_CALL_LOG'), 10, "Peut consulter l'historique de vos appels");
  rule(
    app.requestsOverlay,
    10,
    "Peut s'afficher par-dessus les autres applications",
  );
  rule(
    has('ACCESS_BACKGROUND_LOCATION'),
    10,
    "Peut connaître votre position même quand vous ne l'utilisez pas",
  );
  // targetSdk à 0 : valeur inconnue, on ne pénalise pas.
  rule(
    app.targetSdk > 0 && app.targetSdk < minSafeTargetSdk,
    10,
    "Conçue pour une ancienne version d'Android, avec moins de protections",
  );
  // Boutique d'un fabricant (AppGallery, Galaxy Store…) : petit signal.
  rule(
    otherStore,
    5,
    'Installée depuis une boutique autre que le Play Store '
        '(contrôles différents)',
  );
  rule(has('READ_CONTACTS'), 5, 'Peut lire vos contacts');
  rule(has('CAMERA'), 5, "Peut utiliser l'appareil photo");

  final capped = score > maxAppRiskScore ? maxAppRiskScore : score;
  return AppRiskReport(
    score: capped,
    level: riskLevelFor(capped),
    reasons: List.unmodifiable(reasons),
  );
}

/// Résumé de l'analyse, ex : « 34 applications analysées, dont 2 à vérifier. »
/// Les apps « Système » comptent dans le total, jamais dans « à vérifier ».
String appsScanSummary(List<AppRiskReport> reports) {
  final total = reports.length;
  final toReview = reports.where((r) => r.needsReview).length;
  final analysed = total > 1
      ? '$total applications analysées'
      : '$total application analysée';
  if (toReview == 0) return '$analysed, aucune à vérifier.';
  return '$analysed, dont $toReview à vérifier.';
}
