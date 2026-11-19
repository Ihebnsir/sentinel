import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

/// Ligne de liste : icône, titre et sous-titre, élément à droite.
/// Même hauteur et mêmes marges partout (Accueil, Coffre, Réglages…).
/// [onTap] null : ligne non cliquable. [chevron] : flèche « ouvrir ».
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.leading,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.titleColor,
    this.subtitleMaxLines,
    this.titleMaxLines,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor; // bleu par défaut
  final Widget? leading; // à la place de l'icône (ex : icône d'une app)
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final Color? titleColor;
  final int? subtitleMaxLines;
  final int? titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final icon = this.icon;
    final start =
        leading ??
        (icon == null ? null : Icon(icon, color: iconColor ?? c.bleu));
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.tap),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.row),
          child: Row(
            children: [
              if (start != null) ...[
                start,
                const SizedBox(width: AppSpace.rowGap),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: titleMaxLines,
                      overflow: titleMaxLines == null
                          ? null
                          : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppText.intitule,
                        fontWeight: FontWeight.w500,
                        color: titleColor ?? c.encre,
                      ),
                    ),
                    if (subtitle case final subtitle?) ...[
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        subtitle,
                        maxLines: subtitleMaxLines,
                        overflow: subtitleMaxLines == null
                            ? null
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppText.detail,
                          color: c.secondaire,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing case final trailing?) ...[
                const SizedBox(width: AppSpace.md),
                trailing,
              ],
              if (chevron) ...[
                const SizedBox(width: AppSpace.sm),
                Icon(Icons.chevron_right, color: c.discret),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Message centré à la place d'un contenu (analyse impossible…).
class InfoMessage extends StatelessWidget {
  const InfoMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xxxl),
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppText.intitule,
              color: context.colors.secondaire,
            ),
          ),
        ),
      ),
    );
  }
}
