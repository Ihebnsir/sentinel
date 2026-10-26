import 'package:material_ui/material_ui.dart';

import '../models/installed_app.dart';
import '../theme/app_colors.dart';

/// L'icône d'une app, aux coins légèrement arrondis.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.app, required this.size});

  final InstalledApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = app.icon;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: icon == null
          // Pas d'icône reçue : un carré neutre avec un pictogramme.
          ? Container(
              width: size,
              height: size,
              color: context.colors.ligne,
              child: Icon(
                Icons.android,
                size: size * 0.6,
                color: context.colors.encre.withValues(alpha: 0.4),
              ),
            )
          // gaplessPlayback : pas de clignotement quand la liste se recharge.
          : Image.memory(
              icon,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
    );
  }
}
