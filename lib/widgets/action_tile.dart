import 'package:material_ui/material_ui.dart';

import '../models/security_action.dart';
import '../theme/app_colors.dart';

/// Une ligne d'action : icône, titre + description, et points à droite.
class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.action, this.onTap});

  final SecurityAction action;
  final VoidCallback? onTap; // null : ligne non cliquable

  @override
  Widget build(BuildContext context) {
    // InkWell rend la ligne cliquable, avec un effet d'onde au toucher.
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        // Row aligne ses enfants horizontalement, de gauche à droite.
        child: Row(
          children: [
            Icon(action.icon, color: context.colors.bleu),
            const SizedBox(width: 16),
            // Expanded prend toute la place restante au milieu,
            // ce qui pousse les points tout à droite.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.colors.encre,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.secondaire,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '+${action.points}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.colors.zitouna,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
