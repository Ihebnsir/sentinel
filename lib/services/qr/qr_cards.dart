import 'dart:convert';

import 'qr_content.dart';

/// Fiches contact (vCard, MECARD), e-mails (mailto:, MATMSG:), positions
/// (geo:) et rendez-vous (BEGIN:VEVENT). Calcul pur, sans Flutter.

// Au-delà, le reste est ignoré : un QR code n'en contient jamais autant.
const _maxLines = 300;
const _maxItems = 10;

/// Lignes « NOM;PARAMÈTRES:valeur », lignes repliées recollées.
List<(String, String, String)> _properties(String text) {
  final unfolded = text.replaceAll(RegExp(r'\r?\n[ \t]'), '');
  final result = <(String, String, String)>[];
  for (final line in unfolded.split(RegExp(r'\r?\n')).take(_maxLines)) {
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    final head = line.substring(0, colon);
    final semicolon = head.indexOf(';');
    var name = (semicolon < 0 ? head : head.substring(0, semicolon))
        .toUpperCase()
        .trim();
    // « item1.TEL » (iPhone) → « TEL ».
    if (name.contains('.')) name = name.substring(name.lastIndexOf('.') + 1);
    final params = semicolon < 0
        ? ''
        : head.substring(semicolon + 1).toUpperCase();
    var value = line.substring(colon + 1);
    if (params.contains('QUOTED-PRINTABLE')) value = _quotedPrintable(value);
    result.add((name, params, value));
  }
  return result;
}

// « \, » « \; » « \n » des vCard et iCalendar.
String _unescape(String value) => value
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\N', '\n')
    .replaceAllMapped(RegExp(r'\\([,;:\\])'), (m) => m[1]!)
    .trim();

// vCard 2.1 : « =C3=A9 » → « é » (UTF-8).
String _quotedPrintable(String value) {
  final bytes = <int>[];
  final text = value.replaceAll('=\r\n', '').replaceAll('=\n', '');
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '=' && i + 2 < text.length) {
      final byte = int.tryParse(text.substring(i + 1, i + 3), radix: 16);
      if (byte != null) {
        bytes.add(byte);
        i += 2;
        continue;
      }
    }
    bytes.addAll(utf8.encode(c));
  }
  return utf8.decode(bytes, allowMalformed: true);
}

/// BEGIN:VCARD … END:VCARD
QrContact? parseVcard(String raw, String text) {
  if (!text.toUpperCase().startsWith('BEGIN:VCARD')) return null;
  var formatted = '';
  var structured = '';
  var organization = '';
  String? url;
  final phones = <String>[];
  final emails = <String>[];
  for (final (name, _, value) in _properties(text)) {
    switch (name) {
      case 'FN':
        formatted = _unescape(value);
      case 'N':
        // Nom;Prénom;Autres;Titre;Suffixe → « Prénom Nom ».
        final parts = value.split(';').map(_unescape).toList();
        structured = [
          if (parts.length > 1) parts[1],
          parts[0],
        ].where((p) => p.isNotEmpty).join(' ');
      case 'ORG':
        organization = _unescape(value.replaceAll(';', ' ')).trim();
      case 'TEL' when phones.length < _maxItems:
        final phone = _unescape(
          value.replaceFirst(RegExp('^tel:', caseSensitive: false), ''),
        );
        if (phone.isNotEmpty) phones.add(phone);
      case 'EMAIL' when emails.length < _maxItems:
        final email = _unescape(value);
        if (email.isNotEmpty) emails.add(email);
      case 'URL':
        url ??= _unescape(value);
    }
  }
  final contactName = formatted.isNotEmpty ? formatted : structured;
  if (contactName.isEmpty &&
      organization.isEmpty &&
      phones.isEmpty &&
      emails.isEmpty) {
    return null;
  }
  return QrContact(
    raw,
    name: contactName,
    organization: organization,
    phones: phones,
    emails: emails,
    url: url,
  );
}

/// Champs « CLÉ:valeur; » des formats MECARD et MATMSG (« \ » protège).
Map<String, List<String>> _semicolonFields(String body) {
  final fields = <String, List<String>>{};
  final value = StringBuffer();
  String? key;
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (c == r'\' && i + 1 < body.length) {
      value.write(body[++i]);
    } else if (key == null && c == ':') {
      key = value.toString().toUpperCase().trim();
      value.clear();
    } else if (c == ';') {
      if (key != null) (fields[key] ??= []).add(value.toString().trim());
      key = null;
      value.clear();
    } else {
      value.write(c);
    }
  }
  if (key != null) (fields[key] ??= []).add(value.toString().trim());
  return fields;
}

