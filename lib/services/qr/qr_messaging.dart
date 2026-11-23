import 'qr_content.dart';

/// Liens de messagerie : wa.me, api.whatsapp.com, chat.whatsapp.com, t.me,
/// telegram.me, m.me, viber://… Calcul pur, sans Flutter.

const _whatsappHosts = {'wa.me', 'api.whatsapp.com', 'web.whatsapp.com'};
const _whatsappSite = {'whatsapp.com'};
const _telegramHosts = {'t.me', 'telegram.me', 'telegram.dog'};
const _messengerHosts = {'m.me'};

/// Lien https d'une messagerie connue, sinon null (simple lien web).
QrMessaging? parseWebMessaging(String raw, String text, Uri uri) {
  var host = uri.host.toLowerCase();
  if (host.startsWith('www.')) host = host.substring(4);
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final query = uri.hasQuery ? uri.query : '';
  String? param(String name) => queryParameter(query, name);
  final prefilled = param('text') ?? '';

  // WhatsApp : groupe, chaîne, discussion ou simple partage.
  if (host == 'chat.whatsapp.com') {
    if (segments.isEmpty) return null;
    return QrMessaging(
      raw,
      app: MessagingApp.whatsapp,
      target: MessagingTarget.group,
      handle: segments.last,
      url: text,
    );
  }
  if (_whatsappSite.contains(host) && segments.firstOrNull == 'channel') {
    return QrMessaging(
      raw,
      app: MessagingApp.whatsapp,
      target: MessagingTarget.channel,
      handle: segments.length > 1 ? segments[1] : null,
      url: text,
    );
  }
  if (_whatsappHosts.contains(host) ||
      (_whatsappSite.contains(host) && segments.firstOrNull == 'send')) {
    // wa.me/21698123456 ou api.whatsapp.com/send?phone=21698123456
    final number = host == 'wa.me' && segments.isNotEmpty
        ? segments.first
        : param('phone');
    final phone = number == null
        ? null
        : parsePhone(number, international: true);
    // wa.me/message/CODE : lien d'entreprise, sans numéro visible.
    final business = host == 'wa.me' && segments.firstOrNull == 'message';
    if (phone == null && !business && prefilled.isEmpty) return null;
    return QrMessaging(
      raw,
      app: MessagingApp.whatsapp,
      target: phone == null && !business
          ? MessagingTarget.share
          : MessagingTarget.person,
      phone: phone,
      text: prefilled,
      url: text,
    );
  }

  // Telegram : t.me/nom, t.me/+code (groupe), t.me/+216… (numéro).
  if (_telegramHosts.contains(host)) {
    if (segments.isEmpty) return null;
    final first = segments.first;
    if (first == 'joinchat' || (first.startsWith('+') && !_isDigits(first))) {
      return QrMessaging(
        raw,
        app: MessagingApp.telegram,
        target: MessagingTarget.group,
        handle: first == 'joinchat' && segments.length > 1
            ? segments[1]
            : first,
        url: text,
      );
    }
    if (first.startsWith('+')) {
      return QrMessaging(
        raw,
        app: MessagingApp.telegram,
        target: MessagingTarget.person,
        phone: parsePhone(first),
        url: text,
      );
    }
    if (first == 'share') {
      final shared = [param('url'), param('text')].nonNulls.join('\n');
      return QrMessaging(
        raw,
        app: MessagingApp.telegram,
        target: MessagingTarget.share,
        text: shared,
        url: text,
      );
    }
    final name = first == 's' || first == 'c'
        ? (segments.length > 1 ? segments[1] : '')
        : first;
    if (name.isEmpty) return null;
    return QrMessaging(
      raw,
      app: MessagingApp.telegram,
      target: _telegramTarget(name, channel: first == 's' || first == 'c'),
      handle: '@$name',
      text: prefilled,
      url: text,
    );
  }

  // Messenger : m.me/page, m.me/j/code (groupe).
  if (_messengerHosts.contains(host)) {
    if (segments.isEmpty) return null;
    final group = segments.first == 'j';
    return QrMessaging(
      raw,
      app: MessagingApp.messenger,
      target: group ? MessagingTarget.group : MessagingTarget.person,
      handle: group
          ? (segments.length > 1 ? segments[1] : null)
          : segments.first,
      text: prefilled,
      url: text,
    );
  }

  // Viber : invitation dans un groupe ou chaîne publique.
  if (host == 'invite.viber.com') {
    return QrMessaging(
      raw,
      app: MessagingApp.viber,
      target: MessagingTarget.group,
      url: text,
    );
  }
  if (host == 'chats.viber.com' && segments.isNotEmpty) {
    return QrMessaging(
      raw,
      app: MessagingApp.viber,
      target: MessagingTarget.channel,
      handle: segments.first,
      url: text,
    );
  }
  return null;
}

