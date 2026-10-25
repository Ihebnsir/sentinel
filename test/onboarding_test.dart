import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/screens/onboarding_screen.dart';
import 'package:sentinel/screens/privacy_policy_screen.dart';
import 'package:sentinel/screens/startup_gate.dart';
import 'package:sentinel/services/onboarding_store.dart';

/// Préférence en mémoire : pas de vrai fichier dans les tests widget.
class _MemoryStore extends OnboardingStore {
  _MemoryStore(this.done);

  bool done;
  int writes = 0;

  @override
  Future<bool> isDone() async => done;

  @override
  Future<void> markDone() async {
    done = true;
    writes++;
  }
}

Widget _app(OnboardingStore store) => MaterialApp(
  home: StartupGate(store: store, home: const Text('ACCUEIL')),
);

void main() {
  testWidgets('premier lancement : présentation puis accueil', (tester) async {
    final store = _MemoryStore(false);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text(onboardingPages[0].title), findsOneWidget);
    expect(find.text('ACCUEIL'), findsNothing);

    // 3 pages : « Suivant » deux fois, puis « Commencer ».
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text(onboardingPages[1].title), findsOneWidget);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text(onboardingPages[2].title), findsOneWidget);
    expect(find.text('Suivant'), findsNothing);

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(store.done, isTrue);
    expect(store.writes, 1);
  });

  testWidgets('lancements suivants : directement l\'accueil', (tester) async {
    final store = _MemoryStore(true);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(find.text(onboardingPages[0].title), findsNothing);
    expect(store.writes, 0);
  });

  test('3 pages au plus', () {
    expect(onboardingPages.length, lessThanOrEqualTo(3));
  });

  test('les appels réseau annoncés sont ceux de la politique', () {
    final onboarding = onboardingPages[1].lines.join(' ');
    final policy = privacySections.expand((s) => s.paragraphs).join(' ');
    for (final service in ['Have I Been Pwned', 'Quad9', 'GitHub']) {
      expect(onboarding, contains(service));
      expect(policy, contains(service));
    }
  });

  group('OnboardingStore (fichier)', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('onboarding'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('false au départ, true après markDone', () async {
      final store = OnboardingStore(directory: () async => dir);
      expect(await store.isDone(), isFalse);
      await store.markDone();
      expect(
        await OnboardingStore(directory: () async => dir).isDone(),
        isTrue,
      );
    });

    test('fichier abîmé : la présentation revient', () async {
      File('${dir.path}/${OnboardingStore.fileName}').writeAsStringSync('{');
      expect(
        await OnboardingStore(directory: () async => dir).isDone(),
        isFalse,
      );
    });
  });
}
