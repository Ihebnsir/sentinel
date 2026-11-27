import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/links/link_checker.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Statut d'un verdict : danger, avertissement ou rien de connu.
StatusLevel verdictStatus(Verdict verdict) => switch (verdict) {
  Verdict.dangereux => StatusLevel.danger,
  Verdict.suspect => StatusLevel.warning,
  Verdict.rien => StatusLevel.ok,
};

/// Couleur d'un verdict : rouge, ocre ou vert.
Color verdictColor(AppColors c, Verdict verdict) =>
    verdictStatus(verdict).color(c);

/// Verdict très lisible (arche teintée + icône + mot + couleur),
/// raisons séparées par des traits fins, puis le conseil.
/// Utilisé par l'onglet Liens et par le résultat d'un QR code.
class VerdictSection extends StatelessWidget {
  const VerdictSection({
    super.key,
    required this.verdict,
    required this.reasons,
    required this.advice,
    this.subtitle,
    this.note,
  });

  final Verdict verdict;
  final String? subtitle; // ex : « Ce lien mène en réalité à site[.]xyz »
  final List<String> reasons;
  final String advice;

  /// Information neutre, affichée seulement sans danger (verdict « rien »).
  final String? note;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final level = verdictStatus(verdict);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.xl),
        VerdictHeader(
          level: level,
          label: verdict.label(l),
          subtitle: subtitle,
        ),
        const SizedBox(height: AppSpace.lg),
        for (final reason in reasons) ...[
          const AppDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Petit repère de la couleur du verdict devant chaque raison.
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: Icon(
                    level.icon,
                    size: AppSize.iconSmall,
                    color: level.color(c),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    reason,
                    style: TextStyle(fontSize: AppText.corps, color: c.encre),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Icône info et gris : ce n'est pas une raison du verdict.
        if (note case final note? when verdict == Verdict.rien) ...[
          const AppDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: Icon(
                    Icons.info_outline,
                    size: AppSize.iconSmall,
                    color: c.secondaire,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    note,
                    style: TextStyle(
                      fontSize: AppText.corps,
                      color: c.secondaire,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const AppDivider(),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.lg),
          child: Text(
            advice,
            style: TextStyle(
              fontSize: AppText.corps,
              fontWeight: FontWeight.w500,
              color: c.encre,
            ),
          ),
        ),
      ],
    );
  }
}
