import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/utils/debug_log.dart';

// SEN-05 : aucun log en release. Tout passe par debugLog (lib/utils/debug_log.dart).
void main() {
  // Tout ce qui écrit dans logcat depuis Dart.
  final forbidden = RegExp(
    r'\b(debugPrint|print|debugPrintStack)\s*\(|dart:developer|stdout\.|stderr\.',
  );

  test('aucun appel de log direct dans lib/ (hors debug_log.dart)', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) => !f.path.replaceAll('\\', '/').endsWith('utils/debug_log.dart'),
        );
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue; // commentaire
        if (forbidden.hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}: $line');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('debugLog est conditionné par la constante kDebugMode', () {
    final printed = <String?>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message);
    addTearDown(() => debugPrint = previous);

    debugLog(() => 'secret');
    // Les tests tournent en mode debug : on vérifie l'écriture, et que la
    // condition est bien la constante de compilation kDebugMode.
    expect(printed, kDebugMode ? ['secret'] : isEmpty);
    expect(
      File('lib/utils/debug_log.dart').readAsStringSync(),
      contains('if (kDebugMode) debugPrint(message());'),
    );
  });
}
