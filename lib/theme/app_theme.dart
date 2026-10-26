import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Le thème visuel de l'app (couleurs de base et police), clair ou nuit.
class AppTheme {
  AppTheme._();

  /// Police Readex Pro, embarquée dans l'app (voir pubspec.yaml).
  static const fontFamily = 'ReadexPro';

  /// Thème clair, utilisé par SentinelApp dans main.dart.
  static ThemeData get light => _build(AppColors.light, Brightness.light);

  /// Thème sombre « nuit », assorti à l'icône.
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    // Flutter génère toute une palette harmonieuse à partir du bleu ;
    // les couleurs principales sont ensuite celles de Sentinel.
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.light.bleu,
      brightness: brightness,
    );
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.chaux,
      colorScheme: brightness == Brightness.light
          ? scheme
          : scheme.copyWith(
              primary: c.bleu,
              onPrimary: c.surCouleur,
              surface: c.chaux,
              onSurface: c.encre,
              error: c.rommen,
              outlineVariant: c.ligne,
            ),
      // Police Readex Pro pour tous les textes de l'app.
      fontFamily: fontFamily,
      extensions: [c],
      navigationBarTheme: _navigationBar(c),
      // Texte lisible sur le bleu plein (blanc le jour, bleu nuit le soir).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.bleu,
          foregroundColor: c.surCouleur,
        ),
      ),
      dividerTheme: DividerThemeData(color: c.ligne),
      dialogTheme: DialogThemeData(backgroundColor: c.chaux),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.chaux),
    );
  }

  /// Style de la barre de navigation du bas.
  static NavigationBarThemeData _navigationBar(AppColors c) =>
      NavigationBarThemeData(
        backgroundColor: c.chaux,
        indicatorColor: c.bleu.withValues(alpha: 0.12),
        // Pas d'ombre ni de teinte ajoutée par Material 3.
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        // resolveWith choisit le style selon l'état (actif ou non) :
        // bleu si l'onglet est actif, texte secondaire sinon (AA).
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: _navColor(c, states)),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            color: _navColor(c, states),
          ),
        ),
      );

  static Color _navColor(AppColors c, Set<WidgetState> states) =>
      states.contains(WidgetState.selected) ? c.bleu : c.secondaire;
}
