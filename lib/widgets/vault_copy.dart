import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/vault/vault_platform.dart';
import '../theme/app_colors.dart';

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
        // Avertissement montré avant la première copie (SEN-03).
        title: Text(context.l10n.clipboardSharedTitle),
        content: Text(context.l10n.clipboardSharedWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.bleu),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.clipboardCopyAnyway),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    clipboard.acceptWarning();
  }
  return clipboard.copy(text);
}
