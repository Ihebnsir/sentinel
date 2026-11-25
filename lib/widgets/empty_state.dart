import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import 'arch_icon.dart';
import 'ui/app_buttons.dart';

/// État vide réutilisable : grande arche de Sentinel, titre, explication et
/// bouton principal facultatif.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onPressed,
    this.buttonIcon,
  });

  final String title;
  final String message;
  final String? buttonLabel; // si null : pas de bouton
  final VoidCallback? onPressed;
  final IconData? buttonIcon;

  @override
  Widget build(BuildContext context) {
    // Un peu au-dessus du centre : l'œil y tombe naturellement.
    return Align(
      alignment: const Alignment(0, -0.25),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          // Largeur limitée pour garder le texte sur 2-3 lignes.
          constraints: const BoxConstraints(maxWidth: AppSize.textColumn),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // L'icône de l'app, en bleu du thème ; décorative.
              ExcludeSemantics(
                child: ArchIcon(
                  filled: true,
                  size: AppSize.illustration,
                  color: context.colors.bleu,
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppText.accroche,
                  fontWeight: FontWeight.w600,
                  color: context.colors.encre,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppText.corps,
                  color: context.colors.secondaire,
                ),
              ),
              if (buttonLabel case final label?) ...[
                const SizedBox(height: AppSpace.xl),
                PrimaryButton(
                  label: label,
                  icon: buttonIcon,
                  onPressed: onPressed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
