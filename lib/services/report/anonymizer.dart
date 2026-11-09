/// Anonymisation d'un signalement, AVANT l'aperçu et l'envoi.
///
/// Traduction ligne à ligne de backend/app/anonymize.py : même entrée,
/// même sortie (test/report_anonymizer_parity_test.dart lit les cas de
/// backend/tests/fixtures/anonymize_cases.json). Toute règle changée ici
/// doit l'être aussi en Python, avec la même version.
///
/// RegExp en mode `unicode` : un emoji compte pour un caractère et la casse
/// suit le pliage Unicode, comme le module `re` de Python.
library;

/// Même numéro que ANONYMIZER_VERSION côté serveur.
const anonymizerVersion = 1;

// Marqueurs : sans chiffre ni « @ », jamais repris par une règle suivante.
const _tel = '[TEL]';
const _email = '[EMAIL]';
const _iban = '[IBAN]';
const _card = '[CARTE]';
const _code = '[CODE]';
const _ip = '[IP]';
const _user = '[USER]';
const _path = '[CHEMIN]';

// Un chiffre : occidental ou arabe-indien.
const _d = r'[0-9٠-٩۰-۹]';
// Séparateurs d'un numéro (espaces insécables compris).
const _sep = r'[   .\-]';
// Espaces au sens de Python (str.isspace) : \s de Dart diffère un peu.
const _space =
    r'\t\n\u000B\f\r\u001C-\u001F \u0085   - '
    r'    　';

RegExp _re(String pattern, {bool ignoreCase = false, bool dotAll = false}) =>
    RegExp(
      pattern,
      unicode: true,
      caseSensitive: !ignoreCase,
      dotAll: dotAll,
    );

// --- Liens -----------------------------------------------------------------

const _urlChars = '[^$_space<>"«»]';
const _host =
    r'(?:[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,24}';
final _url = _re(
  // Avec schéma, ou commençant par www.
  '(?:[Hh][Tt][Tt][Pp][Ss]?://|[Ww][Ww][Ww]\\.)$_urlChars+'
  // Ou domaine nu suivi d'un chemin : « poste-tn.xyz/suivi ».
  '|(?<![A-Za-z0-9@._\\-])$_host/$_urlChars*',
);
// Ponctuation de fin de phrase, laissée hors du lien.
const _trailing = '.,;:!?)]}\'"،؛؟…';
final _urlParts = _re(
  r'^(?<scheme>[A-Za-z]+://)?'
  r'(?:(?<userinfo>[^/?#@]*)@)?'
  r'(?<host>\[[^\]]*\]|[^/?#:]*)'
  r'(?<port>:[0-9]{1,5})?'
  r'(?<rest>.*)$',
  dotAll: true,
);

// --- Le reste ----------------------------------------------------------------

final _emailRe = _re(
  r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?'
  r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,24}',
);

// IBAN (majuscules) : pays, 2 chiffres de contrôle, 11 à 30 caractères.
final _ibanRe = _re(
  r'(?<![A-Za-z0-9])[A-Z]{2}[0-9]{2}(?:[ \-]?[A-Z0-9]){11,30}(?![A-Za-z0-9])',
);
// RIB tunisien : 20 chiffres.
final _ribRe = _re('(?<!$_d)$_d(?:$_sep?$_d){19}(?!$_d)');
// Carte bancaire : 13 à 19 chiffres, vérifiés par Luhn.
final _cardRe = _re('(?<!$_d)$_d(?:[ \\-]?$_d){12,18}(?!$_d)');

const _octet = '(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])';
const _ipv4 = '(?<![0-9.])$_octet(?:\\.$_octet){3}(?![0-9]|\\.[0-9])';
const _h = '[0-9A-Fa-f]{1,4}';
const _ipv6 =
    '(?<![0-9A-Fa-f:])(?:'
    '(?:$_h:){7}$_h' // forme complète
    '|(?:$_h:){1,6}:(?:$_h(?::$_h){0,5})?' // avec « :: »
    '|::$_h(?::$_h){0,6}'
    ')(?![0-9A-Fa-f:])';
final _ipRe = _re('$_ipv4|$_ipv6');
final _ipFull = _re('^(?:$_ipv4|$_ipv6)\$');

// International : +XXX ou 00XXX, puis chiffres groupés (8 à 15 au total).
const _d19 = r'[1-9١-٩۱-۹]';
final _phoneIntl = _re(
  '(?<!$_d)\\(?(?:\\+|00)$_d19(?:[ .\\-()]{0,2}$_d){7,14}(?!$_d)',
);
// Tunisien : 8 chiffres commençant par 2 à 9 (98123456, 98 123 456,
// 98 12 34 56), avec ou sans « 216 » collé devant.
const _d29 = r'[2-9٢-٩۲-۹]';
final _phoneTn = _re(
  '(?<!$_d)(?:216$_sep?)?$_d29(?:'
  '$_d{7}'
  '|$_d$_sep$_d{3}$_sep$_d{3}'
  '|$_d$_sep$_d{2}$_sep$_d{2}$_sep$_d{2}'
  ')(?!$_d)',
);
// Local à 10 chiffres commençant par 0 : 0612345678, 06 12 34 56 78.
final _phoneLocal10 = _re(
  '(?<!$_d)[0٠۰]$_d(?:$_sep?$_d{2}){4}(?!$_d)',
);

// Mention : @pseudo (les e-mails sont déjà remplacés).
final _mention = _re(r'(?<![A-Za-z0-9_@.])@[A-Za-z0-9_.]{2,30}(?<![.])');

