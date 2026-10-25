import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/app_risk_calculator.dart';
import '../theme/app_colors.dart';

/// Le niveau de risque en texte coloré : « Élevé », « Modéré », « Faible » ou « Système ».
class RiskLevelText extends StatelessWidget {
  const RiskLevelText({super.key, required this.level, this.fontSize = 14});

  final RiskLevel level;
  final double fontSize;

  /// Couleur selon le niveau.
  static Color colorFor(RiskLevel level) => switch (level) {
        RiskLevel.eleve => AppColors.rommen,
        RiskLevel.modere => AppColors.ocre,
        RiskLevel.faible => AppColors.zitouna,
        RiskLevel.systeme => AppColors.encre.withValues(alpha: 0.45),
      };

  @override
  Widget build(BuildContext context) {
    return Text(
      level.label(context.l10n),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: colorFor(level),
      ),
    );
  }
}
