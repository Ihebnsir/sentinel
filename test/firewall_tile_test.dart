import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/screens/firewall_screen.dart';
import 'package:sentinel/screens/main_shell.dart';

import 'support/l10n.dart';

// Tuile « Pare-feu Sentinel » (FirewallTileService.kt) : quand elle ne peut
// rien faire seule, l'app s'ouvre sur l'écran du pare-feu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const share = MethodChannel('com.iheb.sentinel/share');

  setUp(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.iheb.sentinel/firewall'),
      (call) async => switch (call.method) {
        'status' => {'active': false},
        'reports' => <Object?>[],
        _ => null,
      },
    );
  });

  Future<void> show(WidgetTester tester, {required bool fromTile}) async {
    tester.view.physicalSize = const Size(2400, 6000);
    addTearDown(tester.view.reset);
    messenger.setMockMethodCallHandler(
      share,
      (call) async => call.method == 'getInitialOpenFirewall' ? fromTile : null,
    );
    await tester.pumpWidget(testApp(home: const MainShell()));
    await tester.pumpAndSettle();
  }

  testWidgets('lancée par la tuile : écran du pare-feu', (tester) async {
    await show(tester, fromTile: true);
    expect(find.byType(FirewallScreen), findsOneWidget);
  });

  testWidgets('lancement normal : accueil', (tester) async {
    await show(tester, fromTile: false);
    expect(find.byType(FirewallScreen), findsNothing);
  });

  testWidgets('app ouverte : la tuile ouvre l\'écran une seule fois', (
    tester,
  ) async {
    await show(tester, fromTile: false);
    Future<void> tuile() => messenger.handlePlatformMessage(
      share.name,
      share.codec.encodeMethodCall(const MethodCall('onOpenFirewall')),
      (_) {},
    );
    await tuile();
    await tester.pumpAndSettle();
    await tuile();
    await tester.pumpAndSettle();
    expect(find.byType(FirewallScreen), findsOneWidget);
  });
}
