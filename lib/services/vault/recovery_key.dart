import 'dart:math';

/// Clé de récupération : 28 caractères tirés au hasard parmi 32, soit
/// 28 × 5 = 140 bits (au-dessus des 128 bits demandés).
/// Affichée en 7 groupes de 4 : « K7QM-4XPA-… ».
class RecoveryKey {
  RecoveryKey._();

  /// Base32 sans caractères ambigus : ni 0/O, ni 1/I.
  static const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  static const length = 28;
  static const groupLength = 4;
  static const bits = length * 5; // 32 = 2^5 : 5 bits par caractère

  /// Nouvelle clé, déjà mise en forme avec des tirets.
  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    // 32 est une puissance de 2 : nextInt(32) n'a aucun biais.
    final raw = String.fromCharCodes(
      List.generate(length, (_) => alphabet.codeUnitAt(rng.nextInt(32))),
    );
    return format(raw);
  }

  /// « K7QM4XPA… » → « K7QM-4XPA-… ».
  static String format(String normalized) => [
    for (var i = 0; i < normalized.length; i += groupLength)
      normalized.substring(i, min(i + groupLength, normalized.length)),
  ].join('-');

  /// Saisie tolérante : tirets, espaces et minuscules acceptés.
  /// Renvoie la forme sans tirets, ou null si ce n'est pas une clé valide.
  static String? normalize(String input) {
    final cleaned = input.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.length != length) return null;
    for (final char in cleaned.split('')) {
      if (!alphabet.contains(char)) return null;
    }
    return cleaned;
  }

  /// Les 4 derniers caractères, à retaper pour prouver qu'on l'a notée.
  static String lastGroup(String key) {
    final normalized = key.replaceAll('-', '');
    return normalized.substring(normalized.length - groupLength);
  }
}
