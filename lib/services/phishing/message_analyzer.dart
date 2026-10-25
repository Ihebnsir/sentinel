import '../../l10n/l10n.dart';
import 'phishing_model.dart';
import 'url_analyzer.dart';

/// Le verdict affiché à l'utilisateur, du plus grave au moins grave.
/// Le nom (« arnaque »…) est envoyé tel quel à Kotlin.
enum Verdict {
  arnaque,
  suspect,
  rien;

  String label(AppLocalizations l) => switch (this) {
    arnaque => l.verdictScam,
    suspect => l.verdictSuspect,
    rien => l.verdictNothing,
  };
}

/// À partir de cette probabilité, l'IA seule suffit pour « Arnaque probable ».
const scamThreshold = 0.8;

/// À partir de cette probabilité, l'IA seule suffit pour « Suspect ».
const suspectThreshold = 0.5;

/// Ce qu'on montre à l'utilisateur après l'analyse d'un message.
/// Les phrases sont écrites à l'affichage, dans la langue de l'app.
class MessageAnalysis {
  const MessageAnalysis({
    required this.verdict,
    required this.probability,
    required this.links,
    this.hiddenCharacters = false,
    this.scamWords = const [],
  });

  final Verdict verdict;
  final double probability; // probabilité d'arnaque donnée par l'IA (0 à 1)
  final List<AnalyzedLink> links;
  final bool hiddenCharacters; // caractères cachés ou inversés (SEN-12)
  final List<String> scamWords; // vide si l'IA ne penche pas vers « arnaque »

  /// Probabilité en pourcentage entier, ex : 0,874 → 87.
  int get percent => (probability * 100).round();

  /// Les raisons : caractères cachés, liens, puis mots typiques.
  /// Une même phrase n'apparaît qu'une fois.
  List<String> reasons(AppLocalizations l) {
    final reasons = <String>[if (hiddenCharacters) l.reasonHiddenCharacters];
    for (final finding in [for (final link in links) ...link.findings]) {
      final reason = finding.reason(l);
      if (!reasons.contains(reason)) reasons.add(reason);
    }
    if (scamWords.isNotEmpty) {
      final words = scamWords.map(l.reasonQuotedWord).join(l.listSeparator);
      reasons.add(l.reasonScamWords(words));
    }
    return reasons;
  }

  String advice(AppLocalizations l) => adviceFor(l, verdict);
}

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

  return MessageAnalysis(
    verdict: verdict,
    probability: p,
    links: links,
    hiddenCharacters: deceptive,
    // Les mots ne sont montrés que si l'IA penche vers « arnaque ».
    scamWords: p >= suspectThreshold ? prediction.suspiciousWords : const [],
  );
}

/// Le conseil à suivre pour chaque verdict.
String adviceFor(AppLocalizations l, Verdict verdict) => switch (verdict) {
  Verdict.arnaque => l.adviceScam,
  Verdict.suspect => l.adviceSuspect,
  Verdict.rien => l.adviceNothing,
};
