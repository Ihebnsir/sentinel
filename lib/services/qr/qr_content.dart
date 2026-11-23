import '../../models/wifi_status.dart';
import 'phone_numbers.dart';
import 'qr_apps.dart';
import 'qr_cards.dart';
import 'qr_messaging.dart';

export 'phone_numbers.dart' show PhoneInfo, PhoneZone, parsePhone;

/// Ce que contient un QR code, une fois reconnu. Calcul pur, sans Flutter.
sealed class QrContent {
  const QrContent(this.raw);

  /// Le texte brut lu dans le QR code, tel quel.
  final String raw;
}

/// Un lien web seul (http ou https).
class QrLink extends QrContent {
  const QrLink(super.raw, {required this.url});

  final String url; // le lien sans espaces autour
}

/// Un lien d'un type dangereux (javascript:, intent:, file:…).
class QrUnsafeLink extends QrContent {
  const QrUnsafeLink(super.raw, {required this.scheme});

  final String scheme; // ex : « javascript »
}

/// Un réseau Wi-Fi (format WIFI:T:WPA;S:nom;P:mot de passe;;).
class QrWifi extends QrContent {
  const QrWifi(
    super.raw, {
    required this.ssid,
    required this.security,
    required this.hasPassword,
    this.hidden = false,
  });

  final String ssid; // nom du réseau
  final WifiSecurity security;
  final bool hasPassword;
  final bool hidden; // réseau masqué (H:true)
}

/// Un numéro à appeler (tel:).
class QrPhone extends QrContent {
  const QrPhone(super.raw, {required this.number});

  final String number;
}

/// Un SMS prêt à envoyer (sms:, smsto:).
class QrSms extends QrContent {
  const QrSms(super.raw, {required this.number, this.body = ''});

  final String number;
  final String body; // texte pré-rempli, souvent vide
}

/// Les formats de paiement reconnus.
enum PaymentKind {
  crypto, // bitcoin:, ethereum:…
  upi, // upi://pay (Inde)
  sepa, // virement européen (EPC, commence par BCD)
  emv, // QR de paiement des banques et commerçants (EMVCo)
}

/// Une demande de paiement.
class QrPayment extends QrContent {
  const QrPayment(
    super.raw, {
    required this.kind,
    required this.recipient,
    this.amount,
    this.currency,
    this.uri,
  });

  final PaymentKind kind;
  final String recipient; // nom, IBAN ou adresse du bénéficiaire
  final String? amount; // ex : « 12.50 », null si absent
  final String? currency; // ex : « EUR », « BTC »
  final String? uri; // lien à ouvrir dans une app de paiement, sinon null
}

/// Tout le reste : texte libre, lien sans « http »…
class QrText extends QrContent {
  const QrText(super.raw);
}

/// Les messageries reconnues.
enum MessagingApp { whatsapp, telegram, messenger, viber }

/// Avec qui la discussion s'ouvre.
enum MessagingTarget {
  person, // un numéro ou un compte
  group, // invitation dans un groupe
  channel, // chaîne ou page publique
  bot, // robot Telegram
  share, // « partager » un texte, sans destinataire
}

/// Un lien de messagerie (wa.me, t.me, m.me, viber://…).
class QrMessaging extends QrContent {
  const QrMessaging(
    super.raw, {
    required this.app,
    required this.target,
    this.phone,
    this.handle,
    this.text = '',
    this.url,
  });

  final MessagingApp app;
  final MessagingTarget target;
  final PhoneInfo? phone; // numéro du destinataire, s'il est dans le lien
  final String? handle; // nom du compte ou du groupe, ex : « @sentinel »
  final String text; // message pré-rempli, souvent vide
  final String? url; // lien https à ouvrir, null pour viber://, tg://…
}

/// D'où viendrait l'application.
enum AppSource {
  playStore, // play.google.com ou market://
  apk, // fichier .apk à télécharger directement
  intent, // intent:// (lance une app ou un écran caché)
  vendorStore, // boutique d'un fabricant (Samsung, Huawei, Xiaomi, Amazon)
  thirdPartyStore, // site de téléchargement d'APK (APKPure, Uptodown…)
}

