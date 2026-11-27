import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// SEN-16 : aucun prénom dans l'app. 1.2.1 : plus de salutation du tout.
void main() {
  test('plus de « Bonjour » sur l\'accueil, dans aucune langue', () {
    for (final lang in ['fr', 'ar', 'en']) {
      final arb = File('lib/l10n/app_$lang.arb').readAsStringSync();
      expect(arb, isNot(contains('homeGreeting')), reason: lang);
    }
    expect(
      File('lib/screens/home_screen.dart').readAsStringSync(),
      isNot(contains('Greeting')),
    );
  });

  test('aucun prénom écrit en dur dans lib/', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') || f.path.endsWith('.arb'));
    for (final file in files) {
      expect(
        file.readAsStringSync(),
        isNot(contains('Iheb')),
        reason: file.path,
      );
    }
  });
}
