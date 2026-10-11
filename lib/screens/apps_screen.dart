import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../widgets/empty_state.dart';

/// Onglet « Applications » : analyse des permissions (à venir).
class AppsScreen extends StatelessWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Applications',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            // Expanded : l'état vide occupe le reste et se centre dedans.
            Expanded(
              child: EmptyState(
                icon: Icons.apps_outlined,
                title: 'Analysez vos applications',
                message:
                    'Sentinel vérifie les permissions de chaque application '
                    'installée et signale celles qui en demandent trop.',
                buttonLabel: "Lancer l'analyse",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
