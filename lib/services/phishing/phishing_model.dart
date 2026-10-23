import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Chemin du modèle exporté par ml/train.py.
const phishingModelAsset = 'assets/models/phishing_model.json';

/// Caractères d'espacement : exactement ceux de Python `str.isspace()`
/// (voir ml/README.md, étape 2).
const _whitespaceCodePoints = {
  0x09, 0x0A, 0x0B, 0x0C, 0x0D, // tabulation, retours à la ligne
  0x1C, 0x1D, 0x1E, 0x1F, // séparateurs
  0x20, 0x85, 0xA0, 0x1680, // espace, next line, insécable…
  0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, // espaces typographiques
  0x2006, 0x2007, 0x2008, 0x2009, 0x200A,
  0x2028, 0x2029, 0x202F, 0x205F, 0x3000,
};

/// Caractères retirés avant l'analyse (SEN-12, étape 0 de ml/README.md) :
/// contrôles de direction du texte et caractères invisibles.
/// Liste identique à HIDDEN_CODEPOINTS de ml/train.py.
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

/// Étape 0 : le texte tel que l'utilisateur le voit (SEN-12).
/// Ce qui suit un RLO (U+202E), jusqu'au PDF (U+202C) ou à la fin du
/// paragraphe, est remis à l'endroit ; puis tous les [hiddenCodePoints]
/// sont retirés. `https://` + RLO + `zyx.etsop` + PDF devient `https://poste.xyz`.
String normalizeMessage(String text) {
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

/// Vrai si le message contient un caractère trompeur (SEN-12).
bool hasDeceptiveCharacters(String text) =>
    text.runes.any(deceptiveCodePoints.contains);

/// Découpe un texte en mots (suites de caractères qui ne sont pas des espaces).
/// Jamais de mot vide. Chaque mot est une liste de points de code.
List<List<int>> splitWords(String text) {
  final words = <List<int>>[];
  var current = <int>[];
  for (final rune in text.runes) {
    if (_whitespaceCodePoints.contains(rune)) {
      if (current.isNotEmpty) words.add(current);
      current = <int>[];
    } else {
      current.add(rune);
    }
  }
  if (current.isNotEmpty) words.add(current);
  return words;
}

/// N-grammes d'un seul mot, comme `char_wb` (2 à 5) de scikit-learn.
List<String> wordNgrams(List<int> word) {
  // On entoure le mot d'un espace de chaque côté.
  final w = [0x20, ...word, 0x20];
  final ngrams = <String>[];
  for (var n = 2; n <= 5; n++) {
    // Mot trop court : on garde le mot entier une fois, puis on arrête.
    if (w.length <= n) {
      ngrams.add(String.fromCharCodes(w));
      break;
    }
    for (var i = 0; i <= w.length - n; i++) {
      ngrams.add(String.fromCharCodes(w.sublist(i, i + n)));
    }
  }
  return ngrams;
}

/// Tous les n-grammes d'un message (minuscules, mot par mot, avec doublons).
List<String> charWbNgrams(String text) => [
      for (final word in splitWords(text.toLowerCase())) ...wordNgrams(word),
    ];

/// Résultat du modèle pour un message.
class PhishingPrediction {
  const PhishingPrediction({
    required this.probability,
    required this.suspiciousNgrams,
    required this.suspiciousWords,
  });

  final double probability; // de 0 à 1 : probabilité d'arnaque
  final List<String> suspiciousNgrams; // du plus suspect au moins suspect
  final List<String> suspiciousWords; // max 3 mots lisibles, sans doublons
}

/// Le modèle TF-IDF + régression logistique. Calcul pur, sans Flutter.
class PhishingModel {
  PhishingModel({
    required this.version,
    required this.vocabulary,
    required this.idf,
    required this.coef,
    required this.intercept,
    required this.threshold,
  });

  /// Lit le contenu de phishing_model.json.
  factory PhishingModel.fromJson(Map<String, dynamic> json) {
    List<double> numbers(String key) => [
          for (final v in json[key] as List) (v as num).toDouble(),
        ];
    return PhishingModel(
      version: json['version'] as String,
      vocabulary: (json['vocabulary'] as Map<String, dynamic>)
          .map((ngram, index) => MapEntry(ngram, index as int)),
      idf: numbers('idf'),
      coef: numbers('coef'),
      intercept: (json['intercept'] as num).toDouble(),
      threshold: (json['threshold'] as num).toDouble(),
    );
  }

  final String version;
  final Map<String, int> vocabulary; // n-gramme → index
  final List<double> idf;
  final List<double> coef;
  final double intercept;
  final double threshold; // arnaque si probabilité >= threshold

  /// Nombre maximal de mots montrés à l'utilisateur.
  static const maxWords = 3;

  /// Probabilité d'arnaque d'un message (étapes de ml/README.md).
  PhishingPrediction predict(String text) {
    // Étape 0 : texte tel qu'il s'affiche, sans caractères invisibles.
    final clean = normalizeMessage(text);

    // Étapes 1 à 5 : comptage des n-grammes connus du vocabulaire.
    final counts = <int, int>{};
    for (final ngram in charWbNgrams(clean)) {
      final j = vocabulary[ngram];
      if (j != null) counts[j] = (counts[j] ?? 0) + 1;
    }

    // Étape 6 : tf sublinéaire × idf.
    final x = <int, double>{
      for (final e in counts.entries) e.key: (1 + math.log(e.value)) * idf[e.key],
    };

    // Étape 7 : normalisation L2.
    var sumSquares = 0.0;
    for (final v in x.values) {
      sumSquares += v * v;
    }
    final norm = math.sqrt(sumSquares);

    // Étape 8 : score z, et contribution de chaque n-gramme.
    var z = intercept;
    final contributions = <int, double>{};
    if (norm > 0) {
      for (final e in x.entries) {
        final c = e.value / norm * coef[e.key];
        contributions[e.key] = c;
        z += c;
      }
    }

    // N-grammes qui ont poussé vers « arnaque », du plus fort au plus faible.
    final pushing = contributions.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ngramOf = {for (final e in vocabulary.entries) e.value: e.key};
    final suspicious = [for (final e in pushing) ngramOf[e.key]!];

    return PhishingPrediction(
      probability: sigmoid(z),
      suspiciousNgrams: suspicious,
      suspiciousWords: readableWords(clean, suspicious),
    );
  }
}

/// 1 / (1 + e^-z), écrit sans dépassement quand z est très négatif.
double sigmoid(double z) {
  if (z >= 0) return 1 / (1 + math.exp(-z));
  final e = math.exp(z);
  return e / (1 + e);
}

// Ponctuation au début ou à la fin d'un mot (on garde lettres et chiffres).
final _edgePunctuation = RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true);
final _letter = RegExp(r'\p{L}', unicode: true);