/// Un lien qui mène à l'installation d'une application.
class QrAppInstall extends QrContent {
  const QrAppInstall(
    super.raw, {
    required this.source,
    this.packageId,
    this.store,
    this.url,
  });

  final AppSource source;
  final String? packageId; // ex : « com.whatsapp », s'il est dans le lien
  final String? store; // nom de la boutique, ex : « APKPure »
  final String? url; // lien https à ouvrir, null pour market://…
}

/// Une fiche contact (vCard ou MECARD).
class QrContact extends QrContent {
  const QrContact(
    super.raw, {
    required this.name,
    this.organization = '',
    this.phones = const [],
    this.emails = const [],
    this.url,
  });

  final String name;
  final String organization;
  final List<String> phones;
  final List<String> emails;
  final String? url; // site indiqué dans la fiche
}

/// Un e-mail prêt à écrire (mailto:, MATMSG:).
class QrEmail extends QrContent {
  const QrEmail(
    super.raw, {
    required this.address,
    this.subject = '',
    this.body = '',
  });

  final String address;
  final String subject;
  final String body;
}

/// Une position sur la carte (geo:lat,lon).
class QrGeo extends QrContent {
  const QrGeo(
    super.raw, {
    required this.latitude,
    required this.longitude,
    this.label = '',
  });

  final double latitude;
  final double longitude;
  final String label; // nom du lieu (paramètre q), souvent vide
}

/// Un rendez-vous à ajouter au calendrier (BEGIN:VEVENT).
class QrEvent extends QrContent {
  const QrEvent(
    super.raw, {
    required this.summary,
    this.start = '',
    this.end = '',
    this.location = '',
    this.description = '',
  });

  final String summary;
  final String start; // date lisible, ex : « 2026-12-01 18:00 »
  final String end;
  final String location;
  final String description;
}

/// Types de liens refusés : ils exécutent du code ou ouvrent un fichier
/// ou une app au lieu d'une page web.
const unsafeSchemes = {
  'javascript',
  'vbscript',
  'data',
  'file',
  'content',
  'intent',
  'android-app',
  'jar',
};

/// Cryptomonnaies reconnues, et leur sigle.
const cryptoSchemes = {
  'bitcoin': 'BTC',
  'bitcoincash': 'BCH',
  'litecoin': 'LTC',
  'ethereum': 'ETH',
  'monero': 'XMR',
  'lightning': 'BTC',
};

/// Reconnaît le format du QR code. Ne lève jamais d'exception :
/// un format abîmé devient du texte, analysé comme un message.
QrContent parseQr(String raw) {
  final text = raw.trim();
  final lower = text.toLowerCase();
  final scheme = RegExp(r'^([a-z][a-z0-9+.-]*):').firstMatch(lower)?[1];

  if (scheme == 'http' || scheme == 'https') {
    final uri = Uri.tryParse(text);
    // Un lien suivi d'un texte reste un message (analysé comme tel).
    if (uri != null && uri.host.isNotEmpty && !text.contains(RegExp(r'\s'))) {
      return parseWebMessaging(raw, text, uri) ??
          parseWebApp(raw, text, uri) ??
          QrLink(raw, url: text);
    }
    return QrText(raw);
  }
  if (scheme == null) {
    return _parseEpc(raw, text) ?? _parseEmv(raw, text) ?? QrText(raw);
  }
  // intent:// qui nomme une app : montré comme une installation, verdict
  // toujours « Dangereux » (voir qr_safety.dart).
  if (scheme == 'intent') {
    return parseIntentApp(raw, text) ?? QrUnsafeLink(raw, scheme: scheme);
  }
  if (unsafeSchemes.contains(scheme)) return QrUnsafeLink(raw, scheme: scheme);
  return switch (scheme) {
    'wifi' => _parseWifi(raw, text.substring(5)),
    'tel' => _parsePhone(raw, text.substring(4)),
    'sms' || 'smsto' || 'mmsto' => _parseSms(raw, text, scheme),
    'upi' => _parseUpi(raw, text),
    _ when cryptoSchemes.containsKey(scheme) => _parseCrypto(raw, text, scheme),
    'whatsapp' || 'tg' || 'viber' || 'fb-messenger' =>
      parseAppMessaging(raw, text, scheme) ?? QrText(raw),
    _ when appSchemes.containsKey(scheme) =>
      parseSchemeApp(raw, text, scheme) ?? QrText(raw),
    'mailto' => parseMailto(raw, text) ?? QrText(raw),
    'matmsg' => parseMatmsg(raw, text) ?? QrText(raw),
    'geo' => parseGeo(raw, text) ?? QrText(raw),
    'mecard' => parseMecard(raw, text) ?? QrText(raw),
    'begin' => parseVcard(raw, text) ?? parseVevent(raw, text) ?? QrText(raw),
    _ => QrText(raw),
  };
}

