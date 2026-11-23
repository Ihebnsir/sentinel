import '../apps/known_apps.dart';
import 'qr_content.dart';

/// Liens d'installation d'applications : Play Store, .apk, intent://,
/// boutiques des fabricants et sites d'APK. Calcul pur, sans Flutter.

/// Schémas des boutiques (hors web) et la boutique correspondante.
const appSchemes = {
  'market': (AppSource.playStore, 'Google Play'),
  'samsungapps': (AppSource.vendorStore, 'Galaxy Store'),
  'appmarket': (AppSource.vendorStore, 'AppGallery'),
  'mimarket': (AppSource.vendorStore, 'GetApps'),
  'amzn': (AppSource.vendorStore, 'Amazon Appstore'),
};

/// Boutiques des fabricants : contrôlées, mais moins que le Play Store.
const vendorStoreHosts = {
  'galaxystore.samsung.com': 'Galaxy Store',
  'apps.samsung.com': 'Galaxy Store',
  'appgallery.huawei.com': 'AppGallery',
  'appgallery.cloud.huawei.com': 'AppGallery',
  'app.mi.com': 'GetApps',
  'global.app.mi.com': 'GetApps',
};

/// Sites qui distribuent des fichiers APK : aucun contrôle de Google.
/// Clé : domaine (sous-domaines compris).
const thirdPartyStoreHosts = {
  'apkpure.com': 'APKPure',
  'apkpure.net': 'APKPure',
  'apkmirror.com': 'APKMirror',
  'uptodown.com': 'Uptodown',
  'aptoide.com': 'Aptoide',
  'apkcombo.com': 'APKCombo',
  'apkmonk.com': 'APKMonk',
  'happymod.com': 'HappyMod',
  'an1.com': 'AN1',
  'apkmody.io': 'APKMody',
  'liteapks.com': 'LiteAPKs',
  'f-droid.org': 'F-Droid',
};

const _apkExtensions = ['.apk', '.xapk', '.apks', '.apkm'];
const _apkMime = 'vnd.android.package-archive';

/// Lien https vers une installation, sinon null (simple lien web).
QrAppInstall? parseWebApp(String raw, String text, Uri uri) {
  var host = uri.host.toLowerCase();
  if (host.startsWith('www.')) host = host.substring(4);
  final path = uri.path.toLowerCase();
  final query = uri.hasQuery ? uri.query : '';

  // Fichier APK direct : extension, ou type annoncé dans l'adresse.
  if (_apkExtensions.any(path.endsWith) ||
      decodeComponent(query).toLowerCase().contains(_apkMime)) {
    return QrAppInstall(
      raw,
      source: AppSource.apk,
      store: _storeOf(host, thirdPartyStoreHosts),
      url: text,
    );
  }
  if (host == 'play.google.com' && path.startsWith('/store/apps')) {
    return QrAppInstall(
      raw,
      source: AppSource.playStore,
      packageId: path.startsWith('/store/apps/details')
          ? _package(queryParameter(query, 'id'))
          : null,
      store: 'Google Play',
      url: text,
    );
  }
  if (host == 'amazon.com' && path.startsWith('/gp/mas/dl/android')) {
    return QrAppInstall(
      raw,
      source: AppSource.vendorStore,
      packageId: _package(queryParameter(query, 'p')),
      store: 'Amazon Appstore',
      url: text,
    );
  }
  final vendor = _storeOf(host, vendorStoreHosts);
  if (vendor != null) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return QrAppInstall(
      raw,
      source: AppSource.vendorStore,
      packageId: _package(
        queryParameter(query, 'id') ??
            queryParameter(query, 'appid') ??
            (segments.length > 1 && segments.first == 'detail'
                ? segments[1]
                : null),
      ),
      store: vendor,
      url: text,
    );
  }
  final thirdParty = _storeOf(host, thirdPartyStoreHosts);
  if (thirdParty != null) {
    return QrAppInstall(
      raw,
      source: AppSource.thirdPartyStore,
      store: thirdParty,
      url: text,
    );
  }
  return null;
}

/// market://details?id=…, samsungapps://ProductDetail/…, amzn://apps/android?p=…
QrAppInstall? parseSchemeApp(String raw, String text, String scheme) {
  final (source, store) = appSchemes[scheme]!;
  final rest = text
      .substring(scheme.length + 1)
      .replaceFirst(RegExp('^//'), '');
  final question = rest.indexOf('?');
  final path = question < 0 ? rest : rest.substring(0, question);
  final query = question < 0 ? '' : rest.substring(question + 1);
  final fromPath = path.contains('/') ? path.split('/').last : null;
  return QrAppInstall(
    raw,
    source: source,
    packageId: _package(
      queryParameter(query, 'id') ?? queryParameter(query, 'p') ?? fromPath,
    ),
    store: store,
  );
}

