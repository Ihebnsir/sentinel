import 'package:material_ui/material_ui.dart';

import '../services/vault/vault_platform.dart';
import '../theme/app_colors.dart';

/// Texte de l'avertissement montré avant la première copie (SEN-03).
const sharedClipboardWarning =
    'Sur cette version d\'Android, toutes les applications peuvent lire ce '
    'que vous copiez. Le presse-papiers sera vidé après 10 secondes.';

/// Copie depuis le coffre. Sur Android 9 et avant, demande d'abord une
/// confirmation (une fois par ouverture de l'app).
/// Renvoie le délai avant effacement, ou null si l'utilisateur annule.
Future<Duration?> copyFromVault(
  BuildContext context,
  ClipboardGuard clipboard,
  String text,
) async {
  if (await clipboard.needsWarning()) {
    if (!context.mounted) return null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Presse-papiers partagé'),
        content: const Text(sharedClipboardWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Copier quand même'),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    clipboard.acceptWarning();
  }
  return clipboard.copy(text);
}
