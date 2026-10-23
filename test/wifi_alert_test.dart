import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/screens/vault/create_vault_view.dart';
import 'package:sentinel/screens/vault/vault_item_screen.dart';
import 'package:sentinel/services/vault/vault_crypto.dart';
import 'package:sentinel/services/vault/vault_item.dart';
import 'package:sentinel/services/vault/vault_platform.dart';
import 'package:sentinel/services/vault/vault_session.dart';
import 'package:sentinel/services/vault/vault_storage.dart';
import 'package:sentinel/widgets/wifi_alert.dart';

import 'support/fake_biometrics.dart';

// SEN-17 : l'alerte Wi-Fi ne recouvre jamais les boutons du coffre.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('wifi_alert_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  VaultSession newSession() => VaultSession(
    storage: VaultStorage(directory: () async => dir),
    biometrics: FakeBiometrics(),
    kdfForNewVault: () => newKdfParams(memoryKib: 64, iterations: 2),
  );

  // Affiche l'alerte depuis l'écran testé, comme le fait l'accueil.
  Future<void> showAlert(WidgetTester tester, Finder screen) async {
    showWifiAlert(
      tester.element(screen),
      message: 'Wi-Fi ouvert : évitez la banque et les achats.',
      onDetails: () {},
    );
    await tester.pumpAndSettle();
  }

  // Le bouton est visible ET reçoit bien l'appui (rien par-dessus).
  void expectReachable(WidgetTester tester, Finder button) {
    final banner = tester.getRect(find.byType(MaterialBanner));
    final rect = tester.getRect(button);
    expect(rect.overlaps(banner), isFalse, reason: 'bandeau sur le bouton');
    final hit = tester.hitTestOnBinding(rect.center);
    final target = tester.renderObject(button);
    expect(
      hit.path.any((e) => e.target == target),
      isTrue,
      reason: 'appui intercepté',
    );
  }

  testWidgets('écran « Créer mon coffre » : bouton jamais recouvert', (
    tester,
  ) async {
    final session = newSession();
    await tester.runAsync(session.load);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: CreateVaultView(session: session, onCancel: () {}),
          ),
        ),
      ),
    );
    await showAlert(tester, find.byType(CreateVaultView));

    expect(find.byType(SnackBar), findsNothing);
    expectReachable(
      tester,
      find.widgetWithText(FilledButton, 'Créer mon coffre'),
    );
    expectReachable(tester, find.widgetWithText(TextButton, 'Annuler'));
    await tester.pump(wifiAlertDuration); // fermeture automatique
  });

  testWidgets('écran d\'un mot de passe : « Enregistrer » jamais recouvert', (
    tester,
  ) async {
    final session = newSession();
    await tester.runAsync(() async {
      await session.load();
      await session.create('cheval correct batterie');
      session.recoveryKeyNoted();
    });
    final clipboard = ClipboardGuard();
    addTearDown(clipboard.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: VaultItemScreen(
          session: session,
          clipboard: clipboard,
          type: VaultItemType.motDePasse,
        ),
      ),
    );
    await showAlert(tester, find.byType(VaultItemScreen));

    expect(find.byType(SnackBar), findsNothing);
    expectReachable(tester, find.text('Enregistrer'));
    await tester.pump(wifiAlertDuration); // fermeture automatique
  });

  testWidgets('se ferme seule après 10 s, ou avec « Fermer »', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));
    await showAlert(tester, find.text('x'));
    expect(find.byType(MaterialBanner), findsOneWidget);
    await tester.pump(wifiAlertDuration);
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);

    await showAlert(tester, find.text('x'));
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('« Détails » ferme le bandeau et ouvre les détails', (
    tester,
  ) async {
    var details = 0;
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));
    showWifiAlert(
      tester.element(find.text('x')),
      message: 'Wi-Fi ouvert',
      onDetails: () => details++,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Détails'));
    await tester.pumpAndSettle();
    expect(details, 1);
    expect(find.byType(MaterialBanner), findsNothing);
  });
}
