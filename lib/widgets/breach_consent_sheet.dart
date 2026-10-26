import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// Demande l'accord avant d'utiliser Have I Been Pwned.
/// Renvoie true seulement si l'utilisateur appuie sur « Vérifier ».
Future<bool> askBreachConsent(BuildContext context) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: context.colors.chaux,
    elevation: 0,
    isScrollControlled: true,
    builder: (context) => const _ConsentSheet(),
  );
  return accepted == true;
}

class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = context.colors.secondaire;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.breachConsentTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.breachConsentText,
              style: TextStyle(fontSize: 15, color: context.colors.encre),
            ),
            const SizedBox(height: 12),
            Text(
              l.breachConsentDetail,
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.bleu,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l.breachConsentCheck),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: muted),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l.commonCancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