/// Lit un paramètre d'une adresse (« text » dans « ?text=Bonjour »),
/// décodé, ou null. Pour les autres fichiers de lib/services/qr.
String? queryParameter(String query, String name) =>
    _queryParameter(query, name);

/// Décode « %20 » ; un texte mal encodé reste tel quel.
String decodeComponent(String value) => _decode(value);

// WIFI:T:WPA;S:Maison;P:secret;H:true;; — « \ » protège ; , : " et \.
QrContent _parseWifi(String raw, String body) {
  final fields = <String, String>{};
  final value = StringBuffer();
  String? key;
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (c == r'\' && i + 1 < body.length) {
      value.write(body[++i]);
    } else if (key == null && c == ':') {
      key = value.toString().toUpperCase();
      value.clear();
    } else if (c == ';') {
      if (key != null) fields.putIfAbsent(key, () => value.toString());
      key = null;
      value.clear();
    } else {
      value.write(c);
    }
  }
  if (key != null) fields.putIfAbsent(key, () => value.toString());

  final ssid = fields['S'] ?? '';
  if (ssid.isEmpty) return QrText(raw);
  final password = fields['P'] ?? '';
  final type = (fields['T'] ?? '').toUpperCase();
  final security = switch (type) {
    _ when fields.containsKey('E') || type.contains('EAP') =>
      WifiSecurity.enterprise,
    'WEP' => WifiSecurity.wep,
    'SAE' || 'WPA3' => WifiSecurity.wpa3,
    // « WPA » couvre WPA et WPA2 : le QR code ne les distingue pas.
    'WPA' || 'WPA2' => WifiSecurity.wpa2,
    'NOPASS' => WifiSecurity.open,
    '' when password.isEmpty => WifiSecurity.open,
    _ => WifiSecurity.unknown,
  };
  return QrWifi(
    raw,
    ssid: ssid,
    security: security,
    hasPassword: password.isNotEmpty,
    hidden: (fields['H'] ?? '').toLowerCase() == 'true',
  );
}

QrContent _parsePhone(String raw, String rest) {
  final number = _decode(rest.split(';').first).trim();
  return number.isEmpty ? QrText(raw) : QrPhone(raw, number: number);
}

// SMSTO:numéro:texte, sms:numéro?body=texte, ou sms:numéro.
QrContent _parseSms(String raw, String text, String scheme) {
  final rest = text.substring(scheme.length + 1);
  String number;
  var body = '';
  final query = rest.indexOf('?');
  if (scheme == 'sms' && query >= 0) {
    number = rest.substring(0, query);
    body = _queryParameter(rest.substring(query + 1), 'body') ?? '';
  } else {
    final colon = rest.indexOf(':');
    number = colon < 0 ? rest : rest.substring(0, colon);
    if (colon >= 0) body = rest.substring(colon + 1);
  }
  number = _decode(number).trim();
  if (number.isEmpty) return QrText(raw);
  return QrSms(raw, number: number, body: body.trim());
}

