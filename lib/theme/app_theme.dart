import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Le thème visuel de l'app (couleurs de base et police).
class AppTheme {
  AppTheme._();

  /// Thème clair, utilisé par SentinelApp dans main.dart.
  static ThemeData get light => ThemeData(
        scaffoldBackgroundColor: AppColors.chaux,
        // Flutter génère toute une palette harmonieuse à partir du bleu.
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.bleu),
        // Police Readex Pro pour tous les textes de l'app.
        textTheme: GoogleFonts.readexProTextTheme(),
      );
}
