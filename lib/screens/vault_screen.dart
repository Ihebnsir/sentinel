import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../widgets/empty_state.dart';

/// Onglet « Coffre » : mots de passe et documents chiffrés (à venir).
class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Coffre',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            Expanded(
              child: EmptyState(
                icon: Icons.lock_outline,
                title: 'Vos mots de passe, chiffrés',
                message:
                    'Stockez vos mots de passe et documents sensibles. '
                    'Ils sont chiffrés sur votre téléphone et personne '
                    "d'autre ne peut les lire.",
                buttonLabel: 'Créer mon coffre',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
