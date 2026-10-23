import 'dart:async';

import 'package:material_ui/material_ui.dart';

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
  messenger.clearMaterialBanners();
  final controller = messenger.showMaterialBanner(
    MaterialBanner(
      backgroundColor: AppColors.rommen,
      leading: const Icon(Icons.wifi_off, color: Colors.white),
      content: Text(message, style: const TextStyle(color: Colors.white)),
      actions: [
        TextButton(
          onPressed: messenger.hideCurrentMaterialBanner,
          child: const Text('Fermer', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
            onDetails();
          },
          child: const Text('Détails', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  final timer = Timer(duration, controller.close);
  controller.closed.then((_) => timer.cancel());
}
