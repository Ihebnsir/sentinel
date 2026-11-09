import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Limite côté app : 5 signalements par heure glissante.
/// Le serveur a sa propre limite ; celle-ci évite d'envoyer pour rien.
/// Garde seulement l'heure des envois réussis de la dernière heure,
/// jamais leur contenu (fichier privé de l'app).
class ReportLimiter {
  ReportLimiter({
    Future<Directory> Function()? directory,
    DateTime Function()? now,
    this.limit = 5,
    this.window = const Duration(hours: 1),
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _now = now ?? DateTime.now;

  static const fileName = 'report_limit.json';

  final Future<Directory> Function() _directory;
  final DateTime Function() _now;
  final int limit;
  final Duration window;

  List<DateTime>? _sent; // chargé au premier usage

  Future<File> _file() async {
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  Future<List<DateTime>> _load() async {
    if (_sent case final sent?) return sent;
    final sent = <DateTime>[];
    try {
      final file = await _file();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        if (json is List) {
          for (final value in json) {
            if (value is int) {
              sent.add(DateTime.fromMillisecondsSinceEpoch(value, isUtc: true));
            }
          }
        }
      }
    } on Exception {
      // Fichier abîmé : on repart de zéro (le serveur limite aussi).
    }
    return _sent = sent;
  }

  // Oublie les envois de plus d'une heure (ou datés dans le futur).
  List<DateTime> _recent(List<DateTime> sent) {
    final now = _now().toUtc();
    sent.removeWhere((t) => now.difference(t) >= window || t.isAfter(now));
    return sent;
  }

  /// true si un nouvel envoi est permis maintenant.
  Future<bool> canSend() async => _recent(await _load()).length < limit;

  /// À appeler après un envoi réussi.
  Future<void> recordSent() async {
    final sent = _recent(await _load())..add(_now().toUtc());
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode([for (final t in sent) t.millisecondsSinceEpoch]),
        flush: true,
      );
    } on Exception {
      // Écriture impossible : la limite reste en mémoire.
    }
  }
}
