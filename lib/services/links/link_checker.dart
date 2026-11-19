import '../../l10n/l10n.dart';
import '../phishing/url_analyzer.dart';
import 'hidden_characters.dart';

/// Le verdict affiché, du plus grave au moins grave.
enum Verdict {
  dangereux,
  suspect,
  rien;

  String label(AppLocalizations l) => switch (this) {
    dangereux => l.verdictDangerous,
    suspect => l.verdictSuspect,
    rien => l.verdictNothingKnown,
  };

  /// Le conseil à suivre.
  String advice(AppLocalizations l) => switch (this) {
    dangereux => l.adviceDangerous,
    suspect => l.adviceSuspect,
    rien => l.adviceNothingKnown,
  };
}

/// Réponse des listes du pare-feu (FirewallEngine.checkDomain, Kotlin).
class DomainCheck {
  const DomainCheck({
    required this.allowed,
    required this.dangerous,
    this.listsAvailable = true,
  });

  /// Valeurs inattendues : rien d'autorisé, rien de dangereux.
  factory DomainCheck.fromMap(Map<Object?, Object?> map) => DomainCheck(
    allowed: map['allowed'] == true,
    dangerous: map['dangerous'] == true,
    listsAvailable: map['listsAvailable'] != false,
  );

  final bool allowed; // dans la liste blanche de l'utilisateur
  final bool dangerous; // dans la liste « Malware et hameçonnage »
  final bool listsAvailable; // false : liste illisible (rien vérifié)
}

// Lien collé à un mot sans espace (« هناhttps://… », « Lien:https://… »).
final _gluedScheme = RegExp(r'(?<![\s\w/])(?=https?://)', caseSensitive: false);
final _gluedWww = RegExp(r'(?<![\s\w/.:@-])(?=www\.)', caseSensitive: false);

/// Le premier lien d'un texte partagé, sélectionné ou collé, ou null.
/// Le lien est lu comme il s'affiche (caractères cachés retirés).
AnalyzedLink? extractFirstLink(String text) {
  final visible = normalizeText(text)
      .replaceAll(_gluedScheme, ' ')
      .replaceAll(_gluedWww, ' ');
  final links = analyzeLinks(visible);
  return links.isEmpty ? null : links.first;
}

/// Ce que Sentinel pense d'un lien. Rien n'est enregistré ni envoyé.
class LinkCheck {
  const LinkCheck({
    required this.link,
    this.lists,
    this.hiddenCharacters = false,
  });

  final AnalyzedLink link;

  /// null : listes non consultées (hors Android, adresse IP, échec).
  final DomainCheck? lists;

  /// Caractères cachés ou inversés dans le texte d'origine (SEN-12).
  final bool hiddenCharacters;

  bool get allowed => lists?.allowed == true;

  /// Lien raccourci : la vraie adresse n'est pas visible sans l'ouvrir.
  bool get isShortener => link.has(LinkSignal.raccourcisseur);

  /// Le domaine où mène vraiment le lien, neutralisé : « site[.]xyz ».
  String get realDestination => defang(registrableDomain(link.host));

  Verdict get verdict {
    if (allowed) return Verdict.rien; // choix de l'utilisateur
    if (lists?.dangerous == true ||
        link.has(LinkSignal.usurpationMarque) ||
        link.has(LinkSignal.adresseIp)) {
      return Verdict.dangereux;
    }
    if (link.findings.isNotEmpty || hiddenCharacters) return Verdict.suspect;
    return Verdict.rien;
  }

  /// Les raisons, de la plus grave à la moins grave, sans doublon.
  List<String> reasons(AppLocalizations l) {
    if (allowed) return [l.linkReasonAllowed(link.host)];
    final reasons = <String>[
      if (lists?.dangerous == true) l.linkReasonListed(link.host),
      if (hiddenCharacters) l.reasonHiddenCharacters,
    ];
    for (final finding in link.findings) {
      final reason = finding.reason(l);
      if (!reasons.contains(reason)) reasons.add(reason);
    }
    if (reasons.isEmpty && lists?.listsAvailable == true) {
      reasons.add(l.linkReasonNotListed);
    }
    return reasons;
  }
}

/// Vérifie le premier lien de [text] ; null s'il n'y en a aucun.
/// [lists] : réponse du pare-feu pour ce lien, si on l'a.
LinkCheck? checkText(String text, {DomainCheck? lists}) {
  final link = extractFirstLink(text);
  if (link == null) return null;
  return LinkCheck(
    link: link,
    lists: lists,
    hiddenCharacters: hasDeceptiveCharacters(text),
  );
}
