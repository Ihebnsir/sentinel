import '../../models/installed_app.dart';

/// Une application souvent imitée, et ce qui prouve qu'elle est officielle.
class KnownApp {
  const KnownApp({
    required this.name,
    required this.displayNames,
    required this.officialPackages,
    this.certSha256 = const [],
  });

  final String name; // nom affiché à l'utilisateur, ex : « WhatsApp »
  final List<String> displayNames; // noms possibles, déjà normalisés
  final List<String> officialPackages; // vide = emplacement à compléter
  final List<String> certSha256; // vide = pas encore vérifié, règle inactive
}

/// Une version modifiée connue d'une app (mod non officiel).
class ModdedApp {
  const ModdedApp({
    required this.of,
    required this.displayNames,
    this.packages = const [],
  });

  final String of; // l'app d'origine, ex : « WhatsApp »
  final List<String> displayNames; // déjà normalisés
  final List<String> packages;
}

/// Caractères invisibles qu'un faussaire peut glisser dans un nom.
final _invisible = RegExp(
  '[\u00AD\u200B-\u200F\u202A-\u202E\u2060-\u2064\uFEFF]',
);
final _spaces = RegExp(r'\s+');

/// « WhatsApp », « whatsapp  », « WHATS APP » → « whatsapp ».
/// Minuscules, sans espaces ni caractères invisibles.
String normalizeAppName(String name) =>
    name.replaceAll(_invisible, '').replaceAll(_spaces, '').toLowerCase();

// TODO(à vérifier) : aucune empreinte SHA-256 n'est remplie ici, car aucune
// n'a encore été vérifiée. Pour chaque app, installer la version officielle
// depuis le Play Store puis lancer :
//   python tools/signatures/extract_cert.py --adb <package>
// et recopier l'empreinte (voir tools/signatures/README.md). Tant que la
// liste est vide, la règle « signature différente » ne s'applique pas.
//
// Les noms affichés sont comparés en entier après normalisation :
// « WhatsApp Business » ne correspond pas à « WhatsApp ».
const knownApps = [
  KnownApp(
    name: 'WhatsApp',
    displayNames: ['whatsapp'],
    officialPackages: ['com.whatsapp'],
  ),
  KnownApp(
    name: 'WhatsApp Business',
    displayNames: ['whatsappbusiness', 'wabusiness'],
    officialPackages: ['com.whatsapp.w4b'],
  ),
  KnownApp(
    name: 'Facebook',
    displayNames: ['facebook'],
    officialPackages: ['com.facebook.katana'],
  ),
  KnownApp(
    name: 'Messenger',
    displayNames: ['messenger', 'facebookmessenger'],
    officialPackages: ['com.facebook.orca'],
  ),
  KnownApp(
    name: 'Instagram',
    displayNames: ['instagram'],
    officialPackages: ['com.instagram.android'],
  ),
  // TODO(à vérifier) : TikTok a d'autres packages selon les pays ; les
  // ajouter seulement après vérification, sinon fausse alerte.
  KnownApp(
    name: 'TikTok',
    displayNames: ['tiktok'],
    officialPackages: ['com.zhiliaoapp.musically'],
  ),
  // TODO(à vérifier) : la version téléchargée sur telegram.org a peut-être
  // un package différent de celle du Play Store.
  KnownApp(
    name: 'Telegram',
    displayNames: ['telegram'],
    officialPackages: ['org.telegram.messenger'],
  ),
  KnownApp(
    name: 'Snapchat',
    displayNames: ['snapchat'],
    officialPackages: ['com.snapchat.android'],
  ),
  KnownApp(
    name: 'YouTube',
    displayNames: ['youtube'],
    officialPackages: ['com.google.android.youtube'],
  ),
  KnownApp(
    name: 'Gmail',
    displayNames: ['gmail'],
    officialPackages: ['com.google.android.gm'],
  ),
  // Google Pay s'appelle maintenant Google Wallet (même package) ;
  // le second package est l'app GPay d'Inde.
  KnownApp(
    name: 'Google Pay',
    displayNames: ['googlepay', 'gpay', 'googlewallet'],
    officialPackages: [
      'com.google.android.apps.walletnfcrel',
      'com.google.android.apps.nbu.paisa.user',
    ],
  ),

  // Emplacements pour les apps tunisiennes.
  // TODO(à vérifier) : relever le package exact sur la page Play Store
  // officielle (lien donné par le site de la banque ou de La Poste), puis
  // l'empreinte avec extract_cert.py. Sans package, l'entrée est ignorée.
  KnownApp(name: 'D17 (La Poste)', displayNames: ['d17'], officialPackages: []),
  KnownApp(
    name: 'e-Dinar (La Poste)',
    displayNames: ['edinar', 'e-dinar'],
    officialPackages: [],
  ),
  KnownApp(
    name: 'La Poste Tunisienne',
    displayNames: ['laposte', 'lapostetunisienne'],
    officialPackages: [],
  ),
  KnownApp(name: 'BIAT', displayNames: ['biat'], officialPackages: []),
  KnownApp(name: 'STB', displayNames: ['stb'], officialPackages: []),
  KnownApp(name: 'BNA', displayNames: ['bna'], officialPackages: []),
  KnownApp(
    name: 'Attijari Bank',
    displayNames: ['attijari', 'attijaribank'],
    officialPackages: [],
  ),
];