/// whatsapp://, tg://, viber://, fb-messenger:// : jamais ouverts par
/// Sentinel (pas un lien web), seulement expliqués.
QrMessaging? parseAppMessaging(String raw, String text, String scheme) {
  final rest = text
      .substring(scheme.length + 1)
      .replaceFirst(RegExp('^//'), '');
  final question = rest.indexOf('?');
  final action = (question < 0 ? rest : rest.substring(0, question))
      .toLowerCase()
      .replaceAll(RegExp(r'/+$'), '');
  final query = question < 0 ? '' : rest.substring(question + 1);
  String? param(String name) => queryParameter(query, name);

  switch (scheme) {
    case 'whatsapp':
      if (action == 'chat' && param('code') != null) {
        return QrMessaging(
          raw,
          app: MessagingApp.whatsapp,
          target: MessagingTarget.group,
          handle: param('code'),
        );
      }
      final number = param('phone');
      final phone = number == null
          ? null
          : parsePhone(number, international: true);
      return QrMessaging(
        raw,
        app: MessagingApp.whatsapp,
        target: phone == null ? MessagingTarget.share : MessagingTarget.person,
        phone: phone,
        text: param('text') ?? '',
      );
    case 'tg':
      if (action == 'join') {
        return QrMessaging(
          raw,
          app: MessagingApp.telegram,
          target: MessagingTarget.group,
          handle: param('invite'),
        );
      }
      if (action == 'msg' || action == 'msg_url' || action == 'share') {
        final shared = [param('url'), param('text')].nonNulls.join('\n');
        return QrMessaging(
          raw,
          app: MessagingApp.telegram,
          target: MessagingTarget.share,
          text: shared,
        );
      }
      final domain = param('domain');
      final number = param('phone');
      if (domain == null && number == null) return null;
      return QrMessaging(
        raw,
        app: MessagingApp.telegram,
        target: domain == null
            ? MessagingTarget.person
            : _telegramTarget(domain, channel: false),
        handle: domain == null ? null : '@$domain',
        phone: number == null ? null : parsePhone(number, international: true),
      );
    case 'viber':
      if (action == 'pa' || action == 'public') {
        return QrMessaging(
          raw,
          app: MessagingApp.viber,
          target: MessagingTarget.channel,
          handle: param('chatURI') ?? param('chaturi') ?? param('id'),
        );
      }
      if (action == 'forward') {
        return QrMessaging(
          raw,
          app: MessagingApp.viber,
          target: MessagingTarget.share,
          text: param('text') ?? '',
        );
      }
      final number = param('number');
      return QrMessaging(
        raw,
        app: MessagingApp.viber,
        target: action == 'invite' || action == 'group'
            ? MessagingTarget.group
            : MessagingTarget.person,
        phone: number == null ? null : parsePhone(number, international: true),
        text: param('text') ?? '',
      );
    case 'fb-messenger':
      return QrMessaging(
        raw,
        app: MessagingApp.messenger,
        target: action.startsWith('share')
            ? MessagingTarget.share
            : MessagingTarget.person,
        text: param('text') ?? param('link') ?? '',
      );
  }
  return null;
}

// Les robots Telegram ont un nom qui finit par « bot ».
MessagingTarget _telegramTarget(String name, {required bool channel}) {
  if (channel) return MessagingTarget.channel;
  if (name.toLowerCase().endsWith('bot')) return MessagingTarget.bot;
  return MessagingTarget.person;
}

bool _isDigits(String text) => RegExp(r'^\+?\d+$').hasMatch(text);
