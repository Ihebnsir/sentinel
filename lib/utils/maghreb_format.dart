// Noms des mois utilisés en Tunisie et au Maghreb.
const _months = [
  'جانفي',
  'فيفري',
  'مارس',
  'أفريل',
  'ماي',
  'جوان',
  'جويلية',
  'أوت',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// Date en arabe du Maghreb, chiffres occidentaux : « 5 سبتمبر 2026 ».
String formatMaghrebDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// Heure sur 24 h, comme en Tunisie : « 14:05 ».
String formatMaghrebTime(DateTime date) =>
    '${date.hour}:${date.minute.toString().padLeft(2, '0')}';

/// Remplace les chiffres arabes-indiens (٠١٢… et ۰۱۲…) par 0123456789.
String westernDigits(String text) => text.replaceAllMapped(
  RegExp('[٠-٩۰-۹]'),
  (m) => '${m[0]!.codeUnitAt(0) & 0xF}',
);
