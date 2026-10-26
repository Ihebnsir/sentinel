import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// État vide réutilisable : grande icône, titre, explication et bouton.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? buttonLabel; // si null : pas de bouton
  final VoidCallback? onPressed; // si null : affiche « Bientôt disponible »

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.commonComingSoon)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      // Largeur limitée pour garder le texte sur 2-3 lignes.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: context.colors.bleu),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: context.colors.secondaire),
            ),
            if (buttonLabel case final label?) ...[
              const SizedBox(height: 28),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.bleu,
                ),
                onPressed: onPressed ?? () => _showComingSoon(context),
                child: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
