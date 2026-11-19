import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/app_risk_calculator.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Statut correspondant à un niveau de risque.
StatusLevel riskStatus(RiskLevel level) => switch (level) {
  RiskLevel.eleve => StatusLevel.danger,
  RiskLevel.modere => StatusLevel.warning,
  RiskLevel.faible => StatusLevel.ok,
  RiskLevel.systeme => StatusLevel.neutral,
};

/// Le niveau de risque en badge : icône + mot + couleur
/// (« Élevé », « Modéré », « Faible » ou « Système »).
class RiskLevelText extends StatelessWidget {
  const RiskLevelText({super.key, required this.level});

  final RiskLevel level;

  /// Couleur selon le niveau.
  static Color colorFor(AppColors c, RiskLevel level) =>
      riskStatus(level).color(c);

  @override
  Widget build(BuildContext context) =>
      StatusBadge(level: riskStatus(level), label: level.label(context.l10n));
}
