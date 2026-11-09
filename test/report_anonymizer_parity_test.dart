import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/report/anonymizer.dart';

/// Cas communs avec le serveur (flutter test se lance depuis la racine).
const _fixtures = 'backend/tests/fixtures/anonymize_cases.json';

void main() {
  final data =
      jsonDecode(File(_fixtures).readAsStringSync()) as Map<String, dynamic>;
  final cases = (data['cases'] as List).cast<Map<String, dynamic>>();

  test('même version que le serveur et que les cas', () {
    expect(data['version'], anonymizerVersion);
    final python = File('backend/app/anonymize.py').readAsStringSync();
    final match = RegExp(r'ANONYMIZER_VERSION = (\d+)\s').firstMatch(python);
    expect(match?[1], '$anonymizerVersion');
  });

  test('tous les cas sont là (96 au moins)', () {
    expect(cases.length, greaterThanOrEqualTo(96));
  });

  group('Parité avec backend/app/anonymize.py', () {
    for (final c in cases) {
      test(c['id'] as String, () {
        expect(anonymize(c['input'] as String), c['expected']);
      });
    }
  });

  group('Idempotence : anonymiser deux fois ne change rien', () {
    for (final c in cases) {
      test(c['id'] as String, () {
        final once = c['expected'] as String;
        expect(anonymize(once), once);
      });
    }
  });

  test('Luhn : carte valide et invalide', () {
    expect(luhnValid([4, ...List.filled(15, 1)]), isTrue);
    expect(luhnValid([4, ...List.filled(14, 1), 2]), isFalse);
  });
}
