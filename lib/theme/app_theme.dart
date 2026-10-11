import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Le thème visuel de l'app (couleurs de base et police).
class AppTheme {
  AppTheme._();

  /// Ligne fine au-dessus de la barre de navigation (utilisée par MainShell).
  static const navigationBarBorder = BorderSide(color: AppColors.ligne);

  /// Thème clair, utilisé par SentinelApp dans main.dart.
  static ThemeData get light => ThemeData(
        scaffoldBackgroundColor: AppColors.chaux,
        // Flutter génère toute une palette harmonieuse à partir du bleu.
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.bleu),
        // Police Readex Pro pour tous les textes de l'app.
        textTheme: GoogleFonts.readexProTextTheme(),
        navigationBarTheme: _navigationBar,
      );

  /// Style de la barre de navigation du bas.
  static NavigationBarThemeData get _navigationBar => NavigationBarThemeData(
        backgroundColor: AppColors.chaux,
        indicatorColor: AppColors.bleu.withValues(alpha: 0.12),
        // Pas d'ombre ni de teinte ajoutée par Material 3.
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        // resolveWith choisit le style selon l'état (actif ou non).
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: _navColor(states)),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.readexPro(
            fontSize: 12,
            color: _navColor(states),
          ),
        ),
      );

  /// Bleu si l'onglet est actif, encre à 50 % sinon.
  static Color _navColor(Set<WidgetState> states) =>
      states.contains(WidgetState.selected)
          ? AppColors.bleu
          : AppColors.encre.withValues(alpha: 0.5);
}
