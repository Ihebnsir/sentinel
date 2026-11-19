import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'tokens.dart';

/// Le thème visuel de l'app (couleurs de base et police), clair ou nuit.
/// Les styles des boutons, interrupteurs, dialogues et transitions sont
/// définis ici une fois : les écrans n'ont pas à les répéter.
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
    // les couleurs principales sont ensuite celles de Sentinel (un seul
    // bleu à l'écran, même pour les interrupteurs).
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.light.bleu,
          brightness: brightness,
        ).copyWith(
          primary: c.bleu,
          onPrimary: c.surCouleur,
          surface: c.chaux,
          onSurface: c.encre,
          error: c.rommen,
          outlineVariant: c.ligne,
          surfaceTint: Colors.transparent,
        );
    WidgetStateProperty<T?> selected<T>(T on, [T? off]) =>
        WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? on : off,
        );
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.chaux,
      colorScheme: scheme,
      // Police Readex Pro pour tous les textes de l'app.
      fontFamily: fontFamily,
      extensions: [c],
      navigationBarTheme: _navigationBar(c),
      appBarTheme: AppBarTheme(
        backgroundColor: c.chaux,
        foregroundColor: c.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      // Texte lisible sur le bleu plein (blanc le jour, bleu nuit le soir).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.bleu,
          foregroundColor: c.surCouleur,
          disabledBackgroundColor: c.ligne,
          disabledForegroundColor: c.discret,
          minimumSize: const Size(AppSize.tap, AppSize.tap),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          textStyle: _buttonText,
        ),
      ),
      // Contour bien visible, même inactif (bouton « Ouvrir quand même »).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: c.bleu,
              disabledForegroundColor: c.discret,
              minimumSize: const Size(AppSize.tap, AppSize.tap),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              textStyle: _buttonText,
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.disabled)
                      ? c.discret
                      : c.bleu,
                ),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.bleu,
          disabledForegroundColor: c.discret,
          minimumSize: const Size(AppSize.tap, AppSize.tap),
          textStyle: _buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppSize.tap, AppSize.tap),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: selected<Color>(c.surCouleur),
        trackColor: selected<Color>(c.bleu),
        trackOutlineColor: selected<Color>(c.bleu),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: selected<Color>(c.bleu),
        checkColor: WidgetStatePropertyAll(c.surCouleur),
      ),
      radioTheme: RadioThemeData(
        fillColor: selected<Color>(c.bleu, c.secondaire),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.bleu,
        linearTrackColor: c.ligne,
        circularTrackColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: c.ligne,
        space: AppSize.line,
        thickness: AppSize.line,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.chaux,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md + AppSpace.sm),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: AppText.accroche,
          fontWeight: FontWeight.w600,
          color: c.encre,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: AppText.corps,
          height: AppText.interligne,
          color: c.secondaire,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.chaux,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      // Message en bas : encre sur chaux inversés, coins arrondis.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.encre,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: AppText.corps,
          color: c.chaux,
        ),
        actionTextColor: c.chaux,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SoftPageTransitionsBuilder(),
          TargetPlatform.windows: SoftPageTransitionsBuilder(),
          TargetPlatform.iOS: SoftPageTransitionsBuilder(),
        },
      ),
    );
  }

  static const _buttonText = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppText.corps,
    fontWeight: FontWeight.w600,
  );

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
            fontSize: AppText.legende,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.normal,
            color: _navColor(c, states),
          ),
        ),
      );

  static Color _navColor(AppColors c, Set<WidgetState> states) =>
      states.contains(WidgetState.selected) ? c.bleu : c.secondaire;
}

/// Transition douce entre écrans : fondu et léger glissement vers le haut.
/// Aucune animation si « Supprimer les animations » est actif.
class SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const SoftPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.lent;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.entree,
      reverseCurve: AppMotion.sortie,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
