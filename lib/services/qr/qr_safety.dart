import '../../l10n/l10n.dart';
import '../../models/wifi_status.dart';
import '../apps/known_apps.dart';
import '../links/link_checker.dart';
import '../phishing/known_brands.dart';
import 'qr_apps.dart';
import 'qr_content.dart';
import 'scam_words.dart';

/// Gravité d'un avertissement propre aux QR codes.
enum QrSeverity {
  danger, // « Dangereux », action interdite
  prudence, // au moins « Suspect »
  info, // à lire, ne change pas le verdict
}

/// Avertissements propres aux QR codes (en plus de la vérification du lien).
enum QrWarning {
  lienDangereux(QrSeverity.danger), // javascript:, intent:, file:…
  codeUssd(QrSeverity.danger), // * ou # dans un numéro à appeler
  numeroCourt(QrSeverity.prudence), // SMS vers un numéro court
  paiement(QrSeverity.info), // vérifier bénéficiaire et montant
  wifiOuvert(QrSeverity.info), // réseau sans mot de passe
  wifiWep(QrSeverity.info), // protection cassée depuis longtemps
  crypto(QrSeverity.prudence), // adresse de cryptomonnaie
  messageArnaque(QrSeverity.prudence), // code, mot de passe, paiement…
  numeroSpecial(QrSeverity.prudence), // +882, +979… souvent surtaxé
  numeroInattendu(QrSeverity.prudence), // pays rare pour un QR en Tunisie
  numeroEtranger(QrSeverity.info), // étranger, mais courant
  groupe(QrSeverity.info), // invitation dans un groupe
  apkDirect(QrSeverity.danger), // fichier .apk hors Play Store
  intentApp(QrSeverity.danger), // intent:// qui lance une app
  paquetModifie(QrSeverity.danger), // GB WhatsApp…
  paquetImite(QrSeverity.danger), // faux paquet, hors Play Store
  paquetImiteStore(QrSeverity.prudence), // faux paquet sur une boutique
  paquetInvalide(QrSeverity.prudence), // nom de paquet impossible
  paquetOfficiel(QrSeverity.info), // le vrai paquet d'une app connue
  paquetInconnu(QrSeverity.info), // vérifier l'éditeur
  boutiqueTierce(QrSeverity.prudence), // APKPure, Uptodown…
  boutiqueFabricant(QrSeverity.info), // Galaxy Store, AppGallery…
  contactMarque(QrSeverity.prudence), // fiche « BIAT », « Ooredoo »…
  contactService(QrSeverity.prudence); // fiche « Service client »

  const QrWarning(this.severity);

  final QrSeverity severity;

  /// Texte sans détail (nom de marque, indicatif…). Préférer
  /// [QrFinding.reason], qui les ajoute.
  String reason(AppLocalizations l) => QrFinding(this).reason(l);
}

/// Un avertissement et son détail : marque, indicatif, mots trouvés…
class QrFinding {
  const QrFinding(this.warning, [this.detail = '']);

  final QrWarning warning;
  final String detail;

  QrSeverity get severity => warning.severity;

  String reason(AppLocalizations l) => switch (warning) {
    QrWarning.lienDangereux => l.qrWarningUnsafeLink,
    QrWarning.codeUssd => l.qrWarningUssd,
    QrWarning.numeroCourt => l.qrWarningShortNumber,
    QrWarning.paiement => l.qrWarningPayment,
    QrWarning.wifiOuvert => l.qrWarningWifiOpen,
    QrWarning.wifiWep => l.qrWarningWifiWep,
    QrWarning.crypto => l.qrWarningCrypto,
    QrWarning.messageArnaque => l.qrWarningScamText(detail),
    QrWarning.numeroSpecial => l.qrWarningSpecialNumber(detail),
    QrWarning.numeroInattendu => l.qrWarningUnexpectedCountry(detail),
    QrWarning.numeroEtranger => l.qrWarningForeignNumber(detail),
    QrWarning.groupe => l.qrWarningGroup,
    QrWarning.apkDirect => l.qrWarningApk,
    QrWarning.intentApp => l.qrWarningIntentApp,
    QrWarning.paquetModifie => l.qrWarningPackageMod(detail),
    QrWarning.paquetImite ||
    QrWarning.paquetImiteStore => l.qrWarningPackageImitation(detail),
    QrWarning.paquetInvalide => l.qrWarningPackageInvalid,
    QrWarning.paquetOfficiel => l.qrWarningPackageOfficial(detail),
    QrWarning.paquetInconnu => l.qrWarningPackageUnknown,
    QrWarning.boutiqueTierce => l.qrWarningThirdPartyStore(detail),
    QrWarning.boutiqueFabricant => l.qrWarningVendorStore(detail),
    QrWarning.contactMarque => l.qrWarningContactBrand(detail),
    QrWarning.contactService => l.qrWarningContactService,
  };
}

