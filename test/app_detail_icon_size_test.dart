import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/models/installed_app.dart';
import 'package:sentinel/screens/app_detail_screen.dart';
import 'package:sentinel/services/app_risk_calculator.dart';
import 'package:sentinel/widgets/app_icon.dart';
import 'support/l10n.dart';

// Une image PNG de 1x1 pixel, pour tester l'icône avec une vraie image.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

InstalledApp _app({required bool withIcon}) => InstalledApp(
  packageName: 'com.example.test',
  label: 'Test',
  icon: withIcon ? _png : null,
  isSystemApp: false,
  installerPackage: null,
  versionName: '1.0',
  firstInstallTime: null,
  lastUpdateTime: null,
  targetSdk: 35,
  grantedPermissions: const [],
  requestsOverlay: false,
  accessibilityServiceEnabled: false,
  notificationListenerEnabled: false,
  isDeviceAdmin: false,
  signingCerts: const [],
  debugCert: false,
  hasLauncherIcon: true,
);

void main() {
  // Régression : dans la ListView, l'icône était étirée sur toute la
  // largeur de l'écran (744x64) et devenait floue.
  group("Écran de détail : l'icône reste un carré de 64x64", () {
    for (final withIcon in [true, false]) {
      testWidgets(withIcon ? 'avec une image' : 'sans image (carré neutre)', (
        tester,
      ) async {
        const report = AppRiskReport(
          score: 0,
          level: RiskLevel.faible,
          rules: [],
        );
        await tester.pumpWidget(
          testApp(
            home: AppDetailScreen(
              app: _app(withIcon: withIcon),
              report: report,
            ),
          ),
        );

        expect(tester.getSize(find.byType(AppIcon)), const Size(64, 64));
      });
    }
  });
}
