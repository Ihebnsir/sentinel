/// Indicatifs téléphoniques internationaux. Calcul pur, sans Flutter.
library;

/// D'où vient un numéro, vu de Tunisie.
enum PhoneZone {
  home, // +216 : Tunisie
  usual, // pays proches ou de la diaspora (France, Algérie…)
  unusual, // autre pays : rare pour un QR reçu en Tunisie
  special, // réseaux internationaux ou satellites, souvent surtaxés
  unknown, // pas d'indicatif (numéro local) ou indicatif inconnu
}

/// Indicatif de la Tunisie : celui que Sentinel attend par défaut.
const homeCallingCode = '216';

/// Pays proches ou de la diaspora tunisienne : étrangers mais courants.
const usualCallingCodes = {
  '213', '212', '218', '20', // Algérie, Maroc, Libye, Égypte
  '33', '39', '49', '32', '41', '31', '34', '43', '44', '1', // Europe, USA
  '46', '47', '45', '352', '351', '90', // Scandinavie, Lux., Portugal, Turquie
  '974', '966', '971', '965', '973', '968', // Golfe
};

/// Indicatifs « non géographiques » : satellites, réseaux internationaux,
/// numéros premium. Très utilisés pour les appels surtaxés.
const specialCallingCodes = {'870', '881', '882', '883', '888', '979', '808'};

/// Tous les indicatifs attribués (UIT), pour couper le numéro au bon endroit.
const _callingCodes = {
  '1', '7', //
  '20', '27', '30', '31', '32', '33', '34', '36', '39', '40', '41', '43',
  '44', '45', '46', '47', '48', '49', '51', '52', '53', '54', '55', '56',
  '57', '58', '60', '61', '62', '63', '64', '65', '66', '81', '82', '84',
  '86', '90', '91', '92', '93', '94', '95', '98', //
  '211', '212', '213', '216', '218', '220', '221', '222', '223', '224',
  '225', '226', '227', '228', '229', '230', '231', '232', '233', '234',
  '235', '236', '237', '238', '239', '240', '241', '242', '243', '244',
  '245', '246', '247', '248', '249', '250', '251', '252', '253', '254',
  '255', '256', '257', '258', '260', '261', '262', '263', '264', '265',
  '266', '267', '268', '269', '290', '291', '297', '298', '299', '350',
  '351', '352', '353', '354', '355', '356', '357', '358', '359', '370',
  '371', '372', '373', '374', '375', '376', '377', '378', '380', '381',
  '382', '383', '385', '386', '387', '389', '420', '421', '423', '500',
  '501', '502', '503', '504', '505', '506', '507', '508', '509', '590',
  '591', '592', '593', '594', '595', '596', '597', '598', '599', '670',
  '672', '673', '674', '675', '676', '677', '678', '679', '680', '681',
  '682', '683', '685', '686', '687', '688', '689', '690', '691', '692',
  '800', '808', '850', '852', '853', '855', '856', '870', '878', '880',
  '881', '882', '883', '886', '888', '960', '961', '962', '963', '964',
  '965', '966', '967', '968', '970', '971', '972', '973', '974', '975',
  '976', '977', '979', '992', '993', '994', '995', '996', '998',
};

/// Un numéro découpé : indicatif (sans « + ») et reste du numéro.
class PhoneInfo {
  const PhoneInfo({
    required this.number,
    required this.countryCode,
    required this.national,
    required this.zone,
  });

  /// Le numéro nettoyé, ex : « +21698123456 » ou « 71123456 ».
  final String number;

  /// ex : « 216 », null si le numéro n'a pas d'indicatif.
  final String? countryCode;

  /// Le reste du numéro, ex : « 98123456 ».
  final String national;

  final PhoneZone zone;

  bool get isForeign =>
      zone == PhoneZone.usual ||
      zone == PhoneZone.unusual ||
      zone == PhoneZone.special;
}

/// Découpe [input]. [international] : le numéro est forcément au format
/// international, même sans « + » (wa.me, Viber). null si pas un numéro.
PhoneInfo? parsePhone(String input, {bool international = false}) {
  // Espaces, tirets, points, parenthèses : seulement de la mise en forme.
  var text = input.trim().replaceAll(RegExp(r'[\s().\-]'), '');
  if (text.startsWith('00')) text = '+${text.substring(2)}';
  final plus = text.startsWith('+');
  final digits = plus ? text.substring(1) : text;
  if (digits.length < 3 || digits.length > 15) return null;
  if (!RegExp(r'^\d+$').hasMatch(digits)) return null;

  if (!plus && !international) {
    return PhoneInfo(
      number: digits,
      countryCode: null,
      national: digits,
      zone: PhoneZone.unknown,
    );
  }
  for (final length in [3, 2, 1]) {
    if (digits.length <= length) continue;
    final code = digits.substring(0, length);
    if (!_callingCodes.contains(code)) continue;
    return PhoneInfo(
      number: '+$digits',
      countryCode: code,
      national: digits.substring(length),
      zone: zoneOf(code),
    );
  }
  return PhoneInfo(
    number: '+$digits',
    countryCode: null,
    national: digits,
    zone: PhoneZone.unknown,
  );
}

/// Zone d'un indicatif, vue de Tunisie.
PhoneZone zoneOf(String code) {
  if (code == homeCallingCode) return PhoneZone.home;
  if (specialCallingCodes.contains(code)) return PhoneZone.special;
  if (usualCallingCodes.contains(code)) return PhoneZone.usual;
  return PhoneZone.unusual;
}