/// Grandes familles de contenu, pour l'affichage.
enum QrKind {
  link,
  unsafeLink,
  messaging,
  app,
  wifi,
  contact,
  email,
  geo,
  crypto,
  payment,
  event,
  phone,
  sms,
  text,
}

QrKind qrKindOf(QrContent content) => switch (content) {
  QrLink() => QrKind.link,
  QrUnsafeLink() => QrKind.unsafeLink,
  QrMessaging() => QrKind.messaging,
  QrAppInstall() => QrKind.app,
  QrWifi() => QrKind.wifi,
  QrContact() => QrKind.contact,
  QrEmail() => QrKind.email,
  QrGeo() => QrKind.geo,
  QrPayment(kind: PaymentKind.crypto) => QrKind.crypto,
  QrPayment() => QrKind.payment,
  QrEvent() => QrKind.event,
  QrPhone() => QrKind.phone,
  QrSms() => QrKind.sms,
  QrText() => QrKind.text,
};

/// Ce que l'utilisateur peut faire du contenu, toujours après confirmation.
enum QrAction { ouvrirLien, appeler, envoyerSms, ouvrirPaiement }

/// Le bilan d'un QR code, prêt à afficher.
class QrAssessment {
  const QrAssessment({
    required this.content,
    this.link,
    this.findings = const [],
    this.verdict,
    this.action,
    this.actionAllowed = false,
  });

  final QrContent content;
  final LinkCheck? link; // vérification du lien trouvé, sinon null
  final List<QrFinding> findings;
  final Verdict? verdict; // null : rien à juger (numéro, Wi-Fi…)
  final QrAction? action; // null : aucune action proposée
  final bool actionAllowed; // false : bouton désactivé (lien dangereux)

  List<QrWarning> get warnings => [for (final f in findings) f.warning];

  QrKind get kind => qrKindOf(content);

  /// Le lien https à ouvrir pour [QrAction.ouvrirLien], sinon null.
  String? get openableUrl => openableUrlOf(content);

  /// Statut Wi-Fi équivalent, pour réutiliser assessWifi (wifi_risk.dart).
  WifiStatus? get wifiStatus => switch (content) {
    QrWifi(:final security) => WifiStatus(connected: true, security: security),
    _ => null,
  };
}

/// Le conseil final, selon le type de menace. Fonction pure.
/// « Aucun code ni mot de passe » reste réservé aux liens web.
String qrAdvice(AppLocalizations l, QrAssessment assessment) {
  final verdict = assessment.verdict ?? Verdict.rien;
  if (verdict == Verdict.rien) return verdict.advice(l);
  return switch (assessment.content) {
    QrAppInstall() => l.adviceApp,
    QrMessaging() => l.adviceMessaging,
    QrContact() || QrPhone() => l.adviceContact,
    QrPayment(kind: PaymentKind.crypto) => l.adviceCrypto,
    _ => verdict.advice(l),
  };
}

/// Lien web à proposer d'ouvrir (lien, messagerie ou boutique en https).
String? openableUrlOf(QrContent content) => switch (content) {
  QrLink(:final url) => url,
  QrMessaging(:final url?) => url,
  QrAppInstall(:final url?) when !url.contains(RegExp(r'\s')) => url,
  _ => null,
};

/// Le texte où chercher un lien, sinon null.
String? textToCheck(QrContent content) {
  final text = switch (content) {
    QrLink(:final url) => url,
    QrText(:final raw) => raw,
    QrSms(:final body) => body,
    QrMessaging(:final text) => text,
    QrAppInstall(:final url) => url,
    QrContact(:final url) => url,
    QrEmail(:final subject, :final body) => '$subject\n$body',
    QrEvent(:final location, :final description) => '$location\n$description',
    _ => null,
  };
  return text == null || text.trim().isEmpty ? null : text;
}

/// Domaine du lien à demander aux listes du pare-feu, sinon null.
String? hostToCheck(QrContent content) {
  final text = textToCheck(content);
  return text == null ? null : extractFirstLink(text)?.host;
}

