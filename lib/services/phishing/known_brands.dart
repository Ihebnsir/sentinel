import 'dart:convert';

import 'package:flutter/services.dart';

/// Une marque souvent imitée par les arnaqueurs, et ses vrais sites.
class KnownBrand {
  const KnownBrand({
    required this.name,
    required this.keywords,
    required this.officialDomains,
  });

  factory KnownBrand.fromJson(Map<String, Object?> json) => KnownBrand(
    name: json['name'] as String,
    keywords: _strings(json['keywords']),
    officialDomains: _strings(json['officialDomains']),
  );

  final String name; // nom affiché à l'utilisateur

  /// Mots cherchés dans le nom de domaine (minuscules).
  final List<String> keywords;

  /// Le domaine et ses sous-domaines sont sûrs.
  final List<String> officialDomains;
}

/// Fichier partagé avec Kotlin (BrandRules.kt) : une seule source.
/// Pour ajouter une marque, c'est ce fichier qu'il faut modifier.
const knownBrandsAsset = 'assets/data/known_brands.json';

/// Lit le contenu de known_brands.json (lève une exception si invalide).
List<KnownBrand> parseKnownBrands(String source) {
  final json = jsonDecode(source) as Map<String, Object?>;
  if (json['formatVersion'] != 1) {
    throw const FormatException('known_brands.json : version inconnue');
  }
  return List.unmodifiable([
    for (final item in json['brands'] as List)
      KnownBrand.fromJson((item as Map).cast<String, Object?>()),
  ]);
}

List<KnownBrand>? _brands;
Future<List<KnownBrand>>? _loading;

/// Les marques chargées par [loadKnownBrands].
/// Lève une StateError si on oublie de les charger avant l'analyse.
List<KnownBrand> get knownBrands =>
    _brands ?? (throw StateError('Appeler loadKnownBrands() avant'));

/// Charge les marques une seule fois. [bundle] sert aux tests.
Future<List<KnownBrand>> loadKnownBrands([AssetBundle? bundle]) {
  final loaded = _brands;
  if (loaded != null) return Future.value(loaded);
  return _loading ??= (bundle ?? rootBundle)
      .loadString(knownBrandsAsset)
      .then((text) => _brands = parseKnownBrands(text))
      .catchError((Object e) {
        // Échec : on permettra un nouvel essai au prochain appel.
        _loading = null;
        throw e;
      });
}

List<String> _strings(Object? value) =>
    List.unmodifiable((value as List).cast<String>());