/// intent://…#Intent;package=com.exemple;end : l'app visée, sinon null.
QrAppInstall? parseIntentApp(String raw, String text) {
  final match = RegExp(
    r'[#;]package=([^;#]+)',
    caseSensitive: false,
  ).firstMatch(text);
  final packageId = _package(match == null ? null : decodeComponent(match[1]!));
  if (packageId == null) return null;
  return QrAppInstall(raw, source: AppSource.intent, packageId: packageId);
}

String? _storeOf(String host, Map<String, String> stores) {
  for (final MapEntry(key: domain, value: name) in stores.entries) {
    if (host == domain || host.endsWith('.$domain')) return name;
  }
  return null;
}

// Nom de paquet Android : au moins deux parties, lettres, chiffres et _.
final _packagePattern = RegExp(
  r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$',
);

String? _package(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty || text.length > 255) return null;
  return text;
}

/// Ce que Sentinel sait d'un nom de paquet.
enum PackageVerdict {
  official, // paquet officiel d'une app connue
  knownMod, // version modifiée connue (GB WhatsApp…)
  imitation, // ressemble au nom d'une app connue, sans être le vrai
  invalid, // pas un nom de paquet Android valide
  unknown, // rien à dire
}

/// Verdict et app concernée (« WhatsApp »).
class PackageCheck {
  const PackageCheck(this.verdict, [this.brand]);

  final PackageVerdict verdict;
  final String? brand;
}

/// Éditeurs officiels : leurs paquets commencent par ces préfixes
/// (Facebook Lite = com.facebook.lite, YouTube Music = com.google…).
const _trustedPrefixes = {
  'WhatsApp': ['com.whatsapp'],
  'WhatsApp Business': ['com.whatsapp'],
  'Facebook': ['com.facebook'],
  'Messenger': ['com.facebook'],
  'Instagram': ['com.instagram', 'com.facebook'],
  'TikTok': ['com.zhiliaoapp', 'com.ss.android'],
  'Telegram': ['org.telegram'],
  'Snapchat': ['com.snapchat'],
  'YouTube': ['com.google'],
  'Gmail': ['com.google'],
  'Google Pay': ['com.google'],
};

/// Mots trop courants pour accuser une imitation (« messenger »…).
const _genericNames = {'messenger', 'facebookmessenger', 'gpay', 'wabusiness'};

/// Compare [packageId] à la base des apps connues (known_apps.dart).
PackageCheck checkPackage(
  String packageId, {
  List<KnownApp> known = knownApps,
  List<ModdedApp> mods = knownModdedApps,
}) {
  if (!_packagePattern.hasMatch(packageId)) {
    return const PackageCheck(PackageVerdict.invalid);
  }
  final id = packageId.toLowerCase();
  for (final mod in mods) {
    if (mod.packages.contains(id)) {
      return PackageCheck(PackageVerdict.knownMod, mod.of);
    }
  }
  for (final app in known) {
    if (app.officialPackages.contains(id)) {
      return PackageCheck(PackageVerdict.official, app.name);
    }
  }
  for (final app in known) {
    if (app.officialPackages.isEmpty) continue; // emplacement à compléter
    final trusted = _trustedPrefixes[app.name] ?? app.officialPackages;
    if (trusted.any((p) => id == p || id.startsWith('$p.'))) continue;
    for (final name in app.displayNames) {
      if (_genericNames.contains(name) || name.length < 5) continue;
      if (_imitates(id, name)) {
        return PackageCheck(PackageVerdict.imitation, app.name);
      }
    }
  }
  return const PackageCheck(PackageVerdict.unknown);
}

// « com.whatsapp.update », « com.whatsap.pro », « com.vvhatsapp »…
bool _imitates(String packageId, String name) {
  for (final part in packageId.split(RegExp('[._]'))) {
    final letters = _deceptive(part);
    if (letters.contains(name)) return true;
    if (name.length >= 6 &&
        (letters.length - name.length).abs() <= 1 &&
        _oneEditAway(letters, name)) {
      return true;
    }
  }
  return false;
}

// Lettres qui se ressemblent : vv → w, rn → m, 0 → o, 1 → l.
String _deceptive(String text) => text
    .replaceAll('vv', 'w')
    .replaceAll('rn', 'm')
    .replaceAll('0', 'o')
    .replaceAll('1', 'l')
    .replaceAll(RegExp('[^a-z]'), '');

// Une lettre ajoutée, retirée ou changée.
bool _oneEditAway(String a, String b) {
  if (a == b) return false;
  if (a.length < b.length) return _oneEditAway(b, a);
  var i = 0;
  var j = 0;
  var edits = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      i++;
      j++;
      continue;
    }
    if (++edits > 1) return false;
    if (a.length == b.length) j++;
    i++;
  }
  return edits + (a.length - i) + (b.length - j) <= 1;
}
