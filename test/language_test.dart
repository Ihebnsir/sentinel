import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/screens/settings_screen.dart';
import 'package:sentinel/services/language_store.dart';

import 'support/l10n.dart';

/// Choix en mémoire : pas de vrai fichier dans les tests widget.
class _MemoryStore extends LanguageStore {
  String? saved;

  @override
  Future<String?> load() async => saved;

  @override
  Future<void> save(String? languageCode) async => saved = languageCode;
}

void main() {
  group('LanguageStore (fichier)', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('language'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('rien au départ, puis le choix enregistré', () async {
      final store = LanguageStore(directory: () async => dir);
      expect(await store.load(), isNull);
      await store.save('ar');
      expect(await LanguageStore(directory: () async => dir).load(), 'ar');
      await store.save(null);
      expect(await store.load(), isNull);
    });

    test('fichier abîmé ou langue inconnue : langue du téléphone', () async {
      final file = File('${dir.path}/${LanguageStore.fileName}');
      file.writeAsStringSync('{');
      expect(await LanguageStore(directory: () async => dir).load(), isNull);
      file.writeAsStringSync('{"language": "de"}');
      expect(await LanguageStore(directory: () async => dir).load(), isNull);
    });
  });

  testWidgets('Réglages : choisir l\'arabe puis la langue du téléphone', (
    tester,
  ) async {
    // Le choix est aussi envoyé à Android (notifications).
    final sent = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.iheb.sentinel/language'),
          (call) async {
            sent.add((call.arguments as Map)['language']);
            return null;
          },
        );
    final store = _MemoryStore();
    final controller = LanguageController(store: store);
    await tester.pumpWidget(
      LanguageScope(
        controller: controller,
        child: ValueListenableBuilder<Locale?>(
          valueListenable: controller,
          builder: (context, locale, _) => testApp(
            home: const SettingsScreen(),
            locale: locale ?? const Locale('fr'),
          ),
        ),
      ),
    );

    expect(find.text(fr.settingsLanguage), findsOneWidget);
    expect(find.text(fr.settingsLanguageSystem), findsOneWidget);

    await tester.tap(find.text(fr.settingsLanguage));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(controller.value, const Locale('ar'));
    expect(store.saved, 'ar');
    expect(sent, ['ar']);
    // L'écran est passé en arabe, de droite à gauche.
    expect(find.text(ar.settingsTitle), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text(ar.settingsTitle))),
      TextDirection.rtl,
    );

    await tester.tap(find.text(ar.settingsLanguage));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ar.settingsLanguageSystem).last);
    await tester.pumpAndSettle();

    expect(controller.value, isNull);
    expect(store.saved, isNull);
    expect(sent, ['ar', null]);
  });
}
