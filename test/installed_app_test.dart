import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/models/installed_app.dart';

void main() {
  test('fromMap lit la Map envoyée par Android', () {
    final icon = Uint8List.fromList([137, 80, 78, 71]);
    final installed = DateTime(2026, 3, 1, 10, 30);
    final updated = DateTime(2026, 9, 15, 8);

    final app = InstalledApp.fromMap({
      'packageName': 'com.whatsapp',
      'label': 'WhatsApp',
      'icon': icon,
      'isSystemApp': false,
      'installerPackage': 'com.android.vending',
      'versionName': '2.26.1',
      'firstInstallTime': installed.millisecondsSinceEpoch,
      'lastUpdateTime': updated.millisecondsSinceEpoch,
      'targetSdk': 35,
      'grantedPermissions': [
        'android.permission.CAMERA',
        'android.permission.READ_CONTACTS',
      ],
      'requestsOverlay': true,
      'accessibilityServiceEnabled': false,
      'notificationListenerEnabled': true,
      'isDeviceAdmin': false,
    });

    expect(app.packageName, 'com.whatsapp');
    expect(app.label, 'WhatsApp');
    expect(app.icon, icon);
    expect(app.isSystemApp, isFalse);
    expect(app.installerPackage, 'com.android.vending');
    expect(app.isFromPlayStore, isTrue);
    expect(app.storeName, 'Play Store');
    expect(app.versionName, '2.26.1');
    expect(app.firstInstallTime, installed);
    expect(app.lastUpdateTime, updated);
    expect(app.targetSdk, 35);
    expect(app.grantedPermissions, hasLength(2));
    expect(app.hasPermission('android.permission.CAMERA'), isTrue);
    expect(app.hasPermission('android.permission.RECORD_AUDIO'), isFalse);
    expect(app.requestsOverlay, isTrue);
    expect(app.accessibilityServiceEnabled, isFalse);
    expect(app.notificationListenerEnabled, isTrue);
    expect(app.isDeviceAdmin, isFalse);
  });

  test('fromMap : valeurs absentes = valeurs neutres', () {
    final app = InstalledApp.fromMap({
      'packageName': 'com.exemple',
      'firstInstallTime': 0,
    });
    expect(app.label, 'com.exemple'); // nom technique à défaut
    expect(app.icon, isNull);
    expect(app.isSystemApp, isFalse);
    expect(app.installerPackage, isNull);
    expect(app.isFromPlayStore, isFalse);
    expect(app.storeName, isNull);
    expect(app.isFromOfficialStore, isFalse);
    expect(app.firstInstallTime, isNull);
    expect(app.lastUpdateTime, isNull);
    expect(app.targetSdk, 0);
    expect(app.grantedPermissions, isEmpty);
    expect(app.accessibilityServiceEnabled, isFalse);
  });

  test('boutique de fabricant : nom affiché et boutique officielle', () {
    final app = InstalledApp.fromMap({
      'installerPackage': 'com.huawei.appmarket',
    });
    expect(app.storeName, 'AppGallery');
    expect(app.isFromOfficialStore, isTrue);
    expect(app.isFromPlayStore, isFalse);
  });

  test('la liste des permissions ne peut pas être modifiée', () {
    final app = InstalledApp.fromMap({
      'grantedPermissions': ['android.permission.CAMERA'],
    });
    expect(
      () => app.grantedPermissions.add('android.permission.READ_SMS'),
      throwsUnsupportedError,
    );
  });

  test("fromMap lit les certificats, le debug et l'icône", () {
    final app = InstalledApp.fromMap({
      'packageName': 'com.exemple',
      'signingCerts': [
        {
          'sha256': 'ab:cd${'0' * 60}',
          'sha1': 'ef${'0' * 38}',
          'subjectCn': 'Exemple Inc.',
          'subjectO': 'Exemple',
          'current': true,
        },
        {'sha256': 'ff', 'sha1': 'ff', 'current': false},
        'pas une map', // ignoré
      ],
      'debugCert': true,
      'hasLauncherIcon': false,
    });
    expect(app.signingCerts, hasLength(2));
    expect(app.mainCert!.sha256, 'ABCD${'0' * 60}'); // normalisée
    expect(app.mainCert!.sha1, 'EF${'0' * 38}');
    expect(app.mainCert!.subject, 'Exemple Inc. (Exemple)');
    expect(app.signingCerts[1].current, isFalse);
    expect(app.debugCert, isTrue);
    expect(app.hasLauncherIcon, isFalse);
  });

  test('fromMap : sans données de signature, valeurs neutres', () {
    final app = InstalledApp.fromMap({'packageName': 'com.exemple'});
    expect(app.signingCerts, isEmpty);
    expect(app.mainCert, isNull);
    expect(app.debugCert, isFalse);
    expect(app.hasLauncherIcon, isTrue); // pas d'alerte par défaut
  });
}
