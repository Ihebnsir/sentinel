import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../app_info.dart';
import '../../l10n/l10n.dart';
import '../phishing/message_analyzer.dart';
import 'anonymizer.dart';

/// Adresse du serveur, donnée au build :
/// `--dart-define=SENTINEL_API_URL=https://…`. Vide : pas de signalement.
const sentinelApiUrl = String.fromEnvironment('SENTINEL_API_URL');

/// Seul serveur en clair permis, et seulement en debug : l'ordinateur vu
/// depuis l'émulateur Android (voir android/app/src/debug/).
const debugCleartextHost = '10.0.2.2';

/// Adresse utilisable, ou null (vide, mal écrite, ou HTTP interdit).
/// HTTPS obligatoire, sauf en debug vers http://10.0.2.2.
Uri? parseServerUrl(String raw, {bool debug = kDebugMode}) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
  if (uri.hasQuery || uri.hasFragment) return null;
  if (uri.scheme == 'https') return uri;
  if (debug && uri.scheme == 'http' && uri.host == debugCleartextHost) {
    return uri;
  }
  return null;
}

/// Avis de l'utilisateur, envoyé tel quel (valeurs du serveur).
enum UserFeedback {
  arnaque('arnaque'),
  pasArnaque('pas_arnaque'),
  neSaitPas('ne_sait_pas');

  const UserFeedback(this.wire);
  final String wire;
}

/// Ce qui a empêché l'envoi.
enum ReportProblem { offline, timeout, tooMany, rejected, server }

class ReportException implements Exception {
  const ReportException(this.problem);

  final ReportProblem problem;

  String message(AppLocalizations l) => switch (problem) {
    ReportProblem.offline => l.reportErrorOffline,
    ReportProblem.timeout => l.reportErrorTimeout,
    ReportProblem.tooMany => l.reportErrorTooMany,
    ReportProblem.rejected => l.reportErrorRejected,
    ReportProblem.server => l.reportErrorServer,
  };

  @override
  String toString() => 'ReportException(${problem.name})';
}

/// Un signalement prêt à partir. [text] est anonymisé une dernière fois
/// dans [toJson] : un numéro tapé pendant la relecture ne part pas.
class Report {
  const Report({
    required this.text,
    required this.verdict,
    required this.probability,
    required this.feedback,
  });

  final String text;
  final Verdict verdict;
  final double probability;
  final UserFeedback feedback;

  // Refusés par le serveur (sauf tabulation et retours à la ligne).
  static final _control = RegExp('[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  /// Texte final : anonymisé, sans caractère de contrôle, 2000 au plus.
  static String clean(String text) {
    final out = anonymize(text).replaceAll(_control, '');
    return out.length <= 2000 ? out : out.substring(0, 2000);
  }

  /// Exactement les champs de l'API : rien sur le téléphone ni la personne.
  Map<String, Object> toJson() => {
    'text': clean(text),
    'verdict': verdict.name,
    'probability': probability.clamp(0.0, 1.0),
    // Sur le texte anonymisé : les liens et numéros ne faussent rien.
    'language': guessLanguage(clean(text)),
    'app_version': appVersion,
    'source': 'inconnue',
    'user_feedback': feedback.wire,
  };
}

/// Envoie un signalement à POST /v1/reports. Un appel = un signalement :
/// pas de file d'attente, pas de nouvel essai automatique.
class ReportClient {
  ReportClient(
    this.server, {
    http.Client? client,
    this.timeout = defaultTimeout,
    bool debug = kDebugMode,
  }) : _client = client ?? http.Client() {
    // Double sécurité : une adresse refusée ne crée jamais de client.
    if (parseServerUrl(server.toString(), debug: debug) == null) {
      throw ArgumentError.value(server.scheme, 'server', 'HTTPS obligatoire');
    }
  }

