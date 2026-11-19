import 'package:material_ui/material_ui.dart';

import '../models/security_action.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Une ligne d'action : icône, titre + description, et points à droite.
class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.action, this.onTap});

  final SecurityAction action;
  final VoidCallback? onTap; // null : ligne non cliquable

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListRow(
      icon: action.icon,
      title: action.title,
      subtitle: action.description,
      onTap: onTap,
      // Gauche-droite forcé : sinon l'arabe affiche « 10+ ».
      trailing: Text(
        '+${action.points}',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: AppText.corps,
          fontWeight: FontWeight.w600,
          color: c.zitouna,
        ),
      ),
    );
  }
}
