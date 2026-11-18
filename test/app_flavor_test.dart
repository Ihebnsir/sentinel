import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/app_info.dart';
import 'package:sentinel/widgets/auto_protection_section.dart';

import 'support/l10n.dart';

// Deux variantes Android (android/app/build.gradle.kts) : standard (APK
// GitHub, sans protection automatique) et complete (Google Play).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const canal = MethodChannel('com.iheb.sentinel/protection');
  tearDown(() => messenger.setMockMethodCallHandler(canal, null));

  test('sans --flavor (tests) : comme la variante complete', () {
    expect(isStandardFlavor, isFalse);
    expect(autoProtectionAvailable, isTrue);
    expect(ownPackageName, 'com.iheb.sentinel');
  });

  test('suffixe du paquet standard identique dans Gradle et Dart', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "com.iheb.sentinel"'));
    expect(gradle, contains('applicationIdSuffix = ".standard"'));
  });

  for (final (locale, text) in [
    ('fr', fr.autoProtectionPlayOnly),
    ('en', en.autoProtectionPlayOnly),
    ('ar', ar.autoProtectionPlayOnly),
  ]) {
    testWidgets('standard ($locale) : explication, ni interrupteur ni canal', (
      tester,
    ) async {
      var called = false;
      messenger.setMockMethodCallHandler(canal, (call) async {
        called = true;
        return null;
      });
      await tester.pumpWidget(
        testApp(
          locale: Locale(locale),
          home: const Scaffold(body: AutoProtectionSection(available: false)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
      expect(find.textContaining('Google Play'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(called, isFalse);
    });
  }

  testWidgets('complete : interrupteur selon l\'état lu côté Android', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(
      canal,
      (call) async => {
        'available': true,
        'enabled': false,
        'listenerAccess': false,
        'notificationsAllowed': true,
      },
    );
    await tester.pumpWidget(
      testApp(home: const Scaffold(body: AutoProtectionSection())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text(fr.autoProtectionPlayOnly), findsNothing);
  });
}
