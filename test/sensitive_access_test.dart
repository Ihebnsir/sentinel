import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/sensitive_access.dart';

// Heure locale fixe : mercredi 11 novembre 2026, 20 h.
final now = DateTime(2026, 11, 11, 20);
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

UsageEvent fg(DateTime t) => UsageEvent(t, UsageEventKind.foreground);
UsageEvent bg(DateTime t) => UsageEvent(t, UsageEventKind.background);
UsageEvent start(DateTime t) => UsageEvent(t, UsageEventKind.serviceStart);
UsageEvent stop(DateTime t) => UsageEvent(t, UsageEventKind.serviceStop);

SensitiveAccessApp app(
  String label,
  List<UsageEvent> events, {
  Set<SensitiveSensor> sensors = const {SensitiveSensor.camera},
  bool backgroundLocation = false,
}) => SensitiveAccessApp(
  packageName: 'com.test.${label.toLowerCase()}',
  label: label,
  sensors: sensors,
  backgroundLocation: backgroundLocation,
  events: events,
);

void main() {
  final from = now.subtract(accessWindow);

  group('nuit (00 h – 06 h)', () {
    test('dedans, dehors, à cheval', () {
      expect(overlapsNight(at(10, 2), at(10, 3)), isTrue);
      expect(overlapsNight(at(10, 6), at(10, 23)), isFalse);
      expect(overlapsNight(at(10, 23), at(11, 0, 30)), isTrue);
      expect(overlapsNight(at(10, 5, 59), at(10, 7)), isTrue);
      // Fin exactement à minuit : pas la nuit.
      expect(overlapsNight(at(10, 22), at(11, 0)), isFalse);
    });
  });

  group('moments d\'activité', () {
    test('ouverture puis fermeture', () {
      final s = buildSessions([fg(at(11, 9)), bg(at(11, 10))], from, now);
      expect(s, [UsageSession(at(11, 9), at(11, 10), SessionKind.foreground)]);
    });

    test('pause puis arrêt : un seul moment', () {
      final s = buildSessions(
        [fg(at(11, 9)), bg(at(11, 10)), bg(at(11, 10, 0))],
        from,
        now,
      );
      expect(s, hasLength(1));
    });

    test('changements d\'écran rapprochés fusionnés', () {
      final s = buildSessions(
        [
          fg(at(11, 9)),
          bg(at(11, 9, 10)),
          fg(at(11, 9, 10)),
          bg(at(11, 9, 30)),
        ],
        from,
        now,
      );
      expect(s, [
        UsageSession(at(11, 9), at(11, 9, 30), SessionKind.foreground),
      ]);
    });

    test('déjà ouverte au début, encore ouverte maintenant', () {
      final s = buildSessions([bg(at(5, 1)), fg(at(11, 19))], from, now);
      expect(s, [
        UsageSession(at(11, 19), now, SessionKind.foreground),
        UsageSession(from, at(5, 1), SessionKind.foreground),
      ]);
    });

    test('service hors de l\'écran = arrière-plan', () {
      final s = buildSessions(
        [start(at(11, 8)), fg(at(11, 9)), bg(at(11, 10)), stop(at(11, 12))],
        from,
        now,
      );
      expect(s, [
        UsageSession(at(11, 10), at(11, 12), SessionKind.background),
        UsageSession(at(11, 9), at(11, 10), SessionKind.foreground),
        UsageSession(at(11, 8), at(11, 9), SessionKind.background),
      ]);
    });

    test('services imbriqués : un seul moment', () {
      final s = buildSessions(
        [start(at(11, 1)), start(at(11, 2)), stop(at(11, 3)), stop(at(11, 4))],
        from,
        now,
      );
      expect(s, [UsageSession(at(11, 1), at(11, 4), SessionKind.background)]);
    });

    test('événements dans le désordre', () {
      final s = buildSessions([bg(at(11, 10)), fg(at(11, 9))], from, now);
      expect(s, [UsageSession(at(11, 9), at(11, 10), SessionKind.foreground)]);
    });

    test('hors période : coupé au début des 7 jours', () {
      final s = buildSessions(
        [
          fg(from.subtract(const Duration(hours: 2))),
          bg(from.add(const Duration(hours: 1))),
        ],
        from,
        now,
      );
      expect(s.single.start, from);
    });
  });

  group('résumé d\'une app', () {
    test('comptes 24 h / 7 jours et dernière activité', () {
      final s = summarizeApp(
        app('Photo', [
          fg(at(6, 14)), bg(at(6, 15)), //
          fg(at(11, 9)), bg(at(11, 10)),
          fg(at(11, 18)), bg(at(11, 18, 30)),
        ]),
        now,
      );
      expect(s.count7d, 3);
      expect(s.count24h, 2);
      expect(s.lastUse, at(11, 18, 30));
      expect(s.unusual, isFalse);
    });

    test('la nuit : inhabituel', () {
      final s = summarizeApp(
        app('Nuit', [fg(at(10, 3)), bg(at(10, 3, 5))]),
        now,
      );
      expect(s.reasons, {UnusualReason.night});
      expect(s.nightCount, 1);
    });

    test('arrière-plan avec caméra ou micro : inhabituel', () {
      final s = summarizeApp(
        app(
          'Rec',
          [start(at(11, 14)), stop(at(11, 15))],
          sensors: {SensitiveSensor.microphone},
        ),
        now,
      );
      expect(s.reasons, {UnusualReason.backgroundCameraMic});
      expect(s.backgroundCount, 1);
    });

    test('arrière-plan avec localisation seule (GPS) : pas inhabituel', () {
      final s = summarizeApp(
        app(
          'Gps',
          [start(at(11, 14)), stop(at(11, 15))],
          sensors: {SensitiveSensor.location},
        ),
        now,
      );
      expect(s.unusual, isFalse);
      expect(s.backgroundCount, 1);
    });
  });

  group('liste triée', () {
    test('inhabituelles d\'abord, puis la plus récente, puis le nom', () {
      final list = summarizeAccess([
        app('Bravo', [fg(at(11, 9)), bg(at(11, 10))]),
        app('alpha', [fg(at(11, 9)), bg(at(11, 10))]),
        app('Récente', [fg(at(11, 19)), bg(at(11, 19, 30))]),
        app('Nuit', [fg(at(9, 2)), bg(at(9, 2, 10))]),
        app(
          'Double',
          [start(at(9, 1)), stop(at(9, 2))],
          sensors: {SensitiveSensor.camera},
        ),
      ], now);
      expect(
        [for (final s in list) s.app.label],
        ['Double', 'Nuit', 'Récente', 'alpha', 'Bravo'],
      );
    });

    test('sans activité : cachée, sauf localisation « toujours »', () {
      final list = summarizeAccess([
        app('Muette', const []),
        app(
          'Toujours',
          const [],
          sensors: {SensitiveSensor.location},
          backgroundLocation: true,
        ),
        app('Sans accès', [fg(at(11, 9))], sensors: const {}),
      ], now);
      expect([for (final s in list) s.app.label], ['Toujours']);
      expect(list.single.lastUse, isNull);
    });
  });

  test('lecture de la Map envoyée par Kotlin', () {
    final a = SensitiveAccessApp.fromMap({
      'packageName': 'com.x',
      'label': 'X',
      'icon': Uint8List(3),
      'isSystemApp': true,
      'sensors': ['camera', 'location', 'inconnu'],
      'backgroundLocation': true,
      'eventTimes': Int64List.fromList([1000, 2000, 3000]),
      'eventKinds': Int32List.fromList([0, 9, 3]),
    });
    expect(a.sensors, {SensitiveSensor.camera, SensitiveSensor.location});
    expect(a.isSystemApp, isTrue);
    expect(a.backgroundLocation, isTrue);
    // Le code 9 (inconnu) est ignoré.
    expect(
      [for (final e in a.events) e.kind],
      [UsageEventKind.foreground, UsageEventKind.serviceStop],
    );
    expect(SensitiveAccessApp.fromMap({}).label, '');
  });
}
