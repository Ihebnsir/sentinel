import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Lit un fichier ARB (clés de texte et métadonnées).
Map<String, Object?> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, Object?>;

/// Les textes seuls (sans « @… »).
Map<String, String> _texts(Map<String, Object?> arb) => {
  for (final e in arb.entries)
    if (!e.key.startsWith('@')) e.key: e.value as String,
};

// Valeurs à insérer : « {name} » ou « {count, plural, … } ».
final _placeholder = RegExp(r'(?<![\w=])\{(\w+)(?:\}|,)');

Set<String> _placeholders(String text) => {
  for (final m in _placeholder.allMatches(text)) m[1]!,
};

/// Caractères connus de la police (table cmap, formats 4 et 12).
Set<int> _fontCodePoints(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final tables = <String, int>{};
  for (var i = 0; i < data.getUint16(4); i++) {
    final record = 12 + 16 * i;
    tables[ascii.decode(bytes.sublist(record, record + 4))] = data.getUint32(
      record + 8,
    );
  }
  final cmap = tables['cmap']!;
  final codePoints = <int>{};
  for (var i = 0; i < data.getUint16(cmap + 2); i++) {
    final sub = cmap + data.getUint32(cmap + 8 + 8 * i);
    switch (data.getUint16(sub)) {
      case 4:
        final segments = data.getUint16(sub + 6) ~/ 2;
        for (var s = 0; s < segments; s++) {
          final end = data.getUint16(sub + 14 + 2 * s);
          final start = data.getUint16(sub + 16 + 2 * segments + 2 * s);
          if (start != 0xFFFF) {
            for (var c = start; c <= end; c++) {
              codePoints.add(c);
            }
          }
        }
      case 12:
        for (var g = 0; g < data.getUint32(sub + 12); g++) {
          final group = sub + 16 + 12 * g;
          for (
            var c = data.getUint32(group);
            c <= data.getUint32(group + 4);
            c++
          ) {
            codePoints.add(c);
          }
        }
    }
  }
  return codePoints;
}

/// Scripts du tableau GSUB (règles de liaison des lettres).
List<String> _gsubScripts(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < data.getUint16(4); i++) {
    final record = 12 + 16 * i;
    if (ascii.decode(bytes.sublist(record, record + 4)) != 'GSUB') continue;
    final gsub = data.getUint32(record + 8);
    final list = gsub + data.getUint16(gsub + 4);
    return [
      for (var s = 0; s < data.getUint16(list); s++)
        ascii.decode(bytes.sublist(list + 2 + 6 * s, list + 6 + 6 * s)),
    ];
  }
  return const [];
}

void main() {
  final french = _arb('fr');
  final frTexts = _texts(french);

  for (final lang in ['en', 'ar']) {
    group('app_$lang.arb', () {
      final texts = _texts(_arb(lang));

      test('chaque clé existe dans les 3 langues', () {
        expect(texts.keys.toSet(), frTexts.keys.toSet());
      });

      test('aucun texte vide', () {
        for (final e in texts.entries) {
          expect(e.value.trim(), isNotEmpty, reason: e.key);
        }
      });

      test('mêmes valeurs à insérer que le français', () {
        for (final e in texts.entries) {
          expect(
            _placeholders(e.value),
            _placeholders(frTexts[e.key]!),
            reason: e.key,
          );
        }
      });

      test('marqué « à relire par un humain »', () {
        expect(_arb(lang)['@@x-relecture'], contains('RELIRE PAR UN HUMAIN'));
      });
    });
  }

  test('le français décrit ses valeurs à insérer', () {
    for (final e in frTexts.entries) {
      final names = _placeholders(e.value);
      if (names.isEmpty) continue;
      final meta = french['@${e.key}'] as Map<String, Object?>?;
      final declared = (meta?['placeholders'] as Map?)?.keys.toSet();
      expect(declared, names, reason: e.key);
    }
  });

  test('clés claires : camelCase, sans accent', () {
    for (final key in frTexts.keys) {
      expect(key, matches(RegExp(r'^[a-z][a-zA-Z0-9]*$')), reason: key);
    }
  });

  group('police Readex Pro', () {
    final font = File('assets/fonts/ReadexPro-Regular.ttf').readAsBytesSync();
    final codePoints = _fontCodePoints(font);

    test('contient toutes les lettres des 3 langues', () {
      for (final lang in ['fr', 'en', 'ar']) {
        for (final e in _texts(_arb(lang)).entries) {
          for (final rune in e.value.runes) {
            // Marques de direction (U+200E, U+200F…) : invisibles.
            if (rune >= 0x200B && rune <= 0x200F) continue;
            expect(
              codePoints,
              contains(rune),
              reason:
                  '$lang/${e.key} : U+${rune.toRadixString(16).toUpperCase()}',
            );
          }
        }
      }
    });

    test("sait lier les lettres arabes (GSUB 'arab')", () {
      expect(_gsubScripts(font), contains('arab'));
      // Tout l'alphabet de base, pas seulement les lettres déjà utilisées.
      for (var c = 0x0621; c <= 0x064A; c++) {
        if (c >= 0x063B && c <= 0x063F) continue; // non attribués
        expect(codePoints, contains(c), reason: 'U+${c.toRadixString(16)}');
      }
    });
  });
}