/// MECARD:N:Nom,Prénom;TEL:…;EMAIL:…;;
QrContact? parseMecard(String raw, String text) {
  final fields = _semicolonFields(text.substring('mecard:'.length));
  final rawName = fields['N']?.first ?? '';
  // « Nom,Prénom » → « Prénom Nom ».
  final parts = rawName.split(',').map((p) => p.trim()).toList();
  final name = parts.length > 1 ? '${parts[1]} ${parts[0]}'.trim() : rawName;
  final phones = [...?fields['TEL']]
      .where((p) => p.isNotEmpty)
      .take(_maxItems)
      .toList();
  final emails = [...?fields['EMAIL']]
      .where((e) => e.isNotEmpty)
      .take(_maxItems)
      .toList();
  final organization = fields['ORG']?.first ?? '';
  if (name.isEmpty &&
      phones.isEmpty &&
      emails.isEmpty &&
      organization.isEmpty) {
    return null;
  }
  return QrContact(
    raw,
    name: name,
    organization: organization,
    phones: phones,
    emails: emails,
    url: fields['URL']?.first,
  );
}

/// mailto:adresse?subject=…&body=…
QrEmail? parseMailto(String raw, String text) {
  final rest = text.substring('mailto:'.length);
  final question = rest.indexOf('?');
  final query = question < 0 ? '' : rest.substring(question + 1);
  var address = decodeComponent(
    question < 0 ? rest : rest.substring(0, question),
  ).trim();
  if (address.isEmpty) address = queryParameter(query, 'to') ?? '';
  if (address.isEmpty) return null;
  return QrEmail(
    raw,
    address: address,
    subject: queryParameter(query, 'subject') ?? '',
    body: queryParameter(query, 'body') ?? '',
  );
}

/// MATMSG:TO:adresse;SUB:objet;BODY:texte;;
QrEmail? parseMatmsg(String raw, String text) {
  final fields = _semicolonFields(text.substring('matmsg:'.length));
  final address = fields['TO']?.first ?? '';
  if (address.isEmpty) return null;
  return QrEmail(
    raw,
    address: address,
    subject: fields['SUB']?.first ?? '',
    body: fields['BODY']?.first ?? '',
  );
}

/// geo:36.8065,10.1815?q=Tunis
QrGeo? parseGeo(String raw, String text) {
  final rest = text.substring('geo:'.length);
  final question = rest.indexOf('?');
  final coordinates = (question < 0 ? rest : rest.substring(0, question))
      .split(';')
      .first
      .split(',');
  if (coordinates.length < 2) return null;
  final latitude = double.tryParse(coordinates[0].trim());
  final longitude = double.tryParse(coordinates[1].trim());
  if (latitude == null || longitude == null) return null;
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  final query = question < 0 ? '' : rest.substring(question + 1);
  return QrGeo(
    raw,
    latitude: latitude,
    longitude: longitude,
    label: queryParameter(query, 'q') ?? '',
  );
}

/// BEGIN:VEVENT (seul ou dans BEGIN:VCALENDAR).
QrEvent? parseVevent(String raw, String text) {
  final upper = text.toUpperCase();
  if (!upper.startsWith('BEGIN:VEVENT') &&
      !upper.startsWith('BEGIN:VCALENDAR')) {
    return null;
  }
  if (!upper.contains('BEGIN:VEVENT')) return null;
  final values = <String, String>{};
  var inEvent = false;
  for (final (name, _, value) in _properties(text)) {
    final section = value.toUpperCase().trim();
    if (name == 'BEGIN' && section == 'VEVENT') inEvent = true;
    if (name == 'END' && section == 'VEVENT') break;
    if (inEvent) values.putIfAbsent(name, () => _unescape(value));
  }
  final event = QrEvent(
    raw,
    summary: values['SUMMARY'] ?? '',
    start: formatIcsDate(values['DTSTART'] ?? ''),
    end: formatIcsDate(values['DTEND'] ?? ''),
    location: values['LOCATION'] ?? '',
    description: values['DESCRIPTION'] ?? '',
  );
  if (event.summary.isEmpty && event.start.isEmpty && event.location.isEmpty) {
    return null;
  }
  return event;
}

/// « 20261201T180000Z » → « 2026-12-01 18:00 UTC ». Illisible : tel quel.
String formatIcsDate(String value) {
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})\d{0,2}(Z?))?$')
      .firstMatch(value.trim());
  if (m == null) return value.trim();
  final date = '${m[1]}-${m[2]}-${m[3]}';
  if (m[4] == null) return date;
  return '$date ${m[4]}:${m[5]}${m[6] == 'Z' ? ' UTC' : ''}';
}
