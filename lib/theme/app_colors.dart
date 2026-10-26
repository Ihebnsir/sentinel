import 'package:material_ui/material_ui.dart';

/// Les couleurs de l'app, en deux palettes : claire et nuit (comme l'icône).
/// Les écrans les lisent avec `context.colors.encre`, jamais en dur :
/// le thème choisi (clair, sombre ou celui du téléphone) s'applique partout.
/// Les noms restent ceux du thème clair : chaux = fond, encre = texte.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.chaux,
    required this.bleu,
    required this.encre,
    required this.zitouna,
    required this.ocre,
    required this.rommen,
    required this.ligne,
    required this.secondaire,
    required this.discret,
    required this.surCouleur,
  });

  final Color chaux; // fond
  final Color bleu; // couleur principale (boutons, liens, sécurité correcte)
  final Color encre; // texte
  final Color zitouna; // vert (points gagnés, rien de suspect)
  final Color ocre; // avertissement
  final Color rommen; // danger
  final Color ligne; // séparateurs fins
  final Color secondaire; // texte atténué (détails, sous-titres)
  final Color discret; // texte très discret (notes, indications)
  final Color surCouleur; // texte posé sur bleu ou rouge plein

  /// Thème clair : les couleurs d'origine de Sentinel.
  static const light = AppColors(
    chaux: Color(0xFFF5F7F8),
    bleu: Color(0xFF1F5FA8),
    encre: Color(0xFF14213D),
    zitouna: Color(0xFF5B7A3A),
    ocre: Color(0xFFE0A526),
    rommen: Color(0xFFC2263A),
    ligne: Color(0xFFE3E8EC),
    // Encre à 64 % (60 % avant le thème sombre : 4,2:1, sous le seuil AA).
    secondaire: Color(0xA314213D),
    discret: Color(0x7314213D), // encre à 45 %
    surCouleur: Color(0xFFFFFFFF),
  );

  /// Thème nuit : fond bleu nuit de l'icône, couleurs éclaircies pour
  /// rester lisibles (contraste WCAG AA, vérifié par test/theme_test.dart).
  static const dark = AppColors(
    chaux: Color(0xFF0E1A33),
    bleu: Color(0xFF6EA8FF),
    encre: Color(0xFFE8EEF7),
    zitouna: Color(0xFF8CC063),
    ocre: Color(0xFFF2B84B),
    rommen: Color(0xFFFF7A88),
    ligne: Color(0xFF25365C),
    secondaire: Color(0xB3E8EEF7), // texte à 70 %
    discret: Color(0x94E8EEF7), // texte à 58 %
    surCouleur: Color(0xFF0E1A33), // fond nuit sur couleur claire
  );

  /// Texte le plus lisible sur un fond plein [fill] : [surCouleur] ou
  /// [encre], celui qui a le meilleur contraste WCAG.
  Color textOn(Color fill) =>
      contrastRatio(surCouleur, fill) >= contrastRatio(encre, fill)
      ? surCouleur
      : encre;

  /// Couleurs du thème courant (clair si le thème n'en déclare pas).
  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  AppColors copyWith({
    Color? chaux,
    Color? bleu,
    Color? encre,
    Color? zitouna,
    Color? ocre,
    Color? rommen,
    Color? ligne,
    Color? secondaire,
    Color? discret,
    Color? surCouleur,
  }) => AppColors(
    chaux: chaux ?? this.chaux,
    bleu: bleu ?? this.bleu,
    encre: encre ?? this.encre,
    zitouna: zitouna ?? this.zitouna,
    ocre: ocre ?? this.ocre,
    rommen: rommen ?? this.rommen,
    ligne: ligne ?? this.ligne,
    secondaire: secondaire ?? this.secondaire,
    discret: discret ?? this.discret,
    surCouleur: surCouleur ?? this.surCouleur,
  );

  // Passage en douceur d'un thème à l'autre.
  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      chaux: mix(chaux, other.chaux),
      bleu: mix(bleu, other.bleu),
      encre: mix(encre, other.encre),
      zitouna: mix(zitouna, other.zitouna),
      ocre: mix(ocre, other.ocre),
      rommen: mix(rommen, other.rommen),
      ligne: mix(ligne, other.ligne),
      secondaire: mix(secondaire, other.secondaire),
      discret: mix(discret, other.discret),
      surCouleur: mix(surCouleur, other.surCouleur),
    );
  }
}

/// Rapport de contraste WCAG 2.x entre deux couleurs opaques (1 à 21).
/// AA : 4,5 pour le texte courant, 3 pour le grand texte et les icônes.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (light, dark) = la > lb ? (la, lb) : (lb, la);
  return (light + 0.05) / (dark + 0.05);
}

/// Raccourci : `context.colors.bleu`.
extension AppColorsContext on BuildContext {
  AppColors get colors => AppColors.of(this);
}
