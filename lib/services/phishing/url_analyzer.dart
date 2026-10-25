import '../../l10n/l10n.dart';
import 'known_brands.dart';

/// Les signaux qu'on peut trouver dans un lien, du plus grave au moins grave.
enum LinkSignal {
  usurpationMarque,
  adresseIp,
  punycode,
  arobase,
  raccourcisseur,
  extensionSuspecte,
  tropDeSousDomaines,
  sansHttps,
}

/// Un signal trouvé dans un lien. L'explication est écrite à l'affichage,
/// dans la langue de l'app ([reason]).
class LinkFinding {
  const LinkFinding(this.signal, {required this.host, this.brand});

  final LinkSignal signal;
  final String host; // le domaine (ou l'adresse IP) concerné
  final String? brand; // marque imitée (usurpationMarque seulement)

  /// L'explication du signal, ex : « Lien raccourci (bit.ly) : … ».
  String reason(AppLocalizations l) => switch (signal) {
    LinkSignal.usurpationMarque => l.reasonLinkImpersonation(host, brand ?? ''),
    LinkSignal.adresseIp => l.reasonLinkIp(host),
    LinkSignal.punycode => l.reasonLinkPunycode(host),
    LinkSignal.arobase => l.reasonLinkAt(host),
    LinkSignal.raccourcisseur => l.reasonLinkShortener(host),
    LinkSignal.extensionSuspecte => l.reasonLinkTld(host.split('.').last),
    LinkSignal.tropDeSousDomaines => l.reasonLinkSubdomains(host),
    LinkSignal.sansHttps => l.reasonLinkHttp,
  };
}

/// Un lien trouvé dans le message et ce qu'on en pense.
class AnalyzedLink {
  const AnalyzedLink({
    required this.text,
    required this.host,
    required this.findings,
  });

  final String text; // le lien tel qu'écrit dans le message
  final String host; // le nom de domaine (ou l'adresse IP), en minuscules
  final List<LinkFinding> findings; // vide si rien de suspect

  bool has(LinkSignal signal) => findings.any((f) => f.signal == signal);
}

/// Services qui cachent la vraie adresse derrière un lien court.
const urlShorteners = [
  'bit.ly',
  'tinyurl.com',
  'cutt.ly',
  'is.gd',
  't.co',
  'rb.gy',
  'shorturl.at',
];

/// Extensions bon marché, très utilisées par les arnaques.
const suspiciousTlds = [
  'xyz', 'top', 'icu', 'click', 'live', 'buzz', 'rest', 'cfd', //
];

// Extensions reconnues pour un lien écrit sans « http » ni « www ».
// Sans cette liste, « demain.Merci » serait pris pour un lien.
const _knownTlds = {
  ...suspiciousTlds,
  'tn', 'com', 'net', 'org', 'info', 'fr', 'io', 'co', 'me', 'ly', 'gy', //
  'at', 'gd', 'biz', 'online', 'site', 'shop', 'app', 'link', 'store', //
  'club', 'vip', 'pro', 'cc', 'ws', 'tk', 'ml', 'ga', 'cf', 'gq', 'dz', //
};

// Deuxièmes niveaux du type « com.tn » : le domaine compte alors 3 parties.
const _secondLevels = {'com', 'org', 'net', 'gov', 'edu', 'ens', 'nat', 'co'};

// Ponctuation de la phrase à retirer autour d'un lien.
final _edges = RegExp(r'''^["'«»(\[<{]+|["'«»)\]>},;:!?.]+$''');
final _scheme = RegExp(r'^(https?)://', caseSensitive: false);
final _port = RegExp(r':\d+$');
final _hostPattern = RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$');
final _ipPattern = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
final _hasLetter = RegExp(r'[a-z]');

/// Trouve les liens d'un message et vérifie chacun avec les règles.
List<AnalyzedLink> analyzeLinks(String text) => [
      // « ? » : on n'ajoute que les mots qui sont des liens (pas les null).
      for (final word in text.split(RegExp(r'\s+'))) ?_parseLink(word),
    ];

/// Analyse un mot ; null si ce n'est pas un lien.
AnalyzedLink? _parseLink(String word) {
  final cleaned = word.replaceAll(_edges, '');
  if (cleaned.isEmpty) return null;

  final schemeMatch = _scheme.firstMatch(cleaned);
  final scheme = schemeMatch?.group(1)?.toLowerCase();
  final rest =
      schemeMatch == null ? cleaned : cleaned.substring(schemeMatch.end);

  // Partie « adresse » : jusqu'au premier /, ? ou #.
  final authorityEnd = rest.indexOf(RegExp(r'[/?#]'));
  final authority = authorityEnd == -1 ? rest : rest.substring(0, authorityEnd);
  final hasPath = authorityEnd != -1;

  // « @ » : le navigateur ignore tout ce qui est avant.
  final atIndex = authority.lastIndexOf('@');
  final hasAt = atIndex != -1;
  // Sans « http », un « @ » est une adresse e-mail, pas un lien.
  if (hasAt && scheme == null) return null;

  var host = authority.substring(atIndex + 1).toLowerCase();
  final hasPort = _port.hasMatch(host);
  host = host.replaceFirst(_port, '');
  if (host.endsWith('.')) host = host.substring(0, host.length - 1);

  final isIp = _ipPattern.hasMatch(host);
  if (!isIp && !_hostPattern.hasMatch(host)) return null;
  final tld = host.split('.').last;
  if (!isIp && !_hasLetter.hasMatch(tld)) return null; // ex : « 3.5 »

  // Sans « http », on exige « www. », une extension connue,
  // ou une IP suivie d'un chemin ou d'un port.
  if (scheme == null) {
    final looksLikeLink = isIp
        ? hasPath || hasPort
        : host.startsWith('www.') || _knownTlds.contains(tld);
    if (!looksLikeLink) return null;
  }

  return AnalyzedLink(
    text: cleaned,
    host: host,
    findings: _rules(host: host, scheme: scheme, isIp: isIp, hasAt: hasAt),
  );
}

