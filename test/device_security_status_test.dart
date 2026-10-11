import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/models/device_security_status.dart';
import 'package:sentinel/utils/french_date.dart';

void main() {
  test('fromMap lit la Map envoyée par Android', () {
    final status = DeviceSecurityStatus.fromMap({
      'screenLock': true,
      'biometricEnrolled': false,
      'rooted': false,
      'developerOptions': true,
      'usbDebugging': false,
      'encrypted': true,
      'androidVersion': '15',
      'sdkInt': 35,
      'securityPatch': '2026-08-05',
    });
    expect(status.screenLock, isTrue);
    expect(status.biometricEnrolled, isFalse);
    expect(status.developerOptions, isTrue);
    expect(status.encrypted, isTrue);
    expect(status.androidVersion, '15');
    expect(status.sdkInt, 35);
    expect(status.securityPatch, DateTime(2026, 8, 5));
  });

  test('fromMap : valeurs absentes = non sécurisé, date inconnue', () {
    final status = DeviceSecurityStatus.fromMap({'securityPatch': ''});
    expect(status.screenLock, isFalse);
    expect(status.encrypted, isFalse);
    expect(status.androidVersion, '');
    expect(status.securityPatch, isNull);
  });

  test('date en français', () {
    expect(formatFrenchDate(DateTime(2026, 8, 5)), '5 août 2026');
    expect(formatFrenchDate(DateTime(2026, 3, 1)), '1er mars 2026');
    expect(formatFrenchDate(DateTime(2025, 12, 31)), '31 décembre 2025');
  });
}