  /// Client du build, ou null si SENTINEL_API_URL est vide ou refusée
  /// (le bouton « Signaler » est alors masqué).
  static ReportClient? fromEnvironment() {
    final server = parseServerUrl(sentinelApiUrl);
    return server == null ? null : ReportClient(server);
  }

  static const defaultTimeout = Duration(seconds: 10);

  final Uri server;
  final Duration timeout;
  final http.Client _client;

  /// Nom affiché à l'utilisateur (« où part le signalement »).
  String get host => server.hasPort ? '${server.host}:${server.port}' : server.host;

  Uri get _endpoint {
    final base = server.path.endsWith('/')
        ? server.path.substring(0, server.path.length - 1)
        : server.path;
    return server.replace(path: '$base/v1/reports');
  }

  /// Lève [ReportException] si le signalement n'est pas enregistré.
  Future<void> send(Report report) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: const {
              'Content-Type': 'application/json',
              'User-Agent': 'Sentinel-App',
            },
            body: jsonEncode(report.toJson()),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ReportException(ReportProblem.timeout);
    } on SocketException {
      throw const ReportException(ReportProblem.offline);
    } on http.ClientException {
      throw const ReportException(ReportProblem.offline);
    }
    switch (response.statusCode) {
      case 201:
        return;
      case 429:
        throw const ReportException(ReportProblem.tooMany);
      case 413 || 422:
        throw const ReportException(ReportProblem.rejected);
      default:
        throw const ReportException(ReportProblem.server);
    }
  }

  void close() => _client.close();
}

// --- Langue du message (indication pour la revue, pas une certitude) ----

final _arabicLetter = RegExp(r'[؀-ۿ]');
final _latinLetter = RegExp('[A-Za-zÀ-ÖØ-öø-ÿ]');
// Mot en arabizi : lettres latines et chiffres 3, 7 ou 9 (3la, mte3ek, l7ad).
final _arabiziWord = RegExp(r'^(?=(?:[0-9]*[a-z]){2})[a-z]*[379][a-z0-9]*$');
final _wordSplit = RegExp(r'[^A-Za-zÀ-ÖØ-öø-ÿ؀-ۿ0-9]+');

const _derjaArabic = {
  'برشا', 'باش', 'توا', 'شنوة', 'شنية', 'كيفاش', 'علاش', 'متاعك', 'متاع', //
  'نحب', 'يزي', 'بالله', 'عسلامة', 'ياسر', 'فما', 'ماكش',
};
const _derjaLatin = {
  'barcha', 'bech', 'taw', 'chnowa', 'chniya', 'kifech', 'mta3', 'mte3ek', //
  'yezi', 'sahbi', 'aslema', '3aslema', 'brabi', 'famma', 'nheb', 'ya3tik',
};
const _french = {
  'le', 'la', 'les', 'de', 'des', 'du', 'vous', 'votre', 'vos', 'est', //
  'pour', 'une', 'un', 'et', 'sur', 'avec', 'ici', 'colis', 'compte',
};
const _english = {
  'the', 'your', 'you', 'is', 'to', 'and', 'for', 'of', 'click', 'here', //
  'account', 'please', 'with', 'now',
};

/// Langue probable : fr, ar, derja_latin, derja_arabe, en, ou autre.
String guessLanguage(String text) {
  final arabic = _arabicLetter.allMatches(text).length;
  final latin = _latinLetter.allMatches(text).length;
  if (arabic == 0 && latin == 0) return 'autre';
  final words = text.toLowerCase().split(_wordSplit).toSet();
  if (arabic >= latin) {
    return words.any(_derjaArabic.contains) ? 'derja_arabe' : 'ar';
  }
  if (words.any(_derjaLatin.contains) || words.any(_arabiziWord.hasMatch)) {
    return 'derja_latin';
  }
  final fr = words.where(_french.contains).length;
  final en = words.where(_english.contains).length;
  if (fr == 0 && en == 0) return 'autre';
  return fr >= en ? 'fr' : 'en';
}
