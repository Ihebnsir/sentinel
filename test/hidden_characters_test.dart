import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/links/hidden_characters.dart';
import 'package:sentinel/services/links/link_checker.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'support/l10n.dart';

// SEN-12 : caractères invisibles et inversion de texte.
// Les caractères cachés sont écrits en \u, jamais tels quels.
const rlo = '\u202E'; // force l'affichage à l'envers
const pdf = '\u202C'; // ferme l'ouverture

String reverse(String s) => String.fromCharCodes(s.runes.toList().reversed);

void main() {
  // Les marques viennent de assets/data/known_brands.json.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKnownBrands);

  group('normalizeText', () {
    test('retire les caractères invisibles', () {
      expect(
        normalizeText('pay\u00ADpal se\u200Bcu\u2060rité \uFEFFok'),
        'paypal securité ok',
      );
    });

    test('remet à l\'endroit le texte forcé de droite à gauche', () {
      expect(
        normalizeText('https://${rlo}zyx.etsop$pdf fin'),
        'https://poste.xyz fin',
      );
    });

    test('un emoji (2 unités UTF-16) reste entier quand il est inversé', () {
      expect(normalizeText('$rlo\u{1F600}ab$pdf'), 'ba\u{1F600}');
    });

    test('la fin de paragraphe ferme le forçage', () {
      expect(normalizeText('${rlo}abc\ndef'), 'cba\ndef');
    });

    test('PDF sans ouverture : simplement retiré', () {
      expect(normalizeText('a${pdf}b'), 'ab');
    });

    test('texte normal : inchangé', () {
      const text = 'Rendez-vous demain à 9h, merci ! مرحبا 😀';
      expect(normalizeText(text), text);
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

  group('checkText', () {
    test('caractère trompeur : raison affichée en premier, au moins Suspect', () {
      final c = checkText('Voir https://www.exem\u200Bple.tn')!;
      expect(c.link.host, 'www.exemple.tn'); // lu comme il s'affiche
      expect(c.verdict, Verdict.suspect);
      expect(c.reasons(fr).first, fr.reasonHiddenCharacters);
    });

    test('sans caractère trompeur : verdict inchangé', () {
      final c = checkText('Voir https://www.exemple.tn')!;
      expect(c.verdict, Verdict.rien);
      expect(c.reasons(fr), isNot(contains(fr.reasonHiddenCharacters)));
    });

    test('ne baisse jamais un verdict plus grave', () {
      final c = checkText('Bon\u200Bjour https://poste-tn.com')!;
      expect(c.verdict, Verdict.dangereux);
    });

    test('le lien inversé (P2) est vérifié comme il s\'affiche', () {
      const domain = 'laposte-colis-suivi.example-arnaque.xyz';
      final hidden = 'Payez ici https://$rlo${reverse(domain)}$pdf sinon blocage';
      final c = checkText(hidden)!;
      expect(c.link.host, domain);
      expect(c.verdict, Verdict.dangereux); // imite La Poste
      expect(c.reasons(fr).first, fr.reasonHiddenCharacters);
      expect(c.realDestination, 'example-arnaque[.]xyz');
    });
  });
}
