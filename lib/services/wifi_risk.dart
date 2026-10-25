import '../l10n/l10n.dart';
import '../models/wifi_status.dart';

/// Le niveau de sécurité du Wi-Fi, du pire au meilleur.
enum WifiLevel {
  danger,
  faible,
  correct,
  excellent,
  pasDeWifi,
  inconnu;

  /// Texte court affiché en couleur.
  String label(AppLocalizations l) => switch (this) {
    danger => l.wifiLevelDanger,
    faible => l.wifiLevelWeak,
    correct => l.wifiLevelOk,
    excellent => l.wifiLevelExcellent,
    pasDeWifi => l.wifiLevelNone,
    inconnu => l.wifiLevelUnknown,
  };
}

/// Le résultat de l'analyse du Wi-Fi, prêt à afficher.
class WifiReport {
  const WifiReport({
    required this.level,
    required this.title,
    required this.summary,
    required this.explanation,
    this.advice = const [],
    this.suggestPrivateDns = false,
  });

  final WifiLevel level;
  final String title; // ex : « Wi-Fi ouvert »
  final String summary; // une phrase courte pour l'accueil
  final String explanation; // texte complet pour les détails
  final List<String> advice; // conseils, dans l'ordre
  final bool suggestPrivateDns; // afficher le bouton « DNS privé »
}

/// Calcule le niveau et les conseils, dans la langue [l]. Fonction « pure » :
/// même entrée, même résultat, sans appel à Android, donc facile à tester.
WifiReport assessWifi(AppLocalizations l, WifiStatus status) {
  if (!status.connected) {
    return WifiReport(
      level: WifiLevel.pasDeWifi,
      title: l.wifiNoneTitle,
      summary: l.wifiNoneSummary,
      explanation: l.wifiNoneExplanation,
    );
  }

  final base = _bySecurity(l, status);
  var level = base.level;
  var title = base.title;
  var summary = base.summary;
  final explanation = [base.explanation];
  final advice = [...base.advice];

  // Page de connexion : réseau public partagé, au mieux « faible ».
  if (status.captivePortal) {
    if (level != WifiLevel.danger) {
      level = WifiLevel.faible;
      title = l.wifiPublicTitle;
      summary = l.wifiPublicSummary;
    }
    explanation.add(l.wifiCaptiveExplanation);
    advice.add(l.wifiCaptiveAdvice);
    if (!advice.contains(l.wifiAdviceNoBanking)) {
      advice.add(l.wifiAdviceNoBanking);
    }
  }

  // DNS privé désactivé : on conseille de l'activer.
  final dnsOff = status.privateDnsActive == false;
  if (dnsOff) {
    if (level == WifiLevel.excellent) level = WifiLevel.correct;
    explanation.add(l.wifiDnsOffExplanation);
    advice.add(l.wifiDnsOffAdvice);
  }

  return WifiReport(
    level: level,
    title: title,
    summary: summary,
    explanation: explanation.join(' '),
    advice: advice,
    suggestPrivateDns: dnsOff,
  );
}

/// Niveau et textes de départ, selon le type de protection seul.
WifiReport _bySecurity(AppLocalizations l, WifiStatus status) {
  // Conseils réutilisés.
  final noBanking = l.wifiAdviceNoBanking;
  final useMobile = l.wifiAdviceUseMobile;
  final upgradeBox = l.wifiAdviceUpgradeBox;
  switch (status.security) {
    case WifiSecurity.open:
      return WifiReport(
        level: WifiLevel.danger,
        title: l.wifiOpenTitle,
        summary: l.wifiOpenSummary,
        explanation: l.wifiOpenExplanation,
        advice: [noBanking, useMobile],
      );
    case WifiSecurity.wep:
      return WifiReport(
        level: WifiLevel.danger,
        title: l.wifiWepTitle,
        summary: l.wifiWepSummary,
        explanation: l.wifiWepExplanation,
        advice: [noBanking, useMobile, upgradeBox],
      );
    case WifiSecurity.wpa:
      return WifiReport(
        level: WifiLevel.faible,
        title: l.wifiWpaTitle,
        summary: l.wifiWpaSummary,
        explanation: l.wifiWpaExplanation,
        advice: [noBanking, upgradeBox],
      );
    case WifiSecurity.owe:
      return WifiReport(
        level: WifiLevel.faible,
        title: l.wifiOweTitle,
        summary: l.wifiOweSummary,
        explanation: l.wifiOweExplanation,
        advice: [noBanking],
      );
    case WifiSecurity.wpa2:
      return WifiReport(
        level: WifiLevel.correct,
        title: l.wifiWpa2Title,
        summary: l.wifiWpa2Summary,
        explanation: l.wifiWpa2Explanation,
      );
    case WifiSecurity.wpa3:
      return WifiReport(
        level: WifiLevel.excellent,
        title: l.wifiWpa3Title,
        summary: l.wifiWpa3Summary,
        explanation: l.wifiWpa3Explanation,
      );
    case WifiSecurity.enterprise:
      return WifiReport(
        level: WifiLevel.excellent,
        title: l.wifiEnterpriseTitle,
        summary: l.wifiEnterpriseSummary,
        explanation: l.wifiEnterpriseExplanation,
      );
    case WifiSecurity.unknown:
      return WifiReport(
        level: WifiLevel.inconnu,
        title: l.wifiUnknownTitle,
        summary: l.wifiUnknownSummary,
        // Android 11 et avant : seulement avec la localisation.
        explanation: status.sdkInt > 0 && status.sdkInt < 31
            ? l.wifiUnknownOldAndroid
            : l.wifiUnknownExplanation,
        advice: [l.wifiAdvicePublicUnknown],
      );
  }
}
