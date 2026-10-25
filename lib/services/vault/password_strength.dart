import 'dart:math';

import '../../l10n/l10n.dart';

/// Force d'un mot de passe, du plus faible au plus fort.
enum PasswordStrength {
  faible,
  moyen,
  fort;

  /// En minuscules, pour « Force : moyen ».
  String label(AppLocalizations l) => switch (this) {
    faible => l.strengthWeak,
    moyen => l.strengthMedium,
    fort => l.strengthStrong,
  };
}

/// Longueur minimale du mot de passe maître.
const masterPasswordMinLength = 12;

// Morceaux trop connus : ils ne comptent que pour un caractère.
const _common = [
  'password',
  'motdepasse',
  'azerty',
  'qwerty',
  '123456',
  'abcdef',
  'soleil',
  'bonjour',
  'iloveyou',
  'admin',
  'sentinel',
];

/// Estimation simple de l'entropie, en bits : longueur × log2(nombre de
/// caractères possibles). Les répétitions et les mots trop connus sont
/// pénalisés. Ce n'est qu'une estimation, pas une garantie.
double estimateEntropyBits(String password) {
  if (password.isEmpty) return 0;
  var pool = 0;
  if (password.contains(RegExp('[a-z]'))) pool += 26;
  if (password.contains(RegExp('[A-Z]'))) pool += 26;
  if (password.contains(RegExp('[0-9]'))) pool += 10;
  if (password.contains(RegExp(r'[!-/:-@\[-`{-~ ]'))) pool += 33;
  if (password.runes.any((r) => r > 126)) pool += 100; // accents, emoji…

  var length = password.runes.length;
  // « aaaaaaaa » ou « abababab » : peu de caractères différents.
  final distinct = password.runes.toSet().length;
  length = min(length, distinct * 2);

  final lower = password.toLowerCase();
  for (final word in _common) {
    if (lower.contains(word)) length -= word.length - 1;
  }
  return max(0, length) * log(max(pool, 1)) / ln2;
}

PasswordStrength passwordStrength(String password) {
  final bits = estimateEntropyBits(password);
  if (bits >= 70) return PasswordStrength.fort;
  if (bits >= 50) return PasswordStrength.moyen;
  return PasswordStrength.faible;
}

/// Le mot de passe maître est-il acceptable ? (12 caractères, « moyen »)
bool isMasterPasswordAcceptable(String password) =>
    password.runes.length >= masterPasswordMinLength &&
    passwordStrength(password) != PasswordStrength.faible;
