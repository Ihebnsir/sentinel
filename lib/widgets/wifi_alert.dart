import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// Durée d'affichage de l'alerte Wi-Fi avant qu'elle se ferme seule.
const wifiAlertDuration = Duration(seconds: 10);

/// Alerte « Wi-Fi dangereux », en bandeau en haut de l'écran (SEN-17).
/// Un MaterialBanner décale le contenu vers le bas : contrairement à
/// l'ancienne SnackBar (avec action, donc jamais fermée), il ne recouvre
/// aucun bouton. Il se ferme seul après [duration].
void showWifiAlert(
  BuildContext context, {
  required String message,
  required VoidCallback onDetails,
  Duration duration = wifiAlertDuration,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  messenger.clearMaterialBanners();
  // Texte lisible sur le rouge plein, en clair comme en sombre.
  final colors = context.colors;
  final onRed = colors.textOn(colors.rommen);
  final controller = messenger.showMaterialBanner(
    MaterialBanner(
      backgroundColor: colors.rommen,
      leading: Icon(Icons.wifi_off, color: onRed),
      content: Text(message, style: TextStyle(color: onRed)),
      actions: [
        TextButton(
          onPressed: messenger.hideCurrentMaterialBanner,
          child: Text(l.commonClose, style: TextStyle(color: onRed)),
        ),
        TextButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
            onDetails();
          },
          child: Text(l.commonDetails, style: TextStyle(color: onRed)),
        ),
      ],
    ),
  );
  final timer = Timer(duration, controller.close);
  controller.closed.then((_) => timer.cancel());
}
