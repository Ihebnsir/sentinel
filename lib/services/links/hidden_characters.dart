/// Caractères cachés d'un texte partagé ou collé (SEN-12).
/// Un lien piégé peut s'afficher autrement qu'il n'est écrit : on cherche
/// le lien dans le texte tel que l'utilisateur le voit.
library;

/// Caractères retirés avant de chercher un lien (SEN-12) :
/// contrôles de direction du texte et caractères invisibles.
const hiddenCodePoints = {
  0x00AD, // trait d'union conditionnel
  0x061C, // marque de lettre arabe
  0x180E, // séparateur de voyelles mongol
  0x200B, 0x200C, 0x200D, // espace, anti-liant, liant sans largeur
  0x200E, 0x200F, // marques gauche-à-droite, droite-à-gauche
  0x202A, 0x202B, 0x202C, 0x202D, 0x202E, // enchâssements et forçages
  0x2060, 0x2061, 0x2062, 0x2063, 0x2064, // gluon, opérateurs invisibles
  0x2066, 0x2067, 0x2068, 0x2069, // isolats
  0xFEFF, // espace insécable sans largeur (BOM)
};

/// Les plus trompeurs : leur présence est une raison d'alerte.
/// Exclus : U+200C/U+200D (emojis composés, écriture persane), U+200E,
/// U+200F et U+061C (posés par les claviers arabes), U+00AD et U+180E
/// (fréquents dans un texte copié d'une page web).
const deceptiveCodePoints = {
  0x200B, // espace sans largeur
  0x202A, 0x202B, 0x202C, 0x202D, 0x202E, // enchâssements et forçages
  0x2060, 0x2061, 0x2062, 0x2063, 0x2064, // gluon, opérateurs invisibles
  0x2066, 0x2067, 0x2068, 0x2069, // isolats
  0xFEFF, // espace insécable sans largeur
};

const _rightToLeftOverride = 0x202E; // RLO : force l'affichage à l'envers
const _popDirectionalFormatting = 0x202C; // PDF : ferme la dernière ouverture
const _embeddingOpeners = {0x202A, 0x202B, 0x202D, 0x202E};

/// Fin de paragraphe (règle Unicode B) : ferme toutes les ouvertures.
const _paragraphSeparators = {0x0A, 0x0D, 0x1C, 0x1D, 0x1E, 0x85, 0x2029};

/// Le texte tel que l'utilisateur le voit (SEN-12).
/// Ce qui suit un RLO (U+202E), jusqu'au PDF (U+202C) ou à la fin du
/// paragraphe, est remis à l'endroit ; puis tous les [hiddenCodePoints]
/// sont retirés. `https://` + RLO + `zyx.etsop` + PDF devient `https://poste.xyz`.
String normalizeText(String text) {
  final out = <int>[];
  final opened = <int>[]; // ouvertures en cours (pile)
  var reversed = <int>[]; // caractères sous un RLO, à remettre à l'endroit
  void flush() {
    out.addAll(reversed.reversed);
    reversed = <int>[];
  }

  for (final rune in text.runes) {
    if (_paragraphSeparators.contains(rune)) {
      flush();
      opened.clear();
      out.add(rune);
    } else if (_embeddingOpeners.contains(rune)) {
      flush();
      opened.add(rune);
    } else if (rune == _popDirectionalFormatting) {
      flush();
      if (opened.isNotEmpty) opened.removeLast();
    } else if (hiddenCodePoints.contains(rune)) {
      // retiré
    } else if (opened.isNotEmpty && opened.last == _rightToLeftOverride) {
      reversed.add(rune);
    } else {
      out.add(rune);
    }
  }
  flush();
  return String.fromCharCodes(out);
}

/// Vrai si le texte contient un caractère trompeur (SEN-12).
bool hasDeceptiveCharacters(String text) =>
    text.runes.any(deceptiveCodePoints.contains);
