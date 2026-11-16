import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/l10n/l10n.dart';

import 'package:sentinel/screens/settings_screen.dart';
import 'package:sentinel/screens/weekly_report_screen.dart';
import 'package:sentinel/services/weekly_report_service.dart';

import 'support/l10n.dart';

// Lundi 16 novembre 2026 = jour 20773 depuis le 1er janvier 1970.
const _monday = 20773;

Map<Object?, Object?> _week(
  int days, {
  Map<String, int> counters = const {},
  Map<String, int> gauges = const {},
  int? scoreStart,
  int? scoreEnd,
}) => {
  'week': days,
  'counters': counters,
  'gauges': gauges,
  'scoreStart': scoreStart,
  'scoreEnd': scoreEnd,
};

/// Service sans Android : renvoie un bilan préparé, note les réglages.
class _FakeWeekly extends WeeklyReportService {
  _FakeWeekly({this.report, this.enabled = false});

  final WeeklyReport? report;
  bool? enabled;
  final changes = <bool>[];

  @override
  Future<WeeklyReport?> load() async => report;

  @override
  Future<bool?> notificationsEnabled() async => enabled;

  @override
  Future<void> setNotificationsEnabled(bool value) async {
    changes.add(value);
    enabled = value;
  }
}

void main() {
  group('WeekSummary.fromMap', () {
    test('lit les compteurs, jauges et scores', () {
      final week = WeekSummary.fromMap(
        _week(
          _monday,
          counters: {
            'blocked_trackers': 120,
            'blocked_malware': 3,
            'messages': 9,
            'scam_alerts': 2,
          },
          gauges: {'risky_apps': 1, 'pw_weak': 0},
          scoreStart: 58,
          scoreEnd: 71,
        ),
      );
      expect(week.start, DateTime(2026, 11, 16));
      expect(week.end, DateTime(2026, 11, 22));
      expect(week.blockedIn('trackers'), 120);
      expect(week.blockedIn('ads'), 0);
      expect(week.blockedTotal, 123);
      expect(week.messages, 9);
      expect(week.scamAlerts, 2);
      expect(week.scoreStart, 58);
      expect(week.scoreEnd, 71);
      expect(week.gauges, {
        WeeklyGauge.riskyApps: 1,
        WeeklyGauge.passwordsWeak: 0,
      });
    });

    test('valeurs inattendues ignorées', () {
      final week = WeekSummary.fromMap({
        'week': _monday,
        'counters': {'blocked_ads': -5, 'messages': 'beaucoup', 7: 1},
        'gauges': 'rien',
        'scoreEnd': 250,
      });
      expect(week.blockedTotal, 0);
      expect(week.messages, 0);
      expect(week.gauges, isEmpty);
      expect(week.scoreEnd, isNull);
    });

    test('sans semaine précédente', () {
      final report = WeeklyReport.fromMap({'current': _week(_monday)});
      expect(report.previous, isNull);
      expect(report.current.start, DateTime(2026, 11, 16));
    });
  });

  test('seules des clés de la liste fermée partent vers Android', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('com.iheb.sentinel/weekly');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    const service = WeeklyReportService();
    await service.count(WeeklyCounter.scamAlerts);
    await service.setGauge(WeeklyGauge.passwordsReused, 2);
    await service.recordScore(64);

    expect(calls.map((c) => c.method), ['count', 'setGauge', 'recordScore']);
    expect(calls[0].arguments, {'key': 'scam_alerts', 'n': 1});
    expect(calls[1].arguments, {'key': 'pw_reused', 'value': 2});
    expect(calls[2].arguments, {'score': 64});
  });

  group('Écran Bilan', () {
    final report = WeeklyReport.fromMap({
      'current': _week(
        _monday,
        counters: {'blocked_trackers': 1234, 'messages': 5, 'scam_alerts': 1},
        gauges: {'risky_apps': 2},
        scoreStart: 58,
        scoreEnd: 71,
      ),
      'previous': _week(
        _monday - 7,
        counters: {'blocked_trackers': 800},
        scoreEnd: 55,
      ),
    });

    testWidgets('semaine en cours et précédente', (tester) async {
      await tester.pumpWidget(
        testApp(
          home: WeeklyReportScreen(service: _FakeWeekly(report: report)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(fr.weeklyTitle), findsOneWidget);
      expect(find.text(fr.weeklyScoreChange('58', '71')), findsOneWidget);
      expect(find.text(fr.weeklyLastWeekScore('55')), findsOneWidget);
      // Arche du score.
      expect(find.text('71'), findsOneWidget);
      await tester.scrollUntilVisible(find.text(fr.weeklyPrivacyNote), 300);
      expect(find.text(fr.number(1234))
, findsWidgets); // traqueurs et total
      expect(find.text('800'), findsWidgets);
      // Mots de passe pas mesurés : tiret.
      expect(find.text('–'), findsWidgets);
    });

    testWidgets('en arabe, sans erreur', (tester) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('ar'),
          home: WeeklyReportScreen(service: _FakeWeekly(report: report)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(ar.weeklyTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pas de score cette semaine : arche vide', (tester) async {
      final empty = WeeklyReport.fromMap({'current': _week(_monday)});
      await tester.pumpWidget(
        testApp(
          home: WeeklyReportScreen(service: _FakeWeekly(report: empty)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(fr.weeklyNoScore), findsOneWidget);
    });

    testWidgets('hors Android : message', (tester) async {
      await tester.pumpWidget(
        testApp(home: WeeklyReportScreen(service: _FakeWeekly())),
      );
      await tester.pumpAndSettle();
      expect(find.text(fr.weeklyAndroidOnly), findsOneWidget);
    });
  });

  group('Réglage de la notification', () {
    Future<_FakeWeekly> pump(
      WidgetTester tester, {
      bool? enabled = false,
      bool allowed = true,
    }) async {
      final service = _FakeWeekly(enabled: enabled);
      await tester.pumpWidget(
        testApp(
          home: SettingsScreen(
            weekly: service,
            requestNotifications: () async => allowed,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return service;
    }

    testWidgets('désactivée par défaut, puis activée', (tester) async {
      final service = await pump(tester);
      final row = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(row).value, isFalse);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(service.changes, [true]);
      expect(tester.widget<SwitchListTile>(row).value, isTrue);
    });

    testWidgets('notifications refusées : reste désactivée', (tester) async {
      final service = await pump(tester, allowed: false);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(service.changes, isEmpty);
      expect(find.text(fr.settingsWeeklyNotificationDenied), findsOneWidget);
    });

    testWidgets('hors Android : ligne masquée', (tester) async {
      await pump(tester, enabled: null);
      expect(find.text(fr.settingsWeeklyNotification), findsNothing);
    });
  });
}
