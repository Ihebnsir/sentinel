import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

/// Séparateur fin, la signature visuelle de Sentinel (pas de cartes).
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.color});

  /// Couleur de [AppColors.ligne] par défaut (rouge pour un bloc d'alerte).
  final Color? color;

  @override
  Widget build(BuildContext context) => Divider(
    height: AppSize.line,
    thickness: AppSize.line,
    color: color ?? context.colors.ligne,
  );
}
