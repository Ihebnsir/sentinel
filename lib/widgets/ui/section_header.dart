import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

/// Titre d'un onglet ou d'un écran, avec un sous-titre facultatif.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.secondary = false,
  });

  final String title;
  final String? subtitle;

  /// Écran poussé (titre un peu plus petit qu'un onglet).
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: TextStyle(
              fontSize: secondary ? AppText.titreSecondaire : AppText.titre,
              fontWeight: FontWeight.w600,
              color: c.encre,
            ),
          ),
        ),
        if (subtitle case final subtitle?) ...[
          const SizedBox(height: AppSpace.xs),
          Text(
            subtitle,
            style: TextStyle(fontSize: AppText.corps, color: c.secondaire),
          ),
        ],
      ],
    );
  }
}

/// En-tête de section : intertitre, et à droite un élément facultatif.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.color,
  });

  final String title;
  final Widget? trailing;
  final Color? color; // encre par défaut

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: AppText.section,
                  fontWeight: FontWeight.w600,
                  color: color ?? context.colors.encre,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