// Code de vérification : 4 à 8 chiffres près d'un mot-clé (30 caractères).
const _keywords =
    'code|cod|otp|pin|mdp|mot de passe|password|pass|v[ée]rification|verify'
    '|كود|الكود|رمز|الرمز|كلمة السر|كلمة المرور|تحقق|التحقق|رقم سري';
// L'écart ne traverse pas un [CODE] déjà posé (idempotence).
const _gap = r'(?:(?!\[CODE\])[^\n]){0,30}?';
// Mot-clé entier côté gauche : ni dans un mot latin, ni dans [CODE].
const _keyword = '(?<![\\[A-Za-z])(?:$_keywords)';
final _codeAfterKeyword = _re(
  '($_keyword$_gap)(?<!$_d)($_d{4,8})(?!$_d)',
  ignoreCase: true,
);
final _codeBeforeKeyword = _re(
  '(?<!$_d)($_d{4,8})(?!$_d)(?=$_gap$_keyword)',
  ignoreCase: true,
);

final _oneDigit = _re('^$_d\$');

/// Valeurs des chiffres (occidentaux ou arabes-indiens) de [text].
List<int> _digitValues(String text) => [
  for (final rune in text.runes)
    if (_oneDigit.hasMatch(String.fromCharCode(rune))) rune & 0xF,
];

bool luhnValid(List<int> digits) {
  var total = 0;
  var i = 0;
  for (var d in digits.reversed) {
    if (i.isOdd) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    total += d;
    i++;
  }
  return total % 10 == 0;
}

final _asciiDigits = RegExp(r'^[0-9]+$');

/// IBAN tunisien (TN + 22 chiffres) accepté tel quel ; autres : modulo 97.
bool _ibanValid(String candidate) {
  final compact = candidate.replaceAll(RegExp(r'[ \-]'), '').toUpperCase();
  if (compact.startsWith('TN')) {
    return compact.length == 24 && _asciiDigits.hasMatch(compact.substring(2));
  }
  final rearranged = compact.substring(4) + compact.substring(0, 4);
  // Reste de la division par 97, chiffre par chiffre (A=10 … Z=35).
  var rest = 0;
  for (final char in rearranged.split('')) {
    final value = int.parse(char, radix: 36);
    for (final digit in '$value'.split('')) {
      rest = (rest * 10 + int.parse(digit)) % 97;
    }
  }
  return rest == 1;
}

/// Retire les caractères de [chars] aux deux bouts (str.strip de Python).
String _strip(String text, String chars) {
  var start = 0;
  var end = text.length;
  while (start < end && chars.contains(text[start])) {
    start++;
  }
  while (end > start && chars.contains(text[end - 1])) {
    end--;
  }
  return text.substring(start, end);
}

String _anonymizeUrl(String url) {
  final parts = _urlParts.firstMatch(url);
  if (parts == null) return url; // le motif accepte tout
  final host = parts.namedGroup('host')!;
  final out = StringBuffer(parts.namedGroup('scheme') ?? '');
  if (parts.namedGroup('userinfo') != null) out.write('$_user@');
  out.write(_ipFull.hasMatch(_strip(host, '[]')) ? _ip : host);
  out.write(parts.namedGroup('port') ?? '');
  final rest = parts.namedGroup('rest')!;
  out.write(rest == '' || rest == '/' ? rest : '/$_path');
  return out.toString();
}

String _intlPhone(Match match) {
  // « (+216) » : la parenthèse ne reste que si elle n'est pas fermée.
  final value = match[0]!;
  final prefix = value.startsWith('(') && !value.contains(')') ? '(' : '';
  return '$prefix$_tel';
}

/// Texte sans lien : données personnelles remplacées par des marqueurs.
String _anonymizePlain(String text) {
  text = text.replaceAll(_emailRe, _email);
  text = text.replaceAllMapped(
    _ibanRe,
    (m) => _ibanValid(m[0]!) ? _iban : m[0]!,
  );
  text = text.replaceAll(_ribRe, _iban);
  text = text.replaceAllMapped(
    _cardRe,
    (m) => luhnValid(_digitValues(m[0]!)) ? _card : m[0]!,
  );
  text = text.replaceAll(_ipRe, _ip);
  text = text.replaceAllMapped(_phoneIntl, _intlPhone);
  // Téléphones avant les codes : « appelez le 98123456 pour le code ».
  text = text.replaceAll(_phoneLocal10, _tel);
  text = text.replaceAll(_phoneTn, _tel);
  text = text.replaceAll(_mention, _user);
  text = text.replaceAllMapped(_codeAfterKeyword, (m) => '${m[1]}$_code');
  return text.replaceAll(_codeBeforeKeyword, _code);
}

const _closers = {')': '(', ']': '[', '}': '{'};

int _count(String text, String char) => char.allMatches(text).length;

/// Retire la ponctuation de fin ; une fermante n'est retirée que si elle
/// n'est pas ouverte dans le lien (« /[CHEMIN] » reste entier).
String _trimUrl(String url) {
  while (url.isNotEmpty && _trailing.contains(url[url.length - 1])) {
    final last = url[url.length - 1];
    final opener = _closers[last];
    if (opener != null && _count(url, opener) >= _count(url, last)) break;
    url = url.substring(0, url.length - 1);
  }
  return url;
}

/// Remplace les données personnelles de [text] ; garde tout le reste.
String anonymize(String text) {
  final out = StringBuffer();
  var last = 0;
  for (final match in _url.allMatches(text)) {
    final url = _trimUrl(match[0]!);
    out
      ..write(_anonymizePlain(text.substring(last, match.start)))
      ..write(_anonymizeUrl(url));
    last = match.start + url.length;
  }
  out.write(_anonymizePlain(text.substring(last)));
  return out.toString();
}
