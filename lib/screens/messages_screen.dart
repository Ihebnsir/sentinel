import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../widgets/empty_state.dart';

/// Onglet « Messages » : détection des arnaques par SMS ou lien (à venir).
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            Expanded(
              child: EmptyState(
                icon: Icons.sms_outlined,
                title: 'Repérez les arnaques',
                message:
                    "Collez un SMS ou un lien : l'IA de Sentinel vous dit "
                    "s'il s'agit d'une tentative d'escroquerie.",
                buttonLabel: 'Analyser un message',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
