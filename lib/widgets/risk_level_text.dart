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
  static Color colorFor(AppColors c, RiskLevel level) => switch (level) {
    RiskLevel.eleve => c.rommen,
    RiskLevel.modere => c.ocre,
    RiskLevel.faible => c.zitouna,
    RiskLevel.systeme => c.discret,
  };

  @override
  Widget build(BuildContext context) {
    return Text(
      level.label(context.l10n),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: colorFor(context.colors, level),
      ),
    );
  }
}
