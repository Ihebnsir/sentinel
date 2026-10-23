import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/screens/home_screen.dart';

// SEN-16 : salutation neutre, aucun prénom dans l'app.
void main() {
  test('la salutation est « Bonjour »', () {
    expect(homeGreeting, 'Bonjour');
  });

  test('aucun prénom écrit en dur dans lib/', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      expect(
        file.readAsStringSync(),
        isNot(contains('Iheb')),
        reason: file.path,
      );
    }
  });
}
