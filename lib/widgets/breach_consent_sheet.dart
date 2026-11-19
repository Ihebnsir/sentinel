import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

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
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.breachConsentTitle,
              style: TextStyle(
                fontSize: AppText.titreSecondaire,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              l.breachConsentText,
              style: TextStyle(fontSize: AppText.corps, color: context.colors.encre),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              l.breachConsentDetail,
              style: TextStyle(fontSize: AppText.detail, color: muted),
            ),
            const SizedBox(height: AppSpace.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l.breachConsentCheck),
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: mutedButtonStyle(context),
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
