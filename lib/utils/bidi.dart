// Texte latin (domaine, lien, nom) au milieu d'une phrase arabe.
// Les caractères cachés sont écrits en \u, jamais tels quels.

import 'package:material_ui/material_ui.dart';

/// Ouvre un isolement dont le sens suit la première lettre (FSI).
const fsi = '\u2068';

/// Ouvre un isolement toujours de gauche à droite (LRI).
const lri = '\u2066';

/// Ferme l'isolement (PDI).
const pdi = '\u2069';

// Contrôles de sens déjà présents dans un texte venu d'ailleurs.
final _bidiControls = RegExp('[\u200E\u200F\u202A-\u202E\u2066-\u2069]');

/// Isole [text] : son sens ne déborde pas sur la phrase autour.
/// Ex. : des noms latins séparés par « ، » restent dans l'ordre.
String bidiIsolate(String text) =>
    '$fsi${text.replaceAll(_bidiControls, '')}$pdi';

/// Isole [text] de gauche à droite (domaine, lien, extension).
String ltrIsolate(String text) =>
    '$lri${text.replaceAll(_bidiControls, '')}$pdi';

// Première lettre « forte » : arabe/hébreu ou latin.
final _firstStrong = RegExp(
  '[A-Za-z\u00C0-\u024F\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
);

/// Début de la page (droite en arabe), même si le texte est de gauche
/// à droite : un domaine reste aligné avec le reste de l'écran.
TextAlign pageStart(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
    ? TextAlign.right
    : TextAlign.left;

/// Sens d'un texte brut selon sa première lettre (gauche à droite sinon).
TextDirection directionOf(String text) {
  final letter = _firstStrong.firstMatch(text)?.group(0);
  if (letter == null) return TextDirection.ltr;
  final code = letter.codeUnitAt(0);
  return code >= 0x0590 ? TextDirection.rtl : TextDirection.ltr;
}
