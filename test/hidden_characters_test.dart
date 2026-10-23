import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/phishing/message_analyzer.dart';
import 'package:sentinel/services/phishing/phishing_model.dart';

// SEN-12 : caractères invisibles et inversion de texte.
// Les caractères cachés sont écrits en \u, jamais tels quels.
const rlo = '\u202E'; // force l'affichage à l'envers
const pdf = '\u202C'; // ferme l'ouverture

String reverse(String s) => String.fromCharCodes(s.runes.toList().reversed);

PhishingPrediction fakePrediction(double p) => PhishingPrediction(
  probability: p,
  suspiciousNgrams: const [],
  suspiciousWords: const [],
);

void main() {
  // Les marques viennent de assets/data/known_brands.json.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKnownBrands);

  group('normalizeMessage', () {
    test('retire les caractères invisibles', () {
      expect(
        normalizeMessage('pay\u00ADpal se\u200Bcu\u2060rité \uFEFFok'),
        'paypal securité ok',
      );
    });

    test('remet à l\'endroit le texte forcé de droite à gauche', () {
      expect(
        normalizeMessage('https://${rlo}zyx.etsop$pdf fin'),
        'https://poste.xyz fin',
      );
    });

    test('un emoji (2 unités UTF-16) reste entier quand il est inversé', () {
      expect(normalizeMessage('$rlo\u{1F600}ab$pdf'), 'ba\u{1F600}');
    });

    test('la fin de paragraphe ferme le forçage', () {
      expect(normalizeMessage('${rlo}abc\ndef'), 'cba\ndef');
    });

    test('PDF sans ouverture : simplement retiré', () {
      expect(normalizeMessage('a${pdf}b'), 'ab');
    });

    test('texte normal : inchangé', () {
      const text = 'Rendez-vous demain à 9h, merci ! مرحبا 😀';
      expect(normalizeMessage(text), text);
    });
  });

  group('hasDeceptiveCharacters', () {
    test('détecte inversion, isolats et espaces sans largeur', () {
      expect(hasDeceptiveCharacters('a${rlo}b'), isTrue);
      expect(hasDeceptiveCharacters('a\u2067b\u2069'), isTrue);
      expect(hasDeceptiveCharacters('pay\u200Bpal'), isTrue);
      expect(hasDeceptiveCharacters('a\uFEFFb'), isTrue);
    });

    test('pas de fausse alerte sur les usages légitimes', () {
      // Emoji composé (U+200D), claviers arabes (U+200F, U+200E),
      // texte copié d'une page web (U+00AD).
      expect(hasDeceptiveCharacters('👨\u200D👩\u200D👧'), isFalse);
      expect(hasDeceptiveCharacters('\u200Fمرحبا\u200E Salut'), isFalse);
      expect(hasDeceptiveCharacters('pro\u00ADgramme'), isFalse);
      expect(hasDeceptiveCharacters('Bonjour, à demain'), isFalse);
    });
  });

  group('analyzeMessage', () {
    test(
      'caractère trompeur : raison affichée en premier, au moins Suspect',
      () {
        final a = analyzeMessage('Bon\u200Bjour', fakePrediction(0.1));
        expect(a.verdict, Verdict.suspect);
        expect(a.reasons.first, hiddenCharactersReason);
      },
    );

    test('sans caractère trompeur : verdict inchangé', () {
      final a = analyzeMessage('Bonjour', fakePrediction(0.1));
      expect(a.verdict, Verdict.rien);
      expect(a.reasons, isNot(contains(hiddenCharactersReason)));
    });

    test('ne baisse jamais un verdict plus grave', () {
      final a = analyzeMessage('Bon\u200Bjour', fakePrediction(0.9));
      expect(a.verdict, Verdict.arnaque);
    });

    test('le lien caché est analysé comme il s\'affiche', () {
      final a = analyzeMessage(
        'Payez ici https://${rlo}zyx.ssap-etsopal$pdf',
        fakePrediction(0.1),
      );
      expect(a.links.map((l) => l.host), contains('laposte-pass.xyz'));
    });
  });

  group('Exemple de P2 rejoué (modèle réel)', () {
    final model = PhishingModel.fromJson(
      jsonDecode(File('assets/models/phishing_model.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    const domain = 'laposte-colis-suivi.example-arnaque.xyz';
    const clean = 'Payez ici https://$domain sinon blocage';
    final hidden = 'Payez ici https://$rlo${reverse(domain)}$pdf sinon blocage';

    test('même probabilité que le texte propre (P2 : 96 % → 74 %)', () {
      final pClean = model.predict(clean).probability;
      final pHidden = model.predict(hidden).probability;
      expect(pHidden, pClean);
      expect((pClean * 100).round(), 96);
    });

    test('même verdict, mêmes raisons, plus la raison « caractères »', () {
      final aClean = analyzeMessage(clean, model.predict(clean));
      final aHidden = analyzeMessage(hidden, model.predict(hidden));
      expect(aHidden.verdict, aClean.verdict);
      expect(aHidden.verdict, Verdict.arnaque);
      expect(aHidden.percent, aClean.percent);
      expect(aHidden.reasons, [hiddenCharactersReason, ...aClean.reasons]);
    });
  });
}
