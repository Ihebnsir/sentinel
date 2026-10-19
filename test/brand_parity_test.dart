import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/phishing/url_analyzer.dart';

/// Mêmes cas que BrandParityTest.kt (JUnit) : Dart et Kotlin doivent
/// donner exactement la même réponse.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final brands = parseKnownBrands(
    File('assets/data/known_brands.json').readAsStringSync(),
  );
  final fixture = jsonDecode(
    File('test/fixtures/brand_parity.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final cases = (fixture['cases'] as List).cast<Map<String, Object?>>();

  group('Parité des marques (test/fixtures/brand_parity.json)', () {
    test('assez de cas, avec et sans marque', () {
      expect(cases.length, greaterThanOrEqualTo(40));
      expect(cases.where((c) => c['brand'] == null), isNotEmpty);
      expect(cases.where((c) => c['brand'] != null), isNotEmpty);
    });

    for (final item in cases) {
      final host = item['host'] as String;
      test('« $host »', () {
        expect(
          impersonatedBrand(host, brands: brands)?.name,
          item['brand'],
          reason: item['note'] as String?,
        );
      });
    }

    test('extensions suspectes : même liste qu\'en Kotlin', () {
      expect(fixture['suspiciousTlds'], suspiciousTlds);
    });

    test('chaque marque attendue existe dans known_brands.json', () {
      final names = brands.map((b) => b.name).toSet();
      for (final item in cases) {
        final brand = item['brand'];
        if (brand != null) expect(names, contains(brand));
      }
    });
  });

  group('known_brands.json', () {
    test('22 marques, mots-clés en minuscules, domaines valides', () {
      expect(brands, hasLength(22));
      for (final brand in brands) {
        expect(brand.keywords, isNotEmpty, reason: brand.name);
        expect(brand.officialDomains, isNotEmpty, reason: brand.name);
        for (final k in brand.keywords) {
          expect(k, k.toLowerCase(), reason: brand.name);
        }
        for (final d in brand.officialDomains) {
          expect(d, matches(RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$')));
        }
      }
    });

    test('version inconnue refusée', () {
      expect(
        () => parseKnownBrands('{"formatVersion": 2, "brands": []}'),
        throwsFormatException,
      );
    });

    test('chargé depuis les assets, une seule fois', () async {
      final first = await loadKnownBrands();
      final second = await loadKnownBrands();
      expect(identical(first, second), isTrue);
      expect(first.map((b) => b.name), brands.map((b) => b.name));
      expect(knownBrands, same(first));
    });
  });
}
