import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../l10n/l10n.dart';

/// Ce qui a empêché la vérification.
enum BreachProblem { timeout, offline, tooManyRequests, unavailable }

/// Erreur de vérification ; [message] l'explique dans la langue de l'app.
class BreachCheckException implements Exception {
  const BreachCheckException(this.problem, {this.statusCode});

  final BreachProblem problem;
  final int? statusCode; // réponse HTTP (service indisponible)

  String message(AppLocalizations l) => switch (problem) {
    BreachProblem.timeout => l.breachErrorTimeout,
    BreachProblem.offline => l.breachErrorOffline,
    BreachProblem.tooManyRequests => l.breachErrorTooMany,
    BreachProblem.unavailable => l.breachErrorUnavailable('${statusCode ?? ''}'),
  };

  @override
  String toString() => 'BreachCheckException(${problem.name})';
}

/// Empreinte SHA-1 en hexadécimal majuscule (40 caractères).
/// Ne jamais l'écrire dans les journaux : elle identifie le mot de passe.
String sha1Hex(String password) =>
    sha1.convert(utf8.encode(password)).toString().toUpperCase();

/// Coupe l'empreinte : 5 premiers caractères (envoyés) et le reste (gardé).
(String prefix, String suffix) splitHash(String hash) =>
    (hash.substring(0, 5), hash.substring(5));

/// Lit la réponse « SUFFIXE:NOMBRE » ligne par ligne.
/// Les lignes de remplissage (nombre 0) et les lignes abîmées sont ignorées.
Map<String, int> parseRangeResponse(String body) {
  final counts = <String, int>{};
  for (final line in const LineSplitter().convert(body)) {
    final parts = line.trim().split(':');
    if (parts.length != 2) continue;
    final count = int.tryParse(parts[1]);
    if (count == null || count <= 0) continue;
    counts[parts[0].toUpperCase()] = count;
  }
  return counts;
}

/// Client de l'API Pwned Passwords (Have I Been Pwned), en k-anonymity :
/// seuls les 5 premiers caractères de l'empreinte quittent le téléphone.
class PwnedPasswordsClient {
  PwnedPasswordsClient({http.Client? client, this.timeout = defaultTimeout})
    : _client = client ?? http.Client();

  static const defaultTimeout = Duration(seconds: 10);
  static const _base = 'https://api.pwnedpasswords.com/range/';

  final http.Client _client;
  final Duration timeout;

  // Réponses déjà reçues, par préfixe, le temps d'une analyse.
  final _cache = <String, Map<String, int>>{};

  /// Nombre de fois où ce mot de passe a été vu dans des fuites (0 : jamais).
  /// Lève [BreachCheckException] si la vérification est impossible.
  Future<int> breachCount(String password) async {
    final (prefix, suffix) = splitHash(sha1Hex(password));
    final counts = _cache[prefix] ??= await _fetchRange(prefix);
    return counts[suffix] ?? 0;
  }

  /// Oublie les réponses (à la fin d'une analyse).
  void clearCache() => _cache.clear();

  void close() {
    _cache.clear();
    _client.close();
  }

  Future<Map<String, int>> _fetchRange(String prefix) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('$_base$prefix'),
            headers: const {
              // Réponses complétées avec de fausses lignes : leur taille
              // ne trahit pas le préfixe demandé.
              'Add-Padding': 'true',
              'User-Agent': 'Sentinel-App',
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const BreachCheckException(BreachProblem.timeout);
    } on SocketException {
      throw const BreachCheckException(BreachProblem.offline);
    } on http.ClientException {
      throw const BreachCheckException(BreachProblem.offline);
    }
    if (response.statusCode == 429) {
      throw const BreachCheckException(BreachProblem.tooManyRequests);
    }
    if (response.statusCode != 200) {
      throw BreachCheckException(
        BreachProblem.unavailable,
        statusCode: response.statusCode,
      );
    }
    return parseRangeResponse(response.body);
  }
}
