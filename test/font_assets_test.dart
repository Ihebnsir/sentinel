import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/theme/app_theme.dart';

// SEN-02 : la police est embarquée, rien n'est téléchargé à l'exécution.
void main() {
  // Le seul fichier que google_fonts téléchargeait (nom = SHA-256) : les
  // autres graisses étaient simulées. Le garder seul = rendu identique.
  const expected = {
    'ReadexPro-Regular.ttf':
        'd01db080f4e540c5eb64f567df67d82e951bd72b739e26ccbe55fc9c1ea03f4c',
  };

  test('le fichier de police est présent et intact', () {
    for (final entry in expected.entries) {
      final bytes = File('assets/fonts/${entry.key}').readAsBytesSync();
      expect(sha256.convert(bytes).toString(), entry.value, reason: entry.key);
    }
  });

  test('pubspec déclare ce seul fichier, sans google_fonts', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(r'assets/fonts/\S+\.ttf').allMatches(pubspec);
    expect([for (final m in declared) m[0]], [
      for (final name in expected.keys) 'assets/fonts/$name',
    ]);
    expect(pubspec, isNot(contains('google_fonts')));
    expect(
      File('pubspec.lock').readAsStringSync(),
      isNot(contains('google_fonts')),
    );
  });

  test('aucun code ne contacte un service de polices', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('google_fonts')), reason: file.path);
      expect(source, isNot(contains('fonts.gstatic.com')), reason: file.path);
      expect(
        source,
        isNot(contains('fonts.googleapis.com')),
        reason: file.path,
      );
    }
  });

  test('le thème utilise la police embarquée partout', () {
    final theme = AppTheme.light;
    expect(theme.textTheme.bodyMedium!.fontFamily, AppTheme.fontFamily);
    expect(theme.textTheme.titleLarge!.fontFamily, AppTheme.fontFamily);
    final label = theme.navigationBarTheme.labelTextStyle!.resolve({});
    expect(label!.fontFamily, AppTheme.fontFamily);
  });

  test('la licence OFL de la police est livrée', () {
    final license = File('assets/fonts/ReadexPro-OFL.txt').readAsStringSync();
    expect(license, contains('SIL Open Font License, Version 1.1'));
    expect(license, contains('Readex Pro'));
  });
}
