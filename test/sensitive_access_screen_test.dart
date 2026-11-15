import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/screens/sensitive_access_screen.dart';
import 'package:sentinel/services/sensitive_access.dart';
import 'package:sentinel/services/sensitive_access_service.dart';

import 'support/l10n.dart';

/// Android simulé : autorisation et apps choisies par le test.
class _FakeService extends SensitiveAccessService {
  _FakeService({required this.granted, this.apps = const []});

  bool granted;
  final List<SensitiveAccessApp> apps;
  int settingsOpened = 0;
  int reads = 0;

  @override
  Future<bool> hasUsageAccess() async => granted;

  @override
  Future<List<SensitiveAccessApp>> read() async {
    reads++;
    return apps;
  }

  @override
  Future<void> openUsageAccessSettings() async => settingsOpened++;
}

final _now = DateTime(2026, 11, 11, 20);

SensitiveAccessApp _app(String label, List<UsageEvent> events) =>
    SensitiveAccessApp(
      packageName: 'com.test.$label',
      label: label,
      sensors: const {SensitiveSensor.camera, SensitiveSensor.microphone},
      events: events,
    );

void main() {
  testWidgets('sans autorisation : explication, rien demandé avant le bouton', (
    tester,
  ) async {
    final service = _FakeService(granted: false);
    await tester.pumpWidget(
      testApp(
        home: SensitiveAccessScreen(service: service, clock: () => _now),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(fr.accessIntroTitle), findsOneWidget);
    expect(find.text(fr.accessIntroPrivacy), findsOneWidget);
    expect(service.settingsOpened, 0);
    expect(service.reads, 0);

    await tester.ensureVisible(find.text(fr.accessOpenSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.text(fr.accessOpenSettings));
    await tester.pump();
    expect(service.settingsOpened, 1);
    // Retour sans avoir activé : on le dit.
    expect(find.text(fr.accessNotYetGranted), findsOneWidget);
  });

  testWidgets('avec autorisation : inhabituelles en premier', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final service = _FakeService(
      granted: true,
      apps: [
        _app('Calme', [
          UsageEvent(DateTime(2026, 11, 11, 9), UsageEventKind.foreground),
          UsageEvent(DateTime(2026, 11, 11, 10), UsageEventKind.background),
        ]),
        _app('Nocturne', [
          UsageEvent(DateTime(2026, 11, 10, 3), UsageEventKind.serviceStart),
          UsageEvent(DateTime(2026, 11, 10, 4), UsageEventKind.serviceStop),
        ]),
      ],
    );
    await tester.pumpWidget(
      testApp(
        home: SensitiveAccessScreen(service: service, clock: () => _now),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(fr.accessToReview), findsOneWidget);
    final nocturne = tester.getTopLeft(find.text('Nocturne')).dy;
    final calme = tester.getTopLeft(find.text('Calme')).dy;
    expect(nocturne, lessThan(calme));
    expect(
      find.text('${fr.accessNight} · ${fr.accessBackground}'),
      findsOneWidget,
    );

    // Détail : moments et bouton des autorisations.
    await tester.tap(find.text('Nocturne'));
    await tester.pumpAndSettle();
    expect(find.text(fr.accessReasonNight), findsOneWidget);
    expect(find.text(fr.accessReasonBackground), findsOneWidget);
    expect(find.text(fr.detailManagePermissions), findsOneWidget);
    expect(find.text(fr.accessSeeAnalysis), findsOneWidget);
  });

  testWidgets('arabe : l\'écran s\'affiche sans erreur', (tester) async {
    final service = _FakeService(granted: false);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('ar'),
        home: SensitiveAccessScreen(service: service, clock: () => _now),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(ar.accessIntroTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
