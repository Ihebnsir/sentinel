import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/models/security_action.dart';
import 'package:sentinel/services/apps_scanner_service.dart';
import 'package:sentinel/services/device_security_service.dart';
import 'package:sentinel/services/notification_permission.dart';

// Services qui parlent à MainActivity.kt : un faux canal joue Android,
// pour vérifier les arguments envoyés et la réaction aux erreurs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  void android(String name, Object? Function(MethodCall call) answer) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
      calls.add(call);
      return answer(call);
    });
  }

  Never refuse(MethodCall call) => throw PlatformException(code: 'ERROR');

  setUp(() => calls = []);
  tearDown(() {
    for (final name in ['notifications', 'apps', 'device_security']) {
      messenger.setMockMethodCallHandler(
        MethodChannel('com.iheb.sentinel/$name'),
        null,
      );
    }
  });

  group('NotificationPermission', () {
    const canal = 'com.iheb.sentinel/notifications';
    const service = NotificationPermission();

    test('demande : réponse d\'Android transmise', () async {
      android(canal, (call) => true);
      expect(await service.request(), isTrue);
      expect([for (final c in calls) c.method], ['requestPermission']);
    });

    test('Android refuse, pas de code Android ou réponse vide : false', () async {
      expect(await service.request(), isFalse);
      android(canal, refuse);
      expect(await service.request(), isFalse);
      android(canal, (call) => null);
      expect(await service.request(), isFalse);
    });
  });

  group('AppsScannerService', () {
    const canal = 'com.iheb.sentinel/apps';
    final service = AppsScannerService();

    test('ignore les éléments qui ne sont pas des Map', () async {
      android(
        canal,
        (call) => [
          {'packageName': 'com.exemple.app', 'label': 'Exemple'},
          'pas une app',
          null,
        ],
      );
      final apps = await service.scanApps();
      expect(apps!.single.packageName, 'com.exemple.app');
      expect(apps.single.label, 'Exemple');
    });

    test('pas de code Android ou liste absente : null', () async {
      expect(await service.scanApps(), isNull);
      android(canal, (call) => null);
      expect(await service.scanApps(), isNull);
    });

    test('erreur Android remontée à l\'écran (message d\'erreur)', () async {
      android(canal, refuse);
      expect(service.scanApps(), throwsA(isA<PlatformException>()));
    });

    test('actions : argument packageName, ou url pour une page', () async {
      android(canal, (call) => null);
      await service.openAppSettings('com.exemple.app');
      await service.uninstallApp('com.exemple.app');
      await service.openWebPage('https://exemple.com');
      expect(calls[0].arguments, {'packageName': 'com.exemple.app'});
      expect(calls[1].method, 'uninstallApp');
      expect(calls[2].arguments, {'url': 'https://exemple.com'});
    });

    test('action refusée ou sans code Android : pas d\'exception', () async {
      await service.openAppSettings('com.exemple.app');
      android(canal, refuse);
      await service.uninstallApp('com.exemple.app');
      expect(calls, hasLength(1));
    });
  });

  group('DeviceSecurityService', () {
    const canal = 'com.iheb.sentinel/device_security';
    final service = DeviceSecurityService();

    test('lit l\'audit envoyé par Android', () async {
      android(canal, (call) => {'screenLock': true, 'sdkInt': 35});
      final status = await service.getSecurityStatus();
      expect(status!.screenLock, isTrue);
      expect(status.sdkInt, 35);
    });

    test('pas de code Android ou réponse vide : null', () async {
      expect(await service.getSecurityStatus(), isNull);
      android(canal, (call) => null);
      expect(await service.getSecurityStatus(), isNull);
    });

    test('erreur Android remontée à l\'écran', () async {
      android(canal, refuse);
      expect(service.getSecurityStatus(), throwsA(isA<PlatformException>()));
    });

    test('ouvrir un réglage envoie son nom ; erreur ignorée', () async {
      await service.openSettings(SettingsTarget.update); // sans Android
      android(canal, (call) => null);
      await service.openSettings(SettingsTarget.developer);
      expect(calls.single.arguments, {'target': 'developer'});
      android(canal, refuse);
      await service.openSettings(SettingsTarget.security);
      expect(calls, hasLength(2));
    });
  });
}
