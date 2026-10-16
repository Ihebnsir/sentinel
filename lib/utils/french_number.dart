/// Formate un nombre à la française : « 3 861 », « 1 234 567 ».
/// Espace insécable : le nombre n'est jamais coupé en fin de ligne.
String formatFrenchNumber(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    // Une espace avant chaque groupe de 3 chiffres (sauf au début).
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
