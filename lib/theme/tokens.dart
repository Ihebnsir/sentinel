import 'package:material_ui/material_ui.dart';

// Jetons du système de design : les seules valeurs de mise en page
// autorisées dans les écrans. Voir docs/DESIGN.md.

/// Espacements, sur une échelle de 4.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Grand vide (états vides, messages centrés).
  static const double xxxl = 48;

  /// Marge gauche et droite des pages.
  static const double page = xl;

  /// Marge haute des pages (sous la barre d'état).
  static const double pageTop = xl;

  /// Padding vertical d'une ligne de liste.
  static const double row = lg;

  /// Écart entre l'icône d'une ligne et son texte.
  static const double rowGap = lg;

  /// Écart entre deux sections d'une page.
  static const double section = xxl;
}

/// Rayons des coins.
abstract final class AppRadius {
  /// Champs de saisie, petites surfaces.
  static const double sm = 8;

  /// Badges et surfaces teintées.
  static const double md = 12;

  /// Pilule (boutons, badges ronds).
  static const double pill = 999;

  static const BorderRadius field = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius badge = BorderRadius.all(Radius.circular(pill));
}

/// Tailles de texte (dp, multipliées par la taille de police du système).
abstract final class AppText {
  static const double legende = 12; // barre de navigation, mentions
  static const double detail = 13; // sous-titres, notes
  static const double corps = 15; // texte courant
  static const double intitule = 16; // titre d'une ligne, salutation
  static const double section = 18; // en-tête de section
  static const double accroche = 20; // titre d'un état vide, d'un bloc
  static const double titreSecondaire = 24; // titre d'un écran poussé
  static const double titre = 28; // titre d'un onglet, verdict
  static const double score = 72; // chiffre de l'arche

  /// Interligne du texte long (politique, explications).
  static const double interligne = 1.45;
}

/// Tailles d'icônes et de cibles.
abstract final class AppSize {
  static const double iconSmall = 18;
  static const double icon = 24;
  static const double iconLarge = 28;
  static const double verdictArch = 56; // petite arche d'un verdict
  static const double appIconSmall = 32;
  static const double appIcon = 40;
  static const double appIconLarge = 64;
  static const double tap = 48; // cible tactile minimale
  static const double iconHero = 48; // grande icône en tête d'écran
  static const double archHero = 72; // arche de la présentation
  static const double illustration = 120; // dessin d'un état vide
  static const double line = 1; // séparateur fin
  static const double progress = 2; // barre de chargement fine
  static const double textColumn = 320; // largeur max d'un texte centré
}

/// Durées et courbes des animations. Toujours via [AppMotion.of] pour
/// respecter le réglage « Supprimer les animations » d'Android.
abstract final class AppMotion {
  static const Duration rapide = Duration(milliseconds: 150); // appui
  static const Duration moyen = Duration(milliseconds: 250); // onglets
  static const Duration lent = Duration(milliseconds: 350); // écrans
  static const Duration score = Duration(milliseconds: 1200); // arche

  static const Curve entree = Curves.easeOutCubic;
  static const Curve sortie = Curves.easeInCubic;

  /// Animations désactivées dans les réglages d'accessibilité ?
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], ou zéro si l'utilisateur a supprimé les animations.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
