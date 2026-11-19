import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

/// Niveau d'un statut. Toujours affiché avec couleur + icône + texte :
/// jamais la couleur seule (daltonisme, lecture rapide).
enum StatusLevel {
  danger, // Dangereux, risque élevé
  warning, // Suspect, modéré, faible protection
  ok, // Rien de connu, faible risque, correct
  neutral; // Système, inconnu, désactivé

  Color color(AppColors c) => switch (this) {
    danger => c.rommen,
    warning => c.ocre,
    ok => c.zitouna,
    neutral => c.secondaire,
  };

  IconData get icon => switch (this) {
    danger => Icons.gpp_bad_outlined,
    warning => Icons.error_outline,
    ok => Icons.verified_user_outlined,
    neutral => Icons.remove_circle_outline,
  };
}

/// Petit badge : icône et mot sur un fond teinté très léger, en pilule.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.level, required this.label});

  final StatusLevel level;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = level.color(context.colors);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.badge,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(level.icon, size: AppSize.iconSmall, color: color),
            const SizedBox(width: AppSpace.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: AppText.detail,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grand verdict : icône dans une arche teintée, mot en grand, phrase.
/// Utilisé par les liens, les QR codes et le détail d'une app.
class VerdictHeader extends StatelessWidget {
  const VerdictHeader({
    super.key,
    required this.level,
    required this.label,
    this.subtitle,
  });

  final StatusLevel level;
  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = level.color(c);
    // liveRegion : TalkBack annonce le verdict dès qu'il s'affiche,
    // titre et sous-titre ensemble.
    return MergeSemantics(
      child: Semantics(
        liveRegion: true,
        header: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Petite arche de Sidi Bou, comme celle du score.
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSize.verdictArch / 2),
              ),
              child: Container(
                width: AppSize.verdictArch,
                height: AppSize.verdictArch * 1.2,
                color: color.withValues(alpha: 0.12),
                alignment: const Alignment(0, 0.3),
                child: Icon(level.icon, color: color, size: AppSize.iconLarge),
              ),
            ),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppText.titre,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (subtitle case final subtitle?) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppText.corps,
                        color: c.secondaire,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
