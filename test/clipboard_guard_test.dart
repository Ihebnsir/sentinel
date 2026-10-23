import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/services/vault/vault_platform.dart';
import 'package:sentinel/widgets/vault_copy.dart';

// SEN-03 : Android 9 et avant, avertissement + effacement après 10 s.
void main() {
  // Faux presse-papiers du système (canal flutter/platform), et faux
  // VaultProtection.kt (copie sensible, effacement).
  String? clipboard;
  setUp(() {
    clipboard = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.iheb.sentinel/vault'),
      (call) async {
        switch (call.method) {
          case 'copySensitive':
            clipboard = (call.arguments as Map)['text'] as String?;
          case 'clearClipboard':
            clipboard = '';
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboard = (call.arguments as Map)['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return clipboard == null ? null : {'text': clipboard};
      }
      return null;
    });
  });

  ClipboardGuard guard({required bool shared}) =>
      ClipboardGuard(isClipboardShared: () async => shared);

  group('ClipboardGuard', () {
    testWidgets('Android 9 et avant : avertir, puis effacer après 10 s', (
      tester,
    ) async {
      final g = guard(shared: true);
      addTearDown(g.dispose);
      expect(await g.needsWarning(), isTrue);
      g.acceptWarning();
      expect(await g.needsWarning(), isFalse); // une seule fois

      expect(await g.copy('secret'), const Duration(seconds: 10));
      expect(clipboard, 'secret');
      await tester.pump(const Duration(seconds: 9));
      expect(clipboard, 'secret');
      await tester.pump(const Duration(seconds: 1));
      expect(clipboard, isEmpty);
    });

    testWidgets('Android 10+ : aucun avertissement, effacement après 30 s', (
      tester,
    ) async {
      final g = guard(shared: false);
      addTearDown(g.dispose);
      expect(await g.needsWarning(), isFalse);
      expect(await g.copy('secret'), const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 29));
      expect(clipboard, 'secret');
      await tester.pump(const Duration(seconds: 1));
      expect(clipboard, isEmpty);
    });

    testWidgets('n\'efface pas ce que l\'utilisateur a copié ensuite', (
      tester,
    ) async {
      final g = guard(shared: true);
      addTearDown(g.dispose);
      await g.copy('secret');
      clipboard = 'autre chose';
      await tester.pump(const Duration(seconds: 10));
      expect(clipboard, 'autre chose');
    });
  });

  group('copyFromVault (dialogue)', () {
    Future<BuildContext> host(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('x'))),
      );
      return tester.element(find.text('x'));
    }

    testWidgets('« Annuler » : rien n\'est copié', (tester) async {
      final g = guard(shared: true);
      addTearDown(g.dispose);
      final context = await host(tester);
      final result = copyFromVault(context, g, 'secret');
      await tester.pumpAndSettle();
      expect(find.text(sharedClipboardWarning), findsOneWidget);
      expect(
        sharedClipboardWarning,
        contains('toutes les applications peuvent lire ce que vous copiez'),
      );
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(await result, isNull);
      expect(clipboard, isNull);
    });

    testWidgets('« Copier quand même » : copie, puis plus de question', (
      tester,
    ) async {
      final g = guard(shared: true);
      addTearDown(g.dispose);
      final context = await host(tester);
      final first = copyFromVault(context, g, 'secret');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copier quand même'));
      await tester.pumpAndSettle();
      expect(await first, const Duration(seconds: 10));
      expect(clipboard, 'secret');

      final second = copyFromVault(context, g, 'secret2');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await second, const Duration(seconds: 10));
      expect(clipboard, 'secret2');
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('Android 10+ : copie directe, sans dialogue', (tester) async {
      final g = guard(shared: false);
      addTearDown(g.dispose);
      final context = await host(tester);
      final result = copyFromVault(context, g, 'secret');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await result, const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
    });
  });
}