/// Décide du verdict et de l'action. Fonction pure : [lists] est la
/// réponse du pare-feu pour [hostToCheck] (null si non consulté) ;
/// [brands] remplace les marques connues (tests).
/// Jamais d'ouverture automatique : l'action est seulement proposée.
QrAssessment assessQr(
  QrContent content, {
  DomainCheck? lists,
  List<KnownBrand>? brands,
}) {
  final text = textToCheck(content);
  final link = text == null ? null : checkText(text, lists: lists);
  final findings = _findings(content, brands);

  final judged = switch (content) {
    QrLink() || QrMessaging() || QrAppInstall() || QrContact() => true,
    QrEmail() || QrEvent() || QrPayment(kind: PaymentKind.crypto) => true,
    _ => false,
  };
  final verdict =
      _worst([
        link?.verdict,
        for (final f in findings)
          switch (f.severity) {
            QrSeverity.danger => Verdict.dangereux,
            QrSeverity.prudence => Verdict.suspect,
            QrSeverity.info => null,
          },
      ]) ??
      (judged ? Verdict.rien : null);

  final action = switch (content) {
    _ when openableUrlOf(content) != null => QrAction.ouvrirLien,
    QrPhone() => QrAction.appeler,
    QrSms() => QrAction.envoyerSms,
    QrPayment(:final uri?) => uri.isEmpty ? null : QrAction.ouvrirPaiement,
    _ => null,
  };

  return QrAssessment(
    content: content,
    link: link,
    findings: findings,
    verdict: verdict,
    action: action,
    // « Dangereux » : le bouton reste visible mais désactivé.
    actionAllowed: action != null && verdict != Verdict.dangereux,
  );
}

List<QrFinding> _findings(QrContent content, List<KnownBrand>? brands) {
  switch (content) {
    case QrUnsafeLink():
      return const [QrFinding(QrWarning.lienDangereux)];
    case QrPhone(:final number):
      if (isUssdCode(number)) return const [QrFinding(QrWarning.codeUssd)];
      return _phoneFindings([parsePhone(number)]);
    case QrSms(:final number, :final body):
      if (isUssdCode(number)) return const [QrFinding(QrWarning.codeUssd)];
      return [
        if (isShortNumber(number)) const QrFinding(QrWarning.numeroCourt),
        ..._phoneFindings([parsePhone(number)]),
        ..._scamFindings(body),
      ];
    case QrPayment(kind: PaymentKind.crypto):
      return const [QrFinding(QrWarning.crypto)];
    case QrPayment():
      return const [QrFinding(QrWarning.paiement)];
    case QrWifi(security: WifiSecurity.open):
      return const [QrFinding(QrWarning.wifiOuvert)];
    case QrWifi(security: WifiSecurity.wep):
      return const [QrFinding(QrWarning.wifiWep)];
    case QrMessaging(:final phone, :final text, :final target):
      return [
        ..._scamFindings(text),
        ..._phoneFindings([phone]),
        if (target == MessagingTarget.group) const QrFinding(QrWarning.groupe),
      ];
    case QrAppInstall():
      return _appFindings(content);
    case QrContact(:final name, :final organization, :final phones):
      return [
        ?_contactFinding('$name $organization', brands),
        ..._phoneFindings([for (final p in phones) parsePhone(p)]),
      ];
    case QrEmail(:final subject, :final body):
      return _scamFindings('$subject\n$body');
    default:
      return const [];
  }
}

List<QrFinding> _scamFindings(String text) {
  if (text.trim().isEmpty) return const [];
  final words = findScamWords(text);
  if (words.isEmpty) return const [];
  // Trois exemples suffisent pour comprendre.
  final shown = words.take(3).map((w) => '« $w »').join(', ');
  return [QrFinding(QrWarning.messageArnaque, shown)];
}

// Le numéro le plus inquiétant de la liste (un seul avertissement).
List<QrFinding> _phoneFindings(List<PhoneInfo?> phones) {
  QrFinding? worst;
  for (final phone in phones.nonNulls) {
    final code = '+${phone.countryCode}';
    final finding = switch (phone.zone) {
      PhoneZone.special => QrFinding(QrWarning.numeroSpecial, code),
      PhoneZone.unusual => QrFinding(QrWarning.numeroInattendu, code),
      PhoneZone.usual => QrFinding(QrWarning.numeroEtranger, code),
      _ => null,
    };
    if (finding == null) continue;
    if (worst == null || finding.severity.index < worst.severity.index) {
      worst = finding;
    }
  }
  return [?worst];
}

