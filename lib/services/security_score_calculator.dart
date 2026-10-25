import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
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
/// [l] : langue des titres et des explications.
SecurityReport calculateSecurityScore(
  AppLocalizations l,
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
    SecurityAction(
      icon: Icons.lock_outline,
      title: l.scoreLockTitle,
      description: l.scoreLockDesc,
      points: 25,
      settingsTarget: SettingsTarget.security,
    ),
  );

  // Pas de bouton paramètres : le root ne se retire pas depuis les réglages.
  check(
    !status.rooted,
    SecurityAction(
      icon: Icons.warning_amber_outlined,
      title: l.scoreRootTitle,
      description: l.scoreRootDesc,
      points: 20,
    ),
  );

  final patch = status.securityPatch;
  check(
    patch != null && _ageInDays(patch, today) < maxSecurityPatchAgeDays,
    SecurityAction(
      icon: Icons.system_update_outlined,
      title: l.scoreUpdateTitle,
      description: patch == null ? l.scoreUpdateUnknown : l.scoreUpdateOld,
      points: 20,
      settingsTarget: SettingsTarget.update,
    ),
  );

  check(
    status.biometricEnrolled,
    SecurityAction(
      icon: Icons.fingerprint,
      title: l.scoreBiometricTitle,
      description: l.scoreBiometricDesc,
      points: 10,
      settingsTarget: SettingsTarget.biometric,
    ),
  );

  check(
    !status.developerOptions,
    SecurityAction(
      icon: Icons.developer_mode_outlined,
      title: l.scoreDevOptionsTitle,
      description: l.scoreDevOptionsDesc,
      points: 10,
      settingsTarget: SettingsTarget.developer,
    ),
  );

  check(
    !status.usbDebugging,
    SecurityAction(
      icon: Icons.usb,
      title: l.scoreUsbTitle,
      description: l.scoreUsbDesc,
      points: 10,
      settingsTarget: SettingsTarget.developer,
    ),
  );

  check(
    status.encrypted,
    SecurityAction(
      icon: Icons.enhanced_encryption_outlined,
      title: l.scoreEncryptTitle,
      description: l.scoreEncryptDesc,
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