/// Transforme les n-grammes suspects en mots du message, lisibles.
/// Ex : « olis » → « colis ». Les liens et les nombres sont ignorés
/// (les liens ont leurs propres explications).
List<String> readableWords(
  String text,
  List<String> ngrams, {
  int maxWords = PhishingModel.maxWords,
}) {
  final words = [
    for (final w in splitWords(text.toLowerCase())) String.fromCharCodes(w),
  ];
  final result = <String>[];
  for (final ngram in ngrams) {
    // Un n-gramme de 2 caractères est trop vague pour désigner un mot.
    if (ngram.trim().runes.length < 3) continue;
    for (final word in words) {
      if (!' $word '.contains(ngram)) continue;
      final clean = word.replaceAll(_edgePunctuation, '');
      final isLink = clean.contains('.') || clean.contains('/');
      final hasLetters = _letter.allMatches(clean).length >= 2;
      if (isLink || !hasLetters || result.contains(clean)) continue;
      result.add(clean);
      if (result.length == maxWords) return result;
    }
  }
  return result;
}

// Le modèle chargé, gardé en mémoire après le premier appel.
Future<PhishingModel>? _cachedModel;

/// Charge le modèle depuis les assets (une seule fois, au premier besoin).
Future<PhishingModel> loadPhishingModel() =>
    _cachedModel ??= _readModelAsset();

Future<PhishingModel> _readModelAsset() async {
  try {
    final source = await rootBundle.loadString(phishingModelAsset);
    final json = jsonDecode(source) as Map<String, dynamic>;
    return PhishingModel.fromJson(json);
  } catch (_) {
    // En cas d'échec, on permet un nouvel essai au prochain appel.
    _cachedModel = null;
    rethrow;
  }
}
