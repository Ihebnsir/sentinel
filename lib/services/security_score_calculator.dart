import 'package:material_ui/material_ui.dart';

import '../models/device_security_status.dart';
import '../models/security_action.dart';

/// Résultat de l'audit : le score sur 100 et ce qu'il reste à corriger.
class SecurityReport {
  const SecurityReport({required this.score, required this.actions});

  final int score;
  final List<SecurityAction> actions; // vide si tout est bon
}

/// Un correctif de sécurité plus vieux que ça est considéré comme dépassé.
const maxSecurityPatchAgeDays = 90;

/// Calcule le score à partir de l'état du téléphone.
/// Fonction « pure » : mêmes entrées = même résultat, aucun appel à Android.
/// La date du jour est un paramètre pour pouvoir la fixer dans les tests.
SecurityReport calculateSecurityScore(
  DeviceSecurityStatus status,
  DateTime today,
) {
  var score = 0;
  final actions = <SecurityAction>[];

  // Ajoute les points si la vérification passe, sinon l'action à faire.
  void check(bool passed, SecurityAction action) {
    if (passed) {
      score += action.points;
    } else {
      actions.add(action);
    }
  }

  check(
    status.screenLock,
    const SecurityAction(
      icon: Icons.lock_outline,
      title: "Configurer un verrouillage d'écran",
      description:
          "Un code ou un schéma empêche l'accès à vos données "
          'si le téléphone est perdu',
      points: 25,
      settingsTarget: SettingsTarget.security,
    ),
  );

  // Pas de bouton paramètres : le root ne se retire pas depuis les réglages.
  check(
    !status.rooted,
    const SecurityAction(
      icon: Icons.warning_amber_outlined,
      title: 'Votre téléphone semble rooté',
      description:
          "Le root contourne les protections d'Android. "
          'Il ne se retire pas depuis les paramètres',
      points: 20,
    ),
  );

  final patch = status.securityPatch;
  check(
    patch != null && _ageInDays(patch, today) < maxSecurityPatchAgeDays,
    SecurityAction(
      icon: Icons.system_update_outlined,
      title: 'Installer la mise à jour de sécurité',
      description: patch == null
          ? 'La date du dernier correctif est inconnue'
          : 'Le dernier correctif date de plus de 3 mois',
      points: 20,
      settingsTarget: SettingsTarget.update,
    ),
  );

  check(
    status.biometricEnrolled,
    const SecurityAction(
      icon: Icons.fingerprint,
      title: 'Activer le déverrouillage biométrique',
      description: 'Empreinte ou visage pour ouvrir le téléphone',
      points: 10,
      settingsTarget: SettingsTarget.biometric,
    ),
  );

  check(
    !status.developerOptions,
    const SecurityAction(
      icon: Icons.developer_mode_outlined,
      title: 'Désactiver les options pour les développeurs',
      description: 'Elles donnent accès à des réglages sensibles du système',
      points: 10,
      settingsTarget: SettingsTarget.developer,
    ),
  );

  check(
    !status.usbDebugging,
    const SecurityAction(
      icon: Icons.usb,
      title: 'Désactiver le débogage USB',
      description: 'Un ordinateur branché pourrait accéder à vos données',
      points: 10,
      settingsTarget: SettingsTarget.developer,
    ),
  );

  check(
    status.encrypted,
    const SecurityAction(
      icon: Icons.enhanced_encryption_outlined,
      title: 'Chiffrer le stockage',
      description: 'Vos fichiers restent illisibles sans votre code',
      points: 5,
      settingsTarget: SettingsTarget.security,
    ),
  );

  return SecurityReport(score: score, actions: actions);
}

/// Nombre de jours entre deux dates, en ignorant les heures.
int _ageInDays(DateTime from, DateTime to) {
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);
  return end.difference(start).inDays;
}