List<QrFinding> _appFindings(QrAppInstall app) {
  final findings = <QrFinding>[
    ?switch (app.source) {
      AppSource.apk => const QrFinding(QrWarning.apkDirect),
      AppSource.intent => const QrFinding(QrWarning.intentApp),
      AppSource.thirdPartyStore => QrFinding(
        QrWarning.boutiqueTierce,
        app.store ?? '',
      ),
      AppSource.vendorStore => QrFinding(
        QrWarning.boutiqueFabricant,
        app.store ?? '',
      ),
      AppSource.playStore => null,
    },
  ];
  final packageId = app.packageId;
  if (packageId == null) return findings;
  final check = checkPackage(packageId);
  // Sur une boutique contrôlée, un faux paquet est « Suspect » ; ailleurs,
  // « Dangereux ».
  final controlled =
      app.source == AppSource.playStore || app.source == AppSource.vendorStore;
  findings.add(switch (check.verdict) {
    PackageVerdict.official => QrFinding(
      QrWarning.paquetOfficiel,
      check.brand ?? '',
    ),
    PackageVerdict.knownMod => QrFinding(
      QrWarning.paquetModifie,
      check.brand ?? '',
    ),
    PackageVerdict.imitation => QrFinding(
      controlled ? QrWarning.paquetImiteStore : QrWarning.paquetImite,
      '${check.brand} (${_officialPackage(check.brand)})',
    ),
    PackageVerdict.invalid => const QrFinding(QrWarning.paquetInvalide),
    PackageVerdict.unknown => const QrFinding(QrWarning.paquetInconnu),
  });
  return findings;
}

String _officialPackage(String? brand) =>
    knownApps
        .where((a) => a.name == brand)
        .expand((a) => a.officialPackages)
        .firstOrNull ??
    '';

/// Mots qui font passer une fiche contact pour un service officiel.
const _serviceWords = [
  'service client',
  'service clients',
  'service clientele',
  'support',
  'assistance',
  'customer service',
  'customer care',
  'customer support',
  'help desk',
  'helpdesk',
  'banque',
  'bank',
  'خدمه العملاء',
  'خدمه الحرفاء',
  'مصلحه الحرفاء',
  'الدعم الفني',
  'بنك',
  'البنك',
];

/// La marque qu'une fiche contact prétend être (banque, opérateur, app),
/// ou un « service client » sans marque. null : rien de suspect.
QrFinding? _contactFinding(String name, List<KnownBrand>? brands) {
  final brand = brandInName(name, brands: brands);
  if (brand != null) return QrFinding(QrWarning.contactMarque, brand);
  final normalized = ' ${normalizeForScan(name)} ';
  if (_serviceWords.any((w) => normalized.contains(' $w '))) {
    return const QrFinding(QrWarning.contactService);
  }
  return null;
}

/// Nom de la marque connue citée dans [name] (« Service client BIAT »
/// → « BIAT »), sinon null. Marques de known_brands.json et apps connues.
String? brandInName(String name, {List<KnownBrand>? brands}) {
  final tokens = normalizeForScan(name).split(' ').where((t) => t.isNotEmpty);
  final joined = tokens.join();
  List<KnownBrand> list;
  try {
    list = brands ?? knownBrands;
  } on StateError {
    list = const []; // marques pas encore chargées
  }
  for (final brand in list) {
    for (final keyword in brand.keywords) {
      final hit = keyword.length < 5
          ? tokens.contains(keyword)
          : tokens.any((t) => t.startsWith(keyword) || t.endsWith(keyword));
      if (hit) return brand.name;
    }
  }
  for (final app in knownApps) {
    for (final display in app.displayNames) {
      if (display.length >= 5 && joined.contains(display)) return app.name;
    }
  }
  return null;
}

/// * ou # dans un numéro : code USSD (renvoi d'appel, effacement…).
bool isUssdCode(String number) => number.contains(RegExp('[*#]'));

/// Numéro court (6 chiffres ou moins) : souvent surtaxé.
bool isShortNumber(String number) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  return digits.isNotEmpty && digits.length <= 6;
}

// Le verdict le plus grave (l'énumération va du pire au meilleur).
Verdict? _worst(List<Verdict?> verdicts) {
  Verdict? worst;
  for (final v in verdicts) {
    if (v != null && (worst == null || v.index < worst.index)) worst = v;
  }
  return worst;
}
