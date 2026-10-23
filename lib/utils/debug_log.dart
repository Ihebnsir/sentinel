import 'package:flutter/foundation.dart';

/// Message de diagnostic, écrit seulement en mode debug (SEN-05).
/// En release, kDebugMode vaut false : rien n'arrive dans logcat, et
/// [message] n'est jamais appelé, donc son texte n'est même pas gardé
/// dans l'app compilée.
/// C'est le seul endroit de lib/ qui a le droit d'appeler debugPrint
/// (vérifié par test/no_release_logs_test.dart).
@pragma('vm:prefer-inline')
void debugLog(String Function() message) {
  if (kDebugMode) debugPrint(message());
}
