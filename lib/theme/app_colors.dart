import 'package:material_ui/material_ui.dart';

/// Toutes les couleurs de l'app, réunies au même endroit.
/// Pour changer une couleur partout, il suffit de la modifier ici.
class AppColors {
  // Constructeur privé : on n'a jamais besoin de créer un objet AppColors,
  // on utilise directement AppColors.bleu, AppColors.encre, etc.
  AppColors._();

  static const chaux = Color(0xFFF5F7F8); // fond clair
  static const bleu = Color(0xFF1F5FA8); // couleur principale
  static const encre = Color(0xFF14213D); // texte
  static const zitouna = Color(0xFF5B7A3A); // vert (points gagnés)
  static const ocre = Color(0xFFE0A526); // avertissement
  static const rommen = Color(0xFFC2263A); // danger
  static const ligne = Color(0xFFE3E8EC); // séparateurs fins
}
