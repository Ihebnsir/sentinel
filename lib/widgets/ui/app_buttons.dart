import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

// Les trois boutons de l'app. Leurs couleurs viennent du thème
// (AppTheme) : ces widgets ajoutent l'icône, la pleine largeur et l'état
// « en cours » (petit cercle qui tourne, bouton inactif).

/// Bouton principal : bleu plein. Un seul par écran, pour l'action clé.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed; // null : inactif
  final IconData? icon;
  final bool busy; // action en cours
  final bool expand; // toute la largeur
  final bool danger; // action destructrice (rouge)

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = danger
        ? FilledButton.styleFrom(
            backgroundColor: c.rommen,
            foregroundColor: c.textOn(c.rommen),
          )
        : null;
    final action = busy ? null : onPressed;
    final button = icon == null && !busy
        ? FilledButton(style: style, onPressed: action, child: Text(label))
        : FilledButton.icon(
            style: style,
            onPressed: action,
            icon: _ButtonIcon(icon: icon, busy: busy),
            label: Text(label),
          );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Bouton secondaire : contour fin, pour l'action alternative.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final action = busy ? null : onPressed;
    final button = icon == null && !busy
        ? OutlinedButton(onPressed: action, child: Text(label))
        : OutlinedButton.icon(
            onPressed: action,
            icon: _ButtonIcon(icon: icon, busy: busy),
            label: Text(label),
          );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Style d'un bouton texte discret (« Annuler », « Plus tard »).
ButtonStyle mutedButtonStyle(BuildContext context) =>
    TextButton.styleFrom(foregroundColor: context.colors.secondaire);

/// Icône d'un bouton, remplacée par un petit cercle pendant l'action.
class _ButtonIcon extends StatelessWidget {
  const _ButtonIcon({required this.icon, required this.busy});

  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return SizedBox.square(
        dimension: AppSize.iconSmall,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: IconTheme.of(context).color,
        ),
      );
    }
    return Icon(icon, size: AppSize.iconSmall);
  }
}

/// Bouton texte rouge, pour une action destructrice (« Supprimer »).
ButtonStyle dangerButtonStyle(BuildContext context) =>
    TextButton.styleFrom(foregroundColor: context.colors.rommen);

/// Bouton rouge plein (confirmation d'une suppression).
ButtonStyle dangerFilledStyle(BuildContext context) => FilledButton.styleFrom(
  backgroundColor: context.colors.rommen,
  foregroundColor: context.colors.textOn(context.colors.rommen),
);

/// Bouton texte aligné sur le texte de la page (sans marge intérieure).
ButtonStyle inlineButtonStyle(BuildContext context, {bool danger = false}) =>
    TextButton.styleFrom(
      foregroundColor: danger ? context.colors.rommen : null,
      padding: EdgeInsets.zero,
    );
