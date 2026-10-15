import 'dart:math';

/// Réglages du générateur de mots de passe.
class GeneratorOptions {
  const GeneratorOptions({
    this.length = 20,
    this.uppercase = true,
    this.digits = true,
    this.symbols = true,
  });

  static const minLength = 12;
  static const maxLength = 64;

  final int length;
  final bool uppercase;
  final bool digits;
  final bool symbols;

  GeneratorOptions copyWith({
    int? length,
    bool? uppercase,
    bool? digits,
    bool? symbols,
  }) {
    return GeneratorOptions(
      length: length ?? this.length,
      uppercase: uppercase ?? this.uppercase,
      digits: digits ?? this.digits,
      symbols: symbols ?? this.symbols,
    );
  }
}

const lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
const uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const digitChars = '0123456789';
const symbolChars = r'!#$%&*+-=?@^_~.,:;()[]{}';

/// Mot de passe aléatoire (générateur cryptographique du système).
/// Les minuscules sont toujours présentes ; chaque type coché apparaît
/// au moins une fois.
String generatePassword(GeneratorOptions options, {Random? random}) {
  final rng = random ?? Random.secure();
  final length = options.length.clamp(
    GeneratorOptions.minLength,
    GeneratorOptions.maxLength,
  );
  final sets = [
    lowercaseChars,
    if (options.uppercase) uppercaseChars,
    if (options.digits) digitChars,
    if (options.symbols) symbolChars,
  ];
  final all = sets.join();

  String pick(String chars) => chars[rng.nextInt(chars.length)];

  final chars = [
    for (final set in sets) pick(set), // un de chaque type
    for (var i = sets.length; i < length; i++) pick(all),
  ];
  // Mélange (Fisher-Yates) pour que les caractères imposés ne soient
  // pas toujours au début.
  for (var i = chars.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = chars[i];
    chars[i] = chars[j];
    chars[j] = tmp;
  }
  return chars.join();
}