// bitcoin:adresse?amount=0.01&label=…
QrContent _parseCrypto(String raw, String text, String scheme) {
  final rest = text.substring(scheme.length + 1);
  final query = rest.indexOf('?');
  final address = (query < 0 ? rest : rest.substring(0, query)).replaceFirst(
    RegExp('^//'),
    '',
  );
  if (address.isEmpty) return QrText(raw);
  final params = query < 0 ? '' : rest.substring(query + 1);
  return QrPayment(
    raw,
    kind: PaymentKind.crypto,
    recipient: address,
    amount:
        _queryParameter(params, 'amount') ??
        _queryParameter(params, 'tx_amount'),
    currency: cryptoSchemes[scheme],
    uri: text,
  );
}

// upi://pay?pa=nom@banque&pn=Nom&am=100&cu=INR
QrContent _parseUpi(String raw, String text) {
  final query = text.indexOf('?');
  final params = query < 0 ? '' : text.substring(query + 1);
  final payee = _queryParameter(params, 'pa');
  if (payee == null || payee.isEmpty) return QrText(raw);
  final name = _queryParameter(params, 'pn');
  return QrPayment(
    raw,
    kind: PaymentKind.upi,
    recipient: name == null || name.isEmpty ? payee : '$name ($payee)',
    amount: _queryParameter(params, 'am'),
    currency: _queryParameter(params, 'cu') ?? 'INR',
    uri: text,
  );
}

// Virement SEPA (EPC069-12) : BCD, version, encodage, SCT, BIC, nom,
// IBAN, montant (EUR12.50)…, une valeur par ligne.
QrPayment? _parseEpc(String raw, String text) {
  final lines = text.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();
  if (lines.length < 7 || lines[0] != 'BCD' || lines[3] != 'SCT') return null;
  final name = lines[5];
  final iban = lines[6].replaceAll(' ', '');
  if (iban.isEmpty) return null;
  final money = lines.length > 7
      ? RegExp(r'^([A-Z]{3})(\d+(?:\.\d{1,2})?)$').firstMatch(lines[7])
      : null;
  return QrPayment(
    raw,
    kind: PaymentKind.sepa,
    recipient: name.isEmpty ? iban : '$name ($iban)',
    amount: money?[2],
    currency: money?[1],
  );
}

/// Codes ISO 4217 numériques les plus courants (QR EMVCo).
const _currencyCodes = {
  '788': 'TND',
  '978': 'EUR',
  '840': 'USD',
  '504': 'MAD',
  '012': 'DZD',
  '826': 'GBP',
  '356': 'INR',
};

// QR EMVCo : suite de « étiquette (2 chiffres) + longueur (2) + valeur ».
// 00 = format (01), 59 = nom du commerçant, 54 = montant, 53 = devise.
QrPayment? _parseEmv(String raw, String text) {
  if (!text.startsWith('000201')) return null;
  final fields = <String, String>{};
  var i = 0;
  while (i + 4 <= text.length) {
    final tag = text.substring(i, i + 2);
    final length = int.tryParse(text.substring(i + 2, i + 4));
    if (length == null || i + 4 + length > text.length) return null;
    fields[tag] = text.substring(i + 4, i + 4 + length);
    i += 4 + length;
  }
  if (i != text.length) return null; // reste illisible : pas un QR EMVCo
  final currency = fields['53'];
  return QrPayment(
    raw,
    kind: PaymentKind.emv,
    recipient: fields['59'] ?? '',
    amount: fields['54'],
    currency: currency == null ? null : _currencyCodes[currency] ?? currency,
  );
}

String? _queryParameter(String query, String name) {
  for (final pair in query.split('&')) {
    final equal = pair.indexOf('=');
    if (equal < 0) continue;
    if (pair.substring(0, equal).toLowerCase() == name) {
      return _decode(pair.substring(equal + 1).replaceAll('+', ' '));
    }
  }
  return null;
}

// %20 → espace ; texte mal encodé : laissé tel quel.
String _decode(String value) {
  try {
    return Uri.decodeComponent(value);
  } on FormatException {
    return value; // « %E0%A4 » : octets UTF-8 incomplets
  } on ArgumentError {
    return value;
  }
}
