import 'package:material_ui/material_ui.dart';

/// Les écrans des paramètres Android que l'app sait ouvrir.
/// Le nom (ex : « security ») est envoyé tel quel à Android.
enum SettingsTarget { security, biometric, developer, update }

/// Une action que l'utilisateur peut faire pour améliorer son score.
/// C'est un « modèle » : il contient seulement des données, pas d'affichage.
class SecurityAction {
  const SecurityAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.points,
    this.settingsTarget,
  });

  final IconData icon; // icône affichée à gauche
  final String title; // titre court
  final String description; // explication en une phrase
  final int points; // points gagnés si l'action est faite
  final SettingsTarget? settingsTarget; // null : pas de réglage à ouvrir
}
