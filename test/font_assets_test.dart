import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/theme/app_theme.dart';

// SEN-02 : la police est embarquée, rien n'est téléchargé à l'exécution.
void main() {
  // Mêmes fichiers que ceux que servait fonts.gstatic.com (nom = SHA-256).
  const expected = {
    'ReadexPro-Light.ttf':
        '5fdd397f7c5e4db7672e46b4b7b15f6f5d4a7af92457e713f8dc4b14538c916d',
    'ReadexPro-Regular.ttf':
        'd01db080f4e540c5eb64f567df67d82e951bd72b739e26ccbe55fc9c1ea03f4c',
    'ReadexPro-Medium.ttf':
        'ed47cb984d1f274788ab1d7e5e435d25e9facc7adbdf87168f71dda4b1d24b2c',
    'ReadexPro-SemiBold.ttf':
        '54840850d336e22dca0bd8224a6dc294721e62642eab203f8acbe35a7ea402b8',
    'ReadexPro-Bold.ttf':
        '711c43d85e02884b5bc74994b87fab1fe84c9f9548495a1c2f0b779b7995f861',
  };

  test('les 5 fichiers de police sont présents et intacts', () {
    for (final entry in expected.entries) {
      final bytes = File('assets/fonts/${entry.key}').readAsBytesSync();
      expect(sha256.convert(bytes).toString(), entry.value, reason: entry.key);
    }
  });

  test('pubspec déclare chaque fichier, sans google_fonts', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final name in expected.keys) {
      expect(pubspec, contains('assets/fonts/$name'));
    }
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
