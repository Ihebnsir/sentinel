import 'phishing_model.dart';
import 'url_analyzer.dart';

/// Le verdict affiché à l'utilisateur, du plus grave au moins grave.
enum Verdict {
  arnaque('Arnaque probable'),
  suspect('Suspect'),
  rien('Rien de suspect');

  const Verdict(this.label);

  final String label;
}

/// À partir de cette probabilité, l'IA seule suffit pour « Arnaque probable ».
const scamThreshold = 0.8;

/// À partir de cette probabilité, l'IA seule suffit pour « Suspect ».
const suspectThreshold = 0.5;

/// Ce qu'on montre à l'utilisateur après l'analyse d'un message.
class MessageAnalysis {
  const MessageAnalysis({
    required this.verdict,
    required this.probability,
    required this.reasons,
    required this.advice,
    required this.links,
  });

  final Verdict verdict;
  final double probability; // probabilité d'arnaque donnée par l'IA (0 à 1)
  final List<String> reasons; // liens d'abord, puis mots typiques
  final String advice;
  final List<AnalyzedLink> links;

  /// Probabilité en pourcentage entier, ex : 0,874 → 87.
  int get percent => (probability * 100).round();
}

/// Raison affichée quand le message cache des caractères (SEN-12).
const hiddenCharactersReason =
    "Caractères invisibles ou d'inversion de texte (technique d'arnaque)";

/// Combine la prédiction de l'IA et l'analyse des liens en un verdict.
MessageAnalysis analyzeMessage(String text, PhishingPrediction prediction) {
  // Les liens sont lus comme ils s'affichent (caractères cachés retirés).
  final links = analyzeLinks(normalizeMessage(text));
  final findings = [for (final link in links) ...link.findings];
  final p = prediction.probability;
  final deceptive = hasDeceptiveCharacters(text);

  bool found(LinkSignal s) => findings.any((f) => f.signal == s);
  final Verdict verdict;
  if (p >= scamThreshold ||
      found(LinkSignal.usurpationMarque) ||
      found(LinkSignal.adresseIp)) {
    verdict = Verdict.arnaque;
  } else if (p >= suspectThreshold || findings.isNotEmpty || deceptive) {
    verdict = Verdict.suspect; // autre signal de lien, ou texte piégé
  } else {
    verdict = Verdict.rien;
  }

  final reasons = <String>[if (deceptive) hiddenCharactersReason];
  for (final finding in findings) {
    if (!reasons.contains(finding.reason)) reasons.add(finding.reason);
  }
  // Les mots ne sont montrés que si l'IA penche vers « arnaque ».
  if (p >= suspectThreshold && prediction.suspiciousWords.isNotEmpty) {
    final words = prediction.suspiciousWords.map((w) => '« $w »').join(', ');
    reasons.add('Mots typiques des arnaques : $words');
  }

  return MessageAnalysis(
    verdict: verdict,
    probability: p,
    reasons: reasons,
    advice: adviceFor(verdict),
    links: links,
  );
}

/// Le conseil à suivre pour chaque verdict.
String adviceFor(Verdict verdict) => switch (verdict) {
      Verdict.arnaque => 'Ne cliquez pas sur le lien et ne communiquez aucun '
          'code. Votre banque ou La Poste ne vous demandent jamais de payer '
          'par SMS. Supprimez ce message.',
      Verdict.suspect => "Soyez prudent : n'ouvrez pas le lien et ne donnez "
          "aucune information. En cas de doute, appelez l'organisme au "
          'numéro de son site officiel.',
      Verdict.rien => "Aucun signe d'arnaque trouvé. Restez quand même "
          'vigilant : ne communiquez jamais vos codes ni vos mots de passe.',
    };
