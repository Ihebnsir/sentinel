import '../../l10n/l10n.dart';
import '../../models/wifi_status.dart';
import '../phishing/message_analyzer.dart';
import '../phishing/phishing_model.dart';
import 'qr_content.dart';

/// Gravité d'un avertissement propre aux QR codes.
enum QrSeverity {
  danger, // « Arnaque probable », action interdite
  prudence, // au moins « Suspect »
  info, // à lire, ne change pas le verdict
}

/// Avertissements propres aux QR codes (en plus de l'analyse du texte).
enum QrWarning {
  lienDangereux(QrSeverity.danger), // javascript:, intent:, file:…
  codeUssd(QrSeverity.danger), // * ou # dans un numéro à appeler
  numeroCourt(QrSeverity.prudence), // SMS vers un numéro court
  paiement(QrSeverity.info), // vérifier bénéficiaire et montant
  wifiOuvert(QrSeverity.info), // réseau sans mot de passe
  wifiWep(QrSeverity.info); // protection cassée depuis longtemps

  const QrWarning(this.severity);

  final QrSeverity severity;

  String reason(AppLocalizations l) => switch (this) {
    lienDangereux => l.qrWarningUnsafeLink,
    codeUssd => l.qrWarningUssd,
    numeroCourt => l.qrWarningShortNumber,
    paiement => l.qrWarningPayment,
    wifiOuvert => l.qrWarningWifiOpen,
    wifiWep => l.qrWarningWifiWep,
  };
}

/// Ce que l'utilisateur peut faire du contenu, toujours après confirmation.
enum QrAction { ouvrirLien, appeler, envoyerSms, ouvrirPaiement }

/// Le bilan d'un QR code, prêt à afficher.
class QrAssessment {
  const QrAssessment({
    required this.content,
    this.analysis,
    this.warnings = const [],
    this.verdict,
    this.action,
    this.actionAllowed = false,
  });

  final QrContent content;
  final MessageAnalysis? analysis; // analyse du lien ou du texte, sinon null
  final List<QrWarning> warnings;
  final Verdict? verdict; // null : rien à juger (numéro, Wi-Fi…)
  final QrAction? action; // null : aucune action proposée
  final bool actionAllowed; // false : bouton désactivé (arnaque probable)

  /// Statut Wi-Fi équivalent, pour réutiliser assessWifi (wifi_risk.dart).
  WifiStatus? get wifiStatus => switch (content) {
    QrWifi(:final security) => WifiStatus(connected: true, security: security),
    _ => null,
  };
}

/// Le texte à analyser comme un message (lien ou texte), sinon null.
String? textToAnalyze(QrContent content) => switch (content) {
  QrLink(:final url) => url,
  QrText(:final raw) when raw.trim().isNotEmpty => raw,
  QrSms(:final body) when body.isNotEmpty => body,
  _ => null,
};

/// Décide du verdict et de l'action. Fonction pure : [predict] est l'IA
/// anti-arnaque (remplacée par un faux modèle dans les tests).
/// Jamais d'ouverture automatique : l'action est seulement proposée.
QrAssessment assessQr(
  QrContent content,
  PhishingPrediction Function(String text) predict,
) {
  final text = textToAnalyze(content);
  final analysis = text == null ? null : analyzeMessage(text, predict(text));

  final warnings = <QrWarning>[
    ...switch (content) {
      QrUnsafeLink() => [QrWarning.lienDangereux],
      QrPhone(:final number) when isUssdCode(number) => [QrWarning.codeUssd],
      QrSms(:final number) when isUssdCode(number) => [QrWarning.codeUssd],
      QrSms(:final number) when isShortNumber(number) => [
        QrWarning.numeroCourt,
      ],
      QrPayment() => [QrWarning.paiement],
      QrWifi(security: WifiSecurity.open) => [QrWarning.wifiOuvert],
      QrWifi(security: WifiSecurity.wep) => [QrWarning.wifiWep],
      _ => <QrWarning>[],
    },
  ];

  final verdict = _worst([
    analysis?.verdict,
    for (final w in warnings)
      switch (w.severity) {
        QrSeverity.danger => Verdict.arnaque,
        QrSeverity.prudence => Verdict.suspect,
        QrSeverity.info => null,
      },
  ]);

  final action = switch (content) {
    QrLink() => QrAction.ouvrirLien,
    QrPhone() => QrAction.appeler,
    QrSms() => QrAction.envoyerSms,
    QrPayment(:final uri?) => uri.isEmpty ? null : QrAction.ouvrirPaiement,
    _ => null,
  };

  return QrAssessment(
    content: content,
    analysis: analysis,
    warnings: warnings,
    verdict: verdict,
    action: action,
    // « Arnaque probable » : le bouton reste visible mais désactivé.
    actionAllowed: action != null && verdict != Verdict.arnaque,
  );
}

/// * ou # dans un numéro : code USSD (renvoi d'appel, effacement…).
bool isUssdCode(String number) => number.contains(RegExp('[*#]'));

/// Numéro court (6 chiffres ou moins) : souvent surtaxé.
bool isShortNumber(String number) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  return digits.isNotEmpty && digits.length <= 6;
}

// Le verdict le plus grave (l'énumération va du pire au meilleur).
Verdict? _worst(List<Verdict?> verdicts) {
  Verdict? worst;
  for (final v in verdicts) {
    if (v != null && (worst == null || v.index < worst.index)) worst = v;
  }
  return worst;
}
