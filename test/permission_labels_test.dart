import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/utils/permission_labels.dart';

import 'support/l10n.dart';

void main() {
  // Les noms courts listés dans permission_labels.dart (ex : CAMERA).
  final connues = RegExp(r"^\s*'([A-Z_]+)' =>", multiLine: true)
      .allMatches(File('lib/utils/permission_labels.dart').readAsStringSync())
      .map((m) => m[1]!)
      .toList();

  test('la liste des permissions est bien lue', () {
    expect(connues, contains('CAMERA'));
    expect(connues.length, greaterThan(50));
  });

  test(
    'chaque permission connue a un libellé différent, dans chaque langue',
    () {
      for (final l in [fr, en, ar]) {
        final libelles = [
          for (final nom in connues)
            permissionLabel(l, 'android.permission.$nom'),
        ];
        expect(libelles, everyElement(isNotNull));
        expect(libelles, everyElement(isNotEmpty));
        // Deux permissions avec le même texte : clé recopiée par erreur.
        expect(libelles.toSet(), hasLength(libelles.length));
      }
    },
  );

  test('exemple : appareil photo', () {
    expect(permissionLabel(fr, 'android.permission.CAMERA'), fr.permCamera);
  });

  test('permission inconnue ou d\'une autre app : null', () {
    expect(permissionLabel(fr, 'android.permission.INCONNUE'), isNull);
    expect(permissionLabel(fr, 'com.exemple.permission.CAMERA'), isNull);
    expect(permissionLabel(fr, 'CAMERA'), isNull); // sans préfixe
    expect(permissionLabel(fr, 'android.permission.'), isNull);
    expect(permissionLabel(fr, ''), isNull);
    // La casse compte, comme pour Android.
    expect(permissionLabel(fr, 'android.permission.camera'), isNull);
  });
}