// Versions modifiées de WhatsApp, très diffusées hors des boutiques.
// Les noms suffisent ; les packages ci-dessous sont ceux que ces mods
// utilisent pour cohabiter avec le vrai WhatsApp. Beaucoup de mods
// reprennent aussi « com.whatsapp » : seule l'empreinte les trahit alors.
const knownModdedApps = [
  ModdedApp(
    of: 'WhatsApp',
    displayNames: ['gbwhatsapp', 'whatsappgb'],
    packages: ['com.gbwhatsapp'],
  ),
  ModdedApp(
    of: 'WhatsApp',
    displayNames: ['fmwhatsapp', 'whatsappfm'],
    packages: ['com.fmwhatsapp'],
  ),
  ModdedApp(
    of: 'WhatsApp',
    displayNames: ['yowhatsapp', 'whatsappyo'],
    packages: ['com.yowhatsapp'],
  ),
  ModdedApp(
    of: 'WhatsApp',
    displayNames: ['ogwhatsapp'],
    packages: ['com.ogwhatsapp'],
  ),
  ModdedApp(of: 'WhatsApp', displayNames: ['whatsappplus', 'whatsapp+']),
  ModdedApp(of: 'WhatsApp', displayNames: ['whatsappaero', 'aerowhatsapp']),
  ModdedApp(of: 'WhatsApp', displayNames: ['whatsappgold']),
];

/// Ce que Sentinel conclut sur l'identité d'une app.
enum IdentityVerdict {
  /// Pas dans la base : rien à dire.
  unknown,

  /// Package officiel, empreinte connue et identique.
  verified,

  /// Package officiel, mais aucune empreinte de référence à comparer.
  officialUnchecked,

  /// Package officiel, mais signée par quelqu'un d'autre (repackagée).
  modifiedCopy,

  /// Porte le nom d'une app connue avec un autre package.
  impersonation,

  /// Version modifiée connue (GB WhatsApp…).
  knownMod,
}

/// Verdict et nom de l'app concernée (« WhatsApp »).
class AppIdentity {
  const AppIdentity(this.verdict, [this.brand]);

  static const unknown = AppIdentity(IdentityVerdict.unknown);

  final IdentityVerdict verdict;
  final String? brand;
}

/// Compare l'app à la base officielle. Fonction pure.
/// Ordre : mod connu, puis package officiel (signature), puis usurpation.
AppIdentity identifyApp(
  InstalledApp app, {
  List<KnownApp> known = knownApps,
  List<ModdedApp> mods = knownModdedApps,
}) {
  final name = normalizeAppName(app.label);

  for (final mod in mods) {
    if (mod.packages.contains(app.packageName) ||
        mod.displayNames.contains(name)) {
      return AppIdentity(IdentityVerdict.knownMod, mod.of);
    }
  }

  for (final entry in known) {
    if (!entry.officialPackages.contains(app.packageName)) continue;
    // Signature illisible ou base vide : on ne conclut rien.
    if (entry.certSha256.isEmpty || app.signingCerts.isEmpty) {
      return AppIdentity(IdentityVerdict.officialUnchecked, entry.name);
    }
    final expected = entry.certSha256.map(normalizeFingerprint).toSet();
    final matches = app.signingCerts.any(
      (c) => expected.contains(normalizeFingerprint(c.sha256)),
    );
    return AppIdentity(
      matches ? IdentityVerdict.verified : IdentityVerdict.modifiedCopy,
      entry.name,
    );
  }

  for (final entry in known) {
    // Emplacement sans package : impossible de juger, on ignore.
    if (entry.officialPackages.isEmpty) continue;
    if (entry.displayNames.contains(name)) {
      return AppIdentity(IdentityVerdict.impersonation, entry.name);
    }
  }
  return AppIdentity.unknown;
}