/// Applique toutes les règles à un lien, de la plus grave à la moins grave.
List<LinkFinding> _rules({
  required String host,
  required String? scheme,
  required bool isIp,
  required bool hasAt,
}) {
  final findings = <LinkFinding>[];
  void add(LinkSignal signal, [String? brand]) =>
      findings.add(LinkFinding(signal, host: host, brand: brand));
  final tld = host.split('.').last;

  if (!isIp) {
    final brand = impersonatedBrand(host);
    if (brand != null) add(LinkSignal.usurpationMarque, brand.name);
  }
  if (isIp) add(LinkSignal.adresseIp);
  if (host.split('.').any((label) => label.startsWith('xn--'))) {
    add(LinkSignal.punycode);
  }
  if (hasAt) add(LinkSignal.arobase);
  if (!isIp && _isShortener(host)) add(LinkSignal.raccourcisseur);
  if (!isIp && suspiciousTlds.contains(tld)) add(LinkSignal.extensionSuspecte);
  if (!isIp && subdomainCount(host) > 3) add(LinkSignal.tropDeSousDomaines);
  if (scheme == 'http') add(LinkSignal.sansHttps);
  return findings;
}

bool _isShortener(String host) =>
    urlShorteners.any((s) => host == s || host.endsWith('.$s'));

// Morceaux du domaine enregistrable : 3 pour « biat.com.tn », sinon 2.
int _domainParts(List<String> labels) {
  final hasSecondLevel = labels.length >= 3 &&
      labels.last.length == 2 &&
      _secondLevels.contains(labels[labels.length - 2]);
  return hasSecondLevel ? 3 : 2;
}

/// Nombre de sous-domaines : « a.b.exemple.com » → 2, « a.biat.com.tn » → 1.
int subdomainCount(String host) {
  final labels = host.split('.');
  final domainParts = _domainParts(labels);
  return labels.length > domainParts ? labels.length - domainParts : 0;
}

/// Nom du domaine enregistrable : « laposte » pour « www.laposte.fr »,
/// « biat » pour « biat.com.tn ». null pour un nom sans extension.
String? registrableName(String host) {
  final labels = host.split('.');
  final domainParts = _domainParts(labels);
  return labels.length >= domainParts
      ? labels[labels.length - domainParts]
      : null;
}

/// La marque que ce domaine imite, ou null.
/// Le domaine officiel et ses sous-domaines ne sont jamais signalés, ni
/// le mot-clé seul suivi d'une extension étrangère (« laposte.fr », « orange.be »).
/// Même règle en Kotlin (BrandRules.kt), vérifiée par test/fixtures/brand_parity.json.
KnownBrand? impersonatedBrand(String host, {List<KnownBrand>? brands}) {
  final parts = host.split(RegExp(r'[.-]'));
  // Morceaux où chercher un mot-clé long : chaque partie, et chaque
  // étiquette sans ses tirets (« la-poste-tn » → « lapostetn »).
  final pieces = {
    ...parts,
    for (final label in host.split('.')) label.replaceAll('-', ''),
  };
  final tld = host.split('.').last;
  // Pas d'exemption pour une extension d'arnaque (« biat.xyz ») ni
  // tunisienne : une marque tunisienne n'a pas d'« autre pays » en .tn.
  final exemptable = !suspiciousTlds.contains(tld) && tld != 'tn';
  final name = exemptable ? registrableName(host) : null;
  for (final brand in brands ?? knownBrands) {
    // Mot-clé long : au début ou à la fin d'un morceau (« laposte2 »,
    // « monlaposte »), pas au milieu d'un autre mot (« imposter »).
    final mentioned = brand.keywords.any(
      (k) =>
          parts.contains(k) ||
          (k.length >= 5 &&
              pieces.any((p) => p.startsWith(k) || p.endsWith(k))),
    );
    if (!mentioned) continue;
    // Mot-clé seul + extension : sans doute le vrai site de la même
    // marque dans un autre pays. Signalé seulement s'il est combiné à
    // d'autres mots (« laposte-colis.xyz ») ou en sous-domaine d'un autre site.
    if (brand.keywords.contains(name)) continue;
    final official = brand.officialDomains.any(
      (d) => host == d || host.endsWith('.$d'),
    );
    if (!official) return brand;
  }
  return null;
}
