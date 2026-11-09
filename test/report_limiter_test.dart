import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/report/report_limiter.dart';

void main() {
  late Directory dir;
  late DateTime now;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('sentinel_limit_');
    now = DateTime.utc(2026, 11, 9, 10);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ReportLimiter limiter() =>
      ReportLimiter(directory: () async => dir, now: () => now);

  test('5 signalements par heure, pas un de plus', () async {
    final l = limiter();
    for (var i = 0; i < 5; i++) {
      expect(await l.canSend(), isTrue, reason: 'envoi ${i + 1}');
      await l.recordSent();
      now = now.add(const Duration(minutes: 1));
    }
    expect(await l.canSend(), isFalse);
  });

  test('heure glissante : le plus ancien libère une place', () async {
    final l = limiter();
    for (var i = 0; i < 5; i++) {
      await l.recordSent();
      now = now.add(const Duration(minutes: 10));
    }
    // 10 h 50 : le premier (10 h 00) a moins d'une heure.
    expect(await l.canSend(), isFalse);
    now = DateTime.utc(2026, 11, 9, 11, 0, 1);
    expect(await l.canSend(), isTrue);
  });

  test('gardé après un redémarrage de l\'app', () async {
    final first = limiter();
    for (var i = 0; i < 5; i++) {
      await first.recordSent();
    }
    expect(await limiter().canSend(), isFalse);
  });

  test('fichier : seulement des heures, aucun texte', () async {
    await limiter().recordSent();
    final content = File(
      '${dir.path}${Platform.pathSeparator}${ReportLimiter.fileName}',
    ).readAsStringSync();
    expect(content, matches(RegExp(r'^\[\d+\]$')));
  });

  test('fichier abîmé : on repart de zéro', () async {
    File(
      '${dir.path}${Platform.pathSeparator}${ReportLimiter.fileName}',
    ).writeAsStringSync('{pas du json');
    expect(await limiter().canSend(), isTrue);
  });

  test('heure dans le futur (horloge reculée) : ignorée', () async {
    now = DateTime.utc(2030);
    final l = limiter();
    for (var i = 0; i < 5; i++) {
      await l.recordSent();
    }
    now = DateTime.utc(2026, 11, 9, 10);
    expect(await limiter().canSend(), isTrue);
  });
}
