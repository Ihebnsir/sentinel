import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/phishing/phishing_model.dart';

/// Lit un fichier JSON du projet (flutter test se lance depuis la racine).
Map<String, dynamic> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Le n-gramme sous forme de texte, avec les espaces rendus visibles.
List<String> ngramsOf(String word) =>
    wordNgrams(word.runes.toList()).map((g) => g.replaceAll(' ', '_')).toList();

void main() {
  group('Découpage en n-grammes', () {
    test('« ok » : exemple de ml/README.md', () {
      expect(ngramsOf('ok'), ['_o', 'ok', 'k_', '_ok', 'ok_', '_ok_']);
    });

    test('« a » : mot d\'une lettre', () {
      expect(ngramsOf('a'), ['_a', 'a_', '_a_']);
    });

    test('« abcd » : on va jusqu\'aux 5-grammes', () {
      expect(ngramsOf('abcd'), [
        '_a', 'ab', 'bc', 'cd', 'd_', //
        '_ab', 'abc', 'bcd', 'cd_', //
        '_abc', 'abcd', 'bcd_', //
        '_abcd', 'abcd_',
      ]);
    });

    test('un emoji compte pour un seul caractère', () {
      expect(ngramsOf('😀'), ['_😀', '😀_', '_😀_']);
    });

    test('mots séparés par des espaces variés, sans mot vide', () {
      final words = splitWords('  a\tb c\n\nd  ')
          .map(String.fromCharCodes)
          .toList();
      expect(words, ['a', 'b', 'c', 'd']);
    });

    test('U+200B n\'est pas un espace', () {
      expect(splitWords('a​b'), hasLength(1));
    });

    test('la ponctuation fait partie du mot', () {
      final words = splitWords('ici : poste-tn.xyz/colis')
          .map(String.fromCharCodes)
          .toList();
      expect(words, ['ici', ':', 'poste-tn.xyz/colis']);
    });

    test('minuscules, et un n-gramme ne traverse jamais deux mots', () {
      final ngrams = charWbNgrams('Ab C');
      expect(ngrams, containsAll([' ab', 'ab ', ' c ']));
      expect(ngrams.any((g) => g.contains('b c')), isFalse);
    });

    test('texte vide : aucun n-gramme', () {
      expect(charWbNgrams(''), isEmpty);
      expect(charWbNgrams('   '), isEmpty);
    });
  });

  group('Sigmoïde', () {
    test('valeurs connues et pas de dépassement', () {
      expect(sigmoid(0), 0.5);
      expect(sigmoid(1000), 1.0);
      expect(sigmoid(-1000), 0.0);
      expect(sigmoid(-2) + sigmoid(2), closeTo(1, 1e-15));
    });
  });

  group('Parité avec scikit-learn', () {
    final model = PhishingModel.fromJson(
      readJson('assets/models/phishing_model.json'),
    );
    final fixture = readJson('test/fixtures/phishing_parity.json');
    final tolerance = (fixture['tolerance'] as num).toDouble();
    final cases = fixture['cases'] as List;

    test('la fixture correspond à cette version du modèle', () {
      expect(fixture['model_version'], model.version);
      expect(cases, hasLength(38));
    });

    test('étape 0 : mêmes caractères retirés que ml/train.py (SEN-12)', () {
      final json = readJson('assets/models/phishing_model.json');
      expect(json['format_version'], 2);
      final pre = json['preprocessing'] as Map<String, dynamic>;
      expect((pre['hidden_codepoints'] as List).cast<int>().toSet(),
          hiddenCodePoints);
      expect(deceptiveCodePoints.difference(hiddenCodePoints), isEmpty);
    });

    for (final (i, c) in cases.indexed) {
      final text = c['text'] as String;
      final expected = (c['proba'] as num).toDouble();
      test('cas ${i + 1} (${c['langue']}) : ${jsonEncode(text)}', () {
        // Même texte nettoyé que Python, puis même probabilité.
        expect(normalizeMessage(text), c['normalise']);
        final proba = model.predict(text).probability;
        expect((proba - expected).abs(), lessThan(tolerance));
      });
    }
  });

  group('Mots suspects lisibles', () {
    final model = PhishingModel.fromJson(
      readJson('assets/models/phishing_model.json'),
    );

    test('au plus 3 mots, sans doublon, sans lien', () {
      const text = 'La Poste : colis colis en attente, payez 1,900 DT '
          'ici : poste-colis.xyz/p';
      final words = model.predict(text).suspiciousWords;
      expect(words.length, lessThanOrEqualTo(3));
      expect(words.toSet(), hasLength(words.length));
      expect(words.any((w) => w.contains('.')), isFalse);
    });

    test('un n-gramme est rattaché au mot qui le contient', () {
      expect(readableWords('Payez votre colis !', [' col', 'ayez']),
          ['colis', 'payez']);
    });
  });
}
