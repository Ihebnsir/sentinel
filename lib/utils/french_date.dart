const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Formate une date en français, ex : « 5 août 2026 » ou « 1er mars 2026 ».
String formatFrenchDate(DateTime date) {
  final day = date.day == 1 ? '1er' : '${date.day}';
  return '$day ${_months[date.month - 1]} ${date.year}';
}
