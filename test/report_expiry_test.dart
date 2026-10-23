import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/screens/app_report_screen.dart';
import 'package:sentinel/services/app_analysis.dart';

// SEN-14 : un rapport expiré n'est jamais affiché, même resté ouvert.
void main() {
  final ended = DateTime(2026, 10, 23, 12);
  final report = AppReport(
    id: '1',
    packageName: 'com.exemple.app',
    appLabel: 'Exemple',
    startedAt: ended.subtract(const Duration(minutes: 2)),
    endedAt: ended,
    plannedMinutes: 2,
    stoppedEarly: false,
    truncated: false,
    domains: const [],
  );

  setUp(() {
    // Liste des apps (icône du rapport) : vide.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.iheb.sentinel/apps'),
          (call) async => <Object?>[],
        );
  });

  // Ouvre le rapport depuis une page, comme firewall_screen.dart.
  Future<List<bool?>> open(WidgetTester tester, DateTime now) async {
    final results = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      AppReportScreen(report: report, now: () => now),
                ),
              ),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // animation
    return results;
  }

  testWidgets('se ferme pile à 24 h', (tester) async {
    final opened = ended.add(const Duration(hours: 23, minutes: 59));
    final results = await open(tester, opened);
    expect(find.byType(AppReportScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 59));
    expect(find.byType(AppReportScreen), findsOneWidget); // 23 h 59 min 59 s

    await tester.pump(const Duration(seconds: 1)); // 24 h
    await tester.pumpAndSettle();
    expect(find.byType(AppReportScreen), findsNothing);
    expect(results, [true]); // la liste des rapports est rechargée
  });

  testWidgets('déjà expiré à l\'ouverture : fermé tout de suite', (
    tester,
  ) async {
    final results = await open(tester, ended.add(const Duration(hours: 25)));
    await tester.pumpAndSettle();
    expect(find.byType(AppReportScreen), findsNothing);
    expect(results, [true]);
  });
}
