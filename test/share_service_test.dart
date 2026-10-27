import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/share_service.dart';

// ShareService reçoit les textes partagés par MainActivity.kt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.iheb.sentinel/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void android(Object? Function(MethodCall call) answer) =>
      messenger.setMockMethodCallHandler(channel, (call) async => answer(call));

  // Kotlin envoie un texte alors que l'app est déjà ouverte.
  Future<void> partager(String? text) => messenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall('onSharedText', text)),
    (_) {},
  );

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('texte reçu au lancement', () async {
    android((call) => 'Votre colis est bloqué');
    final service = ShareService();
    await service.start();
    expect(service.received.value?.text, 'Votre colis est bloqué');
    service.dispose();
  });

  test('textes reçus ensuite ; le même texte prévient deux fois', () async {
    android((call) => null);
    final service = ShareService();
    var avertissements = 0;
    service.received.addListener(() => avertissements++);
    await service.start();
    expect(service.received.value, isNull);

    await partager('lien suspect');
    await partager('lien suspect');
    expect(service.received.value?.text, 'lien suspect');
    expect(avertissements, 2);
    service.dispose();
  });

  test('texte vide, blanc ou absent : ignoré', () async {
    android((call) => '   ');
    final service = ShareService();
    await service.start();
    await partager('');
    await partager(null);
    await partager('\n\t');
    expect(service.received.value, isNull);
    service.dispose();
  });

  test('réponse arrivée après la fermeture : ignorée', () async {
    final service = ShareService();
    android((call) {
      service.dispose(); // l'écran se ferme pendant l'attente
      return 'trop tard';
    });
    await service.start(); // ne doit pas toucher au notifier fermé
  });

  test('erreur Android ou pas de code natif : rien reçu', () async {
    final sansAndroid = ShareService();
    await sansAndroid.start();
    expect(sansAndroid.received.value, isNull);
    sansAndroid.dispose();

    android((call) => throw PlatformException(code: 'ERREUR'));
    final service = ShareService();
    await service.start();
    expect(service.received.value, isNull);
    service.dispose();
  });

  group('tuile du pare-feu', () {
    Future<void> tuile() => messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('onOpenFirewall')),
      (_) {},
    );

    test('lancement par la tuile : une demande', () async {
      android((call) => call.method == 'getInitialOpenFirewall' ? true : null);
      final service = ShareService();
      await service.start();
      expect(service.firewallRequests.value, 1);
      expect(service.received.value, isNull);
      service.dispose();
    });

    test('lancement normal : aucune demande', () async {
      android((call) => call.method == 'getInitialOpenFirewall' ? false : null);
      final service = ShareService();
      await service.start();
      expect(service.firewallRequests.value, 0);
      service.dispose();
    });

    test('app déjà ouverte : chaque appui prévient', () async {
      android((call) => null);
      final service = ShareService();
      var avertissements = 0;
      service.firewallRequests.addListener(() => avertissements++);
      await service.start();
      await tuile();
      await tuile();
      expect(avertissements, 2);
      service.dispose();
    });

    test('réponse inattendue ou après fermeture : ignorée', () async {
      android((call) => 'pas un booléen');
      final service = ShareService();
      await service.start();
      expect(service.firewallRequests.value, 0);
      service.dispose();
      await tuile(); // ne doit pas toucher au notifier fermé
    });
  });
}
