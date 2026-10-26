import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// L'arche du score : elle se remplit de bas en haut selon le score (0 à 100).
class ScoreArch extends StatelessWidget {
  const ScoreArch({super.key, required this.score}) : message = null;

  /// Arche vide avec un message à la place du chiffre (pendant l'analyse).
  const ScoreArch.empty({super.key, required String this.message}) : score = 0;

  final int score;
  final String? message;

  static const _width = 220.0;
  static const _height = 300.0;

  /// Couleur selon le niveau de sécurité.
  static Color colorFor(AppColors c, int score) {
    if (score >= 70) return c.bleu;
    if (score >= 45) return c.ocre;
    return c.rommen;
  }

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message != null) {
      return _frame(
        background: context.colors.bleu.withValues(alpha: 0.12),
        children: [
          Positioned(
            bottom: 28,
            child: Text(
              message,
              style: TextStyle(color: context.colors.secondaire),
            ),
          ),
        ],
      );
    }

    final color = colorFor(context.colors, score);

    // TweenAnimationBuilder anime une valeur de 0 jusqu'au score.
    // La fonction builder est rappelée à chaque image de l'animation
    // avec la valeur actuelle (value).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score.toDouble()),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        // Le chiffre est sur la partie remplie à partir de 45 : texte le
        // plus lisible sur cette couleur (contraste WCAG).
        final onFill = value >= 45;
        final textColor = onFill
            ? context.colors.textOn(color)
            : context.colors.encre;

        return _frame(
          background: color.withValues(alpha: 0.12),
          children: [
            // Partie remplie : sa hauteur suit la valeur animée.
            FractionallySizedBox(
              heightFactor: value / 100,
              widthFactor: 1,
              child: Container(color: color),
            ),
            // Le chiffre et « sur 100 », placés en bas.
            Positioned(
              bottom: 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${value.round()}',
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w300,
                      color: textColor,
                    ),
                  ),
                  Text(
                    context.l10n.commonOutOf100,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// La forme de l'arche : fond coloré, haut arrondi, contenu empilé.
  Widget _frame({required Color background, required List<Widget> children}) {
    // ClipRRect découpe le haut en demi-cercle (rayon = moitié de la largeur).
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(_width / 2),
      ),
      child: Container(
        width: _width,
        height: _height,
        color: background,
        // Stack empile les widgets les uns sur les autres.
        child: Stack(alignment: Alignment.bottomCenter, children: children),
      ),
    );
  }
}
