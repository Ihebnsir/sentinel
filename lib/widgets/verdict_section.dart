import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/phishing/message_analyzer.dart';
import '../theme/app_colors.dart';

/// Couleur d'un verdict : rouge, ocre ou vert.
Color verdictColor(AppColors c, Verdict verdict) => switch (verdict) {
  Verdict.arnaque => c.rommen,
  Verdict.suspect => c.ocre,
  Verdict.rien => c.zitouna,
};

/// Verdict en grand, sous-titre, raisons séparées par des traits, conseil.
/// Utilisé par l'onglet Messages et par le résultat d'un QR code.
class VerdictSection extends StatelessWidget {
  const VerdictSection({
    super.key,
    required this.verdict,
    required this.reasons,
    required this.advice,
    this.subtitle,
  });

  final Verdict verdict;
  final String? subtitle; // ex : « Probabilité d'arnaque : 87 % »
  final List<String> reasons;
  final String advice;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = context.colors.secondaire;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text(
          verdict.label(l),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: verdictColor(context.colors, verdict),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: TextStyle(fontSize: 15, color: muted)),
        ],
        const SizedBox(height: 12),
        for (final reason in reasons) ...[
          Divider(height: 1, thickness: 1, color: context.colors.ligne),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              reason,
              style: TextStyle(fontSize: 15, color: context.colors.encre),
            ),
          ),
        ],
        Divider(height: 1, thickness: 1, color: context.colors.ligne),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            advice,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.colors.encre,
            ),
          ),
        ),
      ],
    );
  }
}
