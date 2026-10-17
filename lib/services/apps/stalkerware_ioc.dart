import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/installed_app.dart';

/// Mention de la source, exigée par la licence CC BY 4.0.
const iocCredit =
    'Liste de logiciels espions : projet Stalkerware '
    'Indicators (Echap), licence CC BY 4.0.';

/// Indicateurs de logiciels espions (stalkerware), généré par
/// tools/stalkerware/update_ioc.py à partir du projet public
/// AssoEchap/stalkerware-indicators (licence CC BY 4.0).
class StalkerwareIoc {
  StalkerwareIoc._({
    required this.source,
    required this.commit,
    required this.commitDate,
    required this.license,
    required this.attribution,
    required Map<String, String> byPackage,
    required Map<String, String> byCertSha1,
  }) : _byPackage = Map.unmodifiable(byPackage),
       _byCertSha1 = Map.unmodifiable(byCertSha1);

  /// Lit le JSON généré. Les entrées mal formées sont ignorées.
  factory StalkerwareIoc.fromJson(Map<String, Object?> json) {
    final byPackage = <String, String>{};
    final byCert = <String, String>{};
    final apps = json['apps'];
    if (apps is List) {
      for (final app in apps.whereType<Map<Object?, Object?>>()) {
        final name = app['name'] as String? ?? 'Inconnu';
        for (final p in _strings(app['packages'])) {
          // Un package Android est sensible à la casse : copie exacte.
          byPackage[p] = name;
        }
        for (final c in _strings(app['certificatesSha1'])) {
          byCert[normalizeFingerprint(c)] = name;
        }
      }
    }
    return StalkerwareIoc._(
      source: json['source'] as String? ?? '',
      commit: json['commit'] as String? ?? '',
      commitDate: json['commitDate'] as String? ?? '',
      license: json['license'] as String? ?? '',
      attribution: json['attribution'] as String? ?? '',
      byPackage: byPackage,
      byCertSha1: byCert,
    );
  }

  /// Emplacement du fichier dans les assets de l'app.
  static const assetPath = 'assets/data/stalkerware_ioc.json';

  static Future<StalkerwareIoc>? _loading;

  /// Charge les indicateurs une seule fois : les appels suivants
  /// reçoivent le même objet. [bundle] sert aux tests.
  static Future<StalkerwareIoc> load([AssetBundle? bundle]) {
    return _loading ??= _read(bundle ?? rootBundle).catchError((Object e) {
      // Échec : on permettra un nouvel essai au prochain appel.
      _loading = null;
      throw e;
    });
  }

  static Future<StalkerwareIoc> _read(AssetBundle bundle) async {
    final text = await bundle.loadString(assetPath);
    return StalkerwareIoc.fromJson(jsonDecode(text) as Map<String, Object?>);
  }

  final String source; // adresse du projet d'origine
  final String commit; // version exacte utilisée
  final String commitDate;
  final String license; // « CC BY 4.0 »
  final String attribution; // texte à afficher pour respecter la licence
  final Map<String, String> _byPackage; // package → nom du stalkerware
  final Map<String, String> _byCertSha1; // empreinte SHA-1 → nom

  int get packageCount => _byPackage.length;
  int get certificateCount => _byCertSha1.length;

  /// Nom du stalkerware si ce package est connu, sinon null.
  String? matchPackage(String packageName) => _byPackage[packageName];

  /// Nom du stalkerware si ce certificat (SHA-1) est connu, sinon null.
  String? matchCertificate(String sha1) =>
      _byCertSha1[normalizeFingerprint(sha1)];

  /// Cherche l'app par package puis par chacun de ses certificats.
  String? match(InstalledApp app) {
    final byPackage = matchPackage(app.packageName);
    if (byPackage != null) return byPackage;
    for (final cert in app.signingCerts) {
      if (cert.sha1.isEmpty) continue;
      final byCert = matchCertificate(cert.sha1);
      if (byCert != null) return byCert;
    }
    return null;
  }
}

Iterable<String> _strings(Object? value) =>
    value is List ? value.whereType<String>() : const [];
