import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/screens/qr_result_screen.dart';
import 'package:sentinel/services/phishing/phishing_model.dart';
import 'package:sentinel/utils/bidi.dart';

import 'support/l10n.dart';

// Mots latins dans des phrases arabes : on mesure la position réelle de
// chaque caractère à l'écran (comme arabic_formats_test.dart).

/// Abscisse gauche du caractère [index] dans le texte affiché.
double _left(WidgetTester tester, Finder text, int index) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: index, extentOffset: index + 1),
  );
  return boxes.first.left;
}

/// Affiche [lines] dans un écran en arabe (de droite à gauche).
Future<void> _showArabic(WidgetTester tester, List<String> lines) async {
  tester.view.physicalSize = const Size(2400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      locale: const Locale('ar'),
      home: Scaffold(
        body: Column(children: [for (final line in lines) Text(line)]),
      ),
    ),
  );
}

void main() {
  group('ordre à l\'écran en arabe', () {
    testWidgets('« .xyz » : le point reste devant l\'extension', (
      tester,
    ) async {
      final text = ar.reasonLinkTld('xyz');
      await _showArabic(tester, [text]);
      final f = find.text(text);
      final dot = text.indexOf('.');
      // « .xyz » et non « xyz. » : le point à gauche du x.
      expect(_left(tester, f, dot), lessThan(_left(tester, f, dot + 1)));
      expect(_left(tester, f, dot + 1), lessThan(_left(tester, f, dot + 2)));
      // Guillemets de part et d'autre de « .xyz » (ouvrant à droite).
      final open = text.indexOf('«');
      final close = text.indexOf('»');
      expect(_left(tester, f, open), greaterThan(_left(tester, f, dot + 3)));
      expect(_left(tester, f, close), lessThan(_left(tester, f, dot)));
    });

    testWidgets('« payez », « code », « appelez » : chacun ses guillemets', (
      tester,
    ) async {
      const words = ['payez', 'code', 'appelez'];
      final text = ar.reasonScamWords(
        words.map(ar.reasonQuotedWord).join(ar.listSeparator),
      );
      await _showArabic(tester, [text]);
      final f = find.text(text);
      final starts = [for (final w in words) text.indexOf(w)];
      double? previousLeft;
      for (var i = 0; i < words.length; i++) {
        final start = starts[i];
        final end = start + words[i].length - 1;
        // Le mot se lit de gauche à droite.
        expect(_left(tester, f, start), lessThan(_left(tester, f, end)));
        // Son « ouvrant » juste à droite, son « fermant » juste à gauche.
        final open = text.lastIndexOf('«', start);
        final close = text.indexOf('»', end);
        expect(_left(tester, f, open), greaterThan(_left(tester, f, end)));
        expect(_left(tester, f, close), lessThan(_left(tester, f, start)));
        // Lecture de droite à gauche : chaque mot à gauche du précédent,
        // guillemets compris (pas de « payez», «code » mélangés).
        if (previousLeft != null) {
          expect(_left(tester, f, open), lessThan(previousLeft));
        }
        previousLeft = _left(tester, f, close);
      }
    });

    testWidgets('« poste-tn-livraison.xyz » : domaine entier et entre '
        'guillemets', (tester) async {
      const host = 'poste-tn-livraison.xyz';
      final text = ar.reasonLinkImpersonation(host, 'La Poste Tunisienne');
      await _showArabic(tester, [text]);
      final f = find.text(text);
      final start = text.indexOf(host);
      final dot = text.indexOf('.xyz');
      final end = start + host.length - 1;
      // Ordre du domaine : p … - … . x … z, de gauche à droite.
      expect(_left(tester, f, start), lessThan(_left(tester, f, dot)));
      expect(_left(tester, f, dot), lessThan(_left(tester, f, dot + 1)));
      expect(_left(tester, f, dot + 1), lessThan(_left(tester, f, end)));
      // Guillemets autour du domaine, pas ailleurs.
      expect(
        _left(tester, f, text.indexOf('«')),
        greaterThan(_left(tester, f, end)),
      );
      expect(
        _left(tester, f, text.indexOf('»')),
        lessThan(_left(tester, f, start)),
      );
      // La phrase arabe commence à droite du domaine (début de lecture).
      final brand = text.indexOf('La Poste');
      expect(_left(tester, f, brand), lessThan(_left(tester, f, start)));
    });

    testWidgets('« (http بدلًا من https) » bien ordonné', (tester) async {
      final text = ar.reasonLinkHttp;
      await _showArabic(tester, [text]);
      final f = find.text(text);
      final http = text.indexOf('http');
      final https = text.indexOf('https', http + 4);
      final open = text.indexOf('(');
      final close = text.indexOf(')');
      // « http » se lit de gauche à droite.
      expect(_left(tester, f, http), lessThan(_left(tester, f, http + 3)));
      expect(_left(tester, f, https), lessThan(_left(tester, f, https + 4)));
      // De droite à gauche : ( http … https ).
      expect(_left(tester, f, open), greaterThan(_left(tester, f, http + 3)));
      expect(_left(tester, f, http), greaterThan(_left(tester, f, https + 4)));
      expect(_left(tester, f, close), lessThan(_left(tester, f, https)));
    });

    testWidgets('titres latins séparés par « ، » : ordre gardé', (
      tester,
    ) async {
      final text = ar.healthAlsoUsedFor(
        ['Gmail', 'Facebook'].map(bidiIsolate).join(ar.listSeparator),
      );
      await _showArabic(tester, [text]);
      final f = find.text(text);
      final gmail = text.indexOf('Gmail');
      final facebook = text.indexOf('Facebook');
      // Gmail (lu en premier) à droite de Facebook.
      expect(_left(tester, f, gmail), greaterThan(_left(tester, f, facebook)));
      // La virgule arabe entre les deux.
      final comma = text.indexOf('،');
      expect(_left(tester, f, comma), lessThan(_left(tester, f, gmail)));
      expect(
        _left(tester, f, comma),
        greaterThan(_left(tester, f, facebook + 7)),
      );
    });

    testWidgets('QR : numéro « +216 … » avec le « + » à gauche', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(
          locale: const Locale('ar'),
          home: QrResultScreen(
            raw: 'tel:+21622333444',
            loadPredictor: () async =>
                (_) => const PhishingPrediction(
                  probability: 0.05,
                  suspiciousNgrams: [],
                  suspiciousWords: [],
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final number = find.text('+21622333444');
      expect(number, findsOneWidget);
      expect(_left(tester, number, 0), lessThan(_left(tester, number, 1)));
    });
  });

  test('sens d\'un texte brut', () {
    expect(directionOf('https://poste.xyz/'), TextDirection.ltr);
    expect(directionOf('+216 22 333 444'), TextDirection.ltr);
    expect(directionOf('رابط https://x.tn'), TextDirection.rtl);
  });

  test('isolement : contrôles de sens venus d\'ailleurs retirés', () {
    // Un PDI glissé dans un nom fermerait l'isolement trop tôt.
    expect(bidiIsolate('a${pdi}b$lri'), '${fsi}ab$pdi');
    expect(ltrIsolate('x.tn'), '${lri}x.tn$pdi');
  });

  // Garde-fou pour les prochains textes : tout morceau latin du fichier
  // arabe est isolé, ainsi que les valeurs latines insérées.
  test('app_ar.arb : aucun mot latin hors d\'un isolement', () {
    final arb = jsonDecode(
      File('lib/l10n/app_ar.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    // Textes entièrement latins, affichés seuls.
    const standalone = {'appTitle', 'allowlistHint'};
    // Valeurs souvent latines (domaine, marque, nom d'app, mot…).
    const latinValues = {
      'host', 'brand', 'tld', 'word', 'app', 'name', 'domain', 'server', //
      'url', 'title', 'recipient', 'code', 'number',
    };
    final openers = {lri, fsi, String.fromCharCode(0x2067)};
    final latin = RegExp('[A-Za-z]');
    final problems = <String>[];
    for (final entry in arb.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key.startsWith('@') || value is! String) continue;
      if (standalone.contains(key) || value.contains('plural,')) continue;
      var depth = 0;
      for (var i = 0; i < value.length; i++) {
        final c = value[i];
        if (openers.contains(c)) {
          depth++;
        } else if (c == pdi) {
          depth--;
        } else if (c == '{') {
          final end = value.indexOf('}', i);
          final name = value.substring(i + 1, end);
          if (latinValues.contains(name) && depth == 0) {
            problems.add('$key : {$name} non isolé');
          }
          i = end;
        } else if (depth == 0 && latin.hasMatch(c)) {
          problems.add('$key : « $c » hors isolement');
          break;
        }
      }
      if (depth != 0) problems.add('$key : isolement mal fermé');
    }
    expect(problems, isEmpty);
  });
}
