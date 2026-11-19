import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/links/link_checker.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Couleur d'un verdict : rouge, ocre ou vert.
Color verdictColor(AppColors c, Verdict verdict) => switch (verdict) {
  Verdict.dangereux => c.rommen,
  Verdict.suspect => c.ocre,
  Verdict.rien => c.zitouna,
};

/// Verdict en grand, sous-titre, raisons séparées par des traits, conseil.
/// Utilisé par l'onglet Liens et par le résultat d'un QR code.
class VerdictSection extends StatelessWidget {
  const VerdictSection({
    super.key,
    required this.verdict,
    required this.reasons,
    required this.advice,
    this.subtitle,
  });

  final Verdict verdict;
  final String? subtitle; // ex : « Ce lien mène en réalité à site[.]xyz »
  final List<String> reasons;
  final String advice;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = context.colors.secondaire;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.xl),
        // liveRegion : TalkBack annonce le verdict dès qu'il s'affiche,
        // titre et sous-titre ensemble.
        MergeSemantics(
          child: Semantics(
            liveRegion: true,
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verdict.label(l),
                  style: TextStyle(
                    fontSize: AppText.titre,
                    fontWeight: FontWeight.w600,
                    color: verdictColor(context.colors, verdict),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(subtitle!, style: TextStyle(fontSize: AppText.corps, color: muted)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        for (final reason in reasons) ...[
          const AppDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
            child: Text(
              reason,
              style: TextStyle(fontSize: AppText.corps, color: context.colors.encre),
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
              color: context.colors.encre,
            ),
          ),
        ),
      ],
    );
  }
}
