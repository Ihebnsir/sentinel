import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/firewall_service.dart';
import '../services/links/link_checker.dart';
import '../services/phishing/known_brands.dart';
import '../services/qr/qr_content.dart';
import '../services/qr/qr_safety.dart';
import '../services/qr/qr_scanner_service.dart';
import '../services/weekly_report_service.dart';
import '../services/wifi_risk.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_bar.dart';
import '../widgets/verdict_section.dart';
import '../widgets/wifi_section.dart';
import '../utils/bidi.dart';
import '../widgets/ui.dart';

/// Demande aux listes du pare-feu ce qu'elles savent d'un domaine.
typedef DomainChecker = Future<DomainCheck?> Function(String host);

/// Résultat d'un QR code : contenu brut, détails, verdict, et une action
/// proposée (jamais lancée sans confirmation de l'utilisateur).
/// Toute l'analyse est faite par lib/services/qr : l'écran affiche.
class QrResultScreen extends StatefulWidget {
  const QrResultScreen({
    super.key,
    required this.raw,
    this.checkDomain,
    this.service,
    this.fromCamera = false,
    this.tipIndex,
  });

  final String raw; // texte lu dans le QR code
  final DomainChecker? checkDomain; // remplacé dans les tests
  final QrScannerService? service;

  /// Scan à la caméra : un conseil « quishing » discret est ajouté.
  final bool fromCamera;

  /// Conseil à afficher (tests) ; sinon le suivant, à tour de rôle.
  final int? tipIndex;

  @override
  State<QrResultScreen> createState() => _QrResultScreenState();
}

/// Conseils contre les faux QR codes (« quishing »), à tour de rôle.
List<String> quishingTips(AppLocalizations l) => [
  l.qrTipPoster,
  l.qrTipSmsCode,
  l.qrTipParcel,
  l.qrTipPayment,
];

// Compteur en mémoire seulement : rien n'est enregistré.
int _nextTip = 0;

class _QrResultScreenState extends State<QrResultScreen> {
  late final QrContent _content = parseQr(widget.raw);
  late final QrScannerService _service = widget.service ?? QrScannerService();
  late final int _tip = widget.tipIndex ?? _nextTip++;
  QrAssessment? _assessment;
  bool _failed = false; // les marques connues n'ont pas pu être lues

  @override
  void initState() {
    super.initState();
    _assess();
  }

  // Tout se passe sur le téléphone : rien n'est envoyé sur Internet.
  Future<void> _assess() async {
    try {
      await loadKnownBrands();
      final host = hostToCheck(_content);
      final lists = host == null
          ? null
          : await (widget.checkDomain ?? FirewallService().checkDomain)(host);
      final assessment = assessQr(_content, lists: lists);
      // Bilan de la semaine : un compteur, jamais le lien.
      if (assessment.link != null) {
        unawaited(const WeeklyReportService().count(WeeklyCounter.linksChecked));
      }
      if (mounted) setState(() => _assessment = assessment);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  // Confirmation, puis action. Rien ne s'ouvre sans « Continuer ».
  Future<void> _onAction(QrAssessment assessment) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_actionTitle(l, assessment)),
        content: Text(_confirmText(l, assessment)),
        actions: [
          TextButton(
            style: mutedButtonStyle(context),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.commonContinue),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final done = await _service.perform(assessment);
    if (!done && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.qrActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final assessment = _assessment;
    final muted = context.colors.secondaire;
    final tips = quishingTips(l);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.chaux,
        foregroundColor: context.colors.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xxl),
          children: [
            Text(
              l.qrResultTitle,
              style: TextStyle(
                fontSize: AppText.titreSecondaire,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              qrKindLabel(l, _content),
              style: TextStyle(fontSize: AppText.corps, color: muted),
            ),
            const SizedBox(height: AppSpace.xl),
            Text(l.qrRawContent, style: TextStyle(fontSize: AppText.detail, color: muted)),
            const SizedBox(height: AppSpace.sm),
            _RawContent(raw: widget.raw),
            const SizedBox(height: AppSpace.md),
            for (final detail in qrDetails(l, _content)) _InfoRow(detail: detail),
            if (assessment == null && !_failed)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xl),
                child: LoadingBar(label: context.l10n.homeAnalyzing),
              ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xl),
                child: Text(
                  l.linksFailed,
                  style: TextStyle(fontSize: AppText.corps, color: muted),
                ),
              ),
            if (assessment != null) ..._result(l, assessment),
            if (widget.fromCamera) ...[
              const SizedBox(height: AppSpace.xl),
              // Conseil discret, différent à chaque scan.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: AppSize.iconSmall, color: muted),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      tips[_tip % tips.length],
                      style: TextStyle(fontSize: AppText.detail, color: muted),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _result(AppLocalizations l, QrAssessment assessment) {
    final link = assessment.link;
    final verdict = assessment.verdict;
    final wifi = assessment.wifiStatus;
    final reasons = [
      for (final f in assessment.findings) f.reason(l),
      ...?link?.reasons(l),
    ];
    final action = assessment.action;
    return [
      if (wifi != null) _WifiBlock(report: assessWifi(l, wifi)),
      if (verdict != null)
        VerdictSection(
          verdict: verdict,
          subtitle: link == null
              ? null
              : l.linksRealDestination(link.realDestination),
          reasons: reasons,
          advice: qrAdvice(l, assessment),
          note: link?.notListed == true ? l.linkNoteNotListed : null,
        )
      else
        // Pas de verdict (Wi-Fi, paiement…) : avertissements seuls.
        for (final reason in reasons) ...[
          const SizedBox(height: AppSpace.md),
          Text(
            reason,
            style: TextStyle(
              fontSize: AppText.corps,
              fontWeight: FontWeight.w500,
              color: context.colors.encre,
            ),
          ),
        ],
      if (action != null) ...[
        const SizedBox(height: AppSpace.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            // null : désactivé (lien dangereux).
            onPressed: assessment.actionAllowed
                ? () => _onAction(assessment)
                : null,
            child: Text(_actionTitle(l, assessment)),
          ),
        ),
        if (!assessment.actionAllowed)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Text(
              l.qrActionBlocked,
              style: TextStyle(fontSize: AppText.detail, color: context.colors.secondaire),
            ),
          ),
      ],
    ];
  }
}

/// Texte du bouton d'action.
String _actionTitle(AppLocalizations l, QrAssessment assessment) =>
    switch (assessment.action) {
      QrAction.ouvrirLien when assessment.verdict == Verdict.rien =>
        l.qrActionOpenLink,
      QrAction.ouvrirLien => l.qrActionOpenAnyway,
      QrAction.appeler => l.qrActionCall,
      QrAction.envoyerSms => l.qrActionSms,
      QrAction.ouvrirPaiement => l.qrActionPayment,
      null => '',
    };

/// Ce qui va se passer, écrit en clair dans la confirmation.
String _confirmText(AppLocalizations l, QrAssessment assessment) {
  final url = assessment.openableUrl;
  if (url != null) return l.qrConfirmLink(url);
  return switch (assessment.content) {
    QrPhone(:final number) => l.qrConfirmCall(number),
    QrSms(:final number) => l.qrConfirmSms(number),
    QrPayment(:final recipient) => l.qrConfirmPayment(recipient),
    _ => '',
  };
}

/// Type de contenu, ex : « Réseau Wi-Fi ».
String qrKindLabel(AppLocalizations l, QrContent content) =>
    switch (qrKindOf(content)) {
      QrKind.link => l.qrKindLink,
      QrKind.unsafeLink => l.qrKindUnsafeLink,
      QrKind.messaging => l.qrKindMessaging,
      QrKind.app => l.qrKindApp,
      QrKind.wifi => l.qrKindWifi,
      QrKind.contact => l.qrKindContact,
      QrKind.email => l.qrKindEmail,
      QrKind.geo => l.qrKindGeo,
      QrKind.crypto => l.qrKindCrypto,
      QrKind.payment => l.qrKindPayment,
      QrKind.event => l.qrKindEvent,
      QrKind.phone => l.qrKindPhone,
      QrKind.sms => l.qrKindSms,
      QrKind.text => l.qrKindText,
    };

/// Icône du type de contenu (liste de plusieurs QR codes).
IconData qrKindIcon(QrContent content) => switch (qrKindOf(content)) {
  QrKind.link || QrKind.unsafeLink => Icons.link,
  QrKind.messaging => Icons.chat_bubble_outline,
  QrKind.app => Icons.get_app,
  QrKind.wifi => Icons.wifi,
  QrKind.contact => Icons.person_outline,
  QrKind.email => Icons.mail_outline,
  QrKind.geo => Icons.place_outlined,
  QrKind.crypto || QrKind.payment => Icons.payments_outlined,
  QrKind.event => Icons.event_outlined,
  QrKind.phone => Icons.call_outlined,
  QrKind.sms => Icons.sms_outlined,
  QrKind.text => Icons.notes,
};

/// Une ligne de détail : libellé, valeur, et un badge éventuel
/// (indicatif du pays : couleur + icône + texte).
class QrDetail {
  const QrDetail(this.label, this.value, {this.badge, this.badgeLevel});

  final String label;
  final String value;
  final String? badge;
  final StatusLevel? badgeLevel;
}

const _appNames = {
  MessagingApp.whatsapp: 'WhatsApp',
  MessagingApp.telegram: 'Telegram',
  MessagingApp.messenger: 'Messenger',
  MessagingApp.viber: 'Viber',
};

String _targetLabel(AppLocalizations l, MessagingTarget target) =>
    switch (target) {
      MessagingTarget.person => l.qrTargetPerson,
      MessagingTarget.group => l.qrTargetGroup,
      MessagingTarget.channel => l.qrTargetChannel,
      MessagingTarget.bot => l.qrTargetBot,
      MessagingTarget.share => l.qrTargetShare,
    };

/// Numéro avec son indicatif mis en évidence : badge vert pour la
/// Tunisie, ocre pour l'étranger inattendu ou spécial.
/// [shown] : le numéro tel qu'écrit dans le QR code (sinon nettoyé).
QrDetail _phoneDetail(
  AppLocalizations l,
  String label,
  PhoneInfo phone, [
  String? shown,
]) {
  final code = phone.countryCode;
  final value = shown ?? phone.number;
  if (code == null) return QrDetail(label, value);
  final (zone, level) = switch (phone.zone) {
    PhoneZone.home => (l.qrZoneHome, StatusLevel.ok),
    PhoneZone.usual => (l.qrZoneForeign, StatusLevel.neutral),
    PhoneZone.unusual => (l.qrZoneForeign, StatusLevel.warning),
    PhoneZone.special => (l.qrZoneSpecial, StatusLevel.warning),
    PhoneZone.unknown => (l.qrZoneForeign, StatusLevel.neutral),
  };
  return QrDetail(
    label,
    value,
    badge: '+$code · $zone',
    badgeLevel: level,
  );
}

String _sourceLabel(AppLocalizations l, QrAppInstall app) =>
    app.store ??
    switch (app.source) {
      AppSource.apk => l.qrAppSourceApk,
      AppSource.intent => l.qrAppSourceIntent,
      _ => l.qrAppSourceUnknownSite,
    };

/// Détails lisibles selon le type.
List<QrDetail> qrDetails(AppLocalizations l, QrContent content) =>
    switch (content) {
      QrWifi(:final ssid, :final security, :final hasPassword) => [
        QrDetail(l.qrWifiName, ssid),
        QrDetail(l.qrWifiSecurity, security.label(l)),
        QrDetail(
          l.qrWifiPassword,
          hasPassword ? l.qrWifiPasswordYes : l.qrWifiPasswordNo,
        ),
      ],
      QrPhone(:final number) => [
        switch (parsePhone(number)) {
          final phone? => _phoneDetail(l, l.qrPhoneNumber, phone, number),
          null => QrDetail(l.qrPhoneNumber, number),
        },
      ],
      QrSms(:final number, :final body) => [
        switch (parsePhone(number)) {
          final phone? => _phoneDetail(l, l.qrSmsRecipient, phone, number),
          null => QrDetail(l.qrSmsRecipient, number),
        },
        if (body.isNotEmpty) QrDetail(l.qrSmsText, body),
      ],
      QrPayment(:final recipient, :final amount, :final currency) => [
        QrDetail(
          l.qrPaymentRecipient,
          recipient.isEmpty ? l.qrNotSpecified : recipient,
        ),
        QrDetail(
          l.qrPaymentAmount,
          amount == null ? l.qrNotSpecified : '$amount ${currency ?? ''}'.trim(),
        ),
      ],
      QrMessaging(
        :final app,
        :final target,
        :final phone,
        :final handle,
        :final text,
      ) =>
        [
          QrDetail(l.qrMessagingApp, _appNames[app]!),
          QrDetail(l.qrMessagingTarget, _targetLabel(l, target)),
          if (phone != null) _phoneDetail(l, l.qrMessagingNumber, phone),
          if (handle != null && handle.isNotEmpty)
            QrDetail(l.qrMessagingAccount, handle),
          if (text.isNotEmpty) QrDetail(l.qrMessagingText, text),
        ],
      QrAppInstall(:final packageId) => [
        QrDetail(l.qrAppStore, _sourceLabel(l, content)),
        if (packageId != null) QrDetail(l.qrAppPackage, packageId),
      ],
      QrContact(
        :final name,
        :final organization,
        :final phones,
        :final emails,
        :final url,
      ) =>
        [
          if (name.isNotEmpty) QrDetail(l.qrContactName, name),
          if (organization.isNotEmpty)
            QrDetail(l.qrContactOrganization, organization),
          for (final p in phones)
            switch (parsePhone(p)) {
              final phone? => _phoneDetail(l, l.qrContactPhone, phone, p),
              null => QrDetail(l.qrContactPhone, p),
            },
          for (final e in emails) QrDetail(l.qrContactEmail, e),
          if (url != null && url.isNotEmpty) QrDetail(l.qrContactWebsite, url),
        ],
      QrEmail(:final address, :final subject, :final body) => [
        QrDetail(l.qrEmailTo, address),
        if (subject.isNotEmpty) QrDetail(l.qrEmailSubject, subject),
        if (body.isNotEmpty) QrDetail(l.qrEmailBody, body),
      ],
      QrGeo(:final latitude, :final longitude, :final label) => [
        QrDetail(l.qrGeoCoordinates, '$latitude, $longitude'),
        if (label.isNotEmpty) QrDetail(l.qrGeoLabel, label),
      ],
      QrEvent(
        :final summary,
        :final start,
        :final end,
        :final location,
        :final description,
      ) =>
        [
          if (summary.isNotEmpty) QrDetail(l.qrEventTitle, summary),
          if (start.isNotEmpty) QrDetail(l.qrEventStart, start),
          if (end.isNotEmpty) QrDetail(l.qrEventEnd, end),
          if (location.isNotEmpty) QrDetail(l.qrEventLocation, location),
          if (description.isNotEmpty)
            QrDetail(l.qrEventDescription, description),
        ],
      _ => const [],
    };

/// Le texte brut dans un cadre fin, sélectionnable (copier à la main).
class _RawContent extends StatelessWidget {
  const _RawContent({required this.raw});

  final String raw;

  // Un contenu énorme n'est pas affiché en entier (écran figé sinon).
  static const _maxShown = 2000;

  @override
  Widget build(BuildContext context) {
    final empty = raw.trim().isEmpty;
    final shown = raw.length > _maxShown ? '${raw.substring(0, _maxShown)}…' : raw;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.ligne),
        borderRadius: AppRadius.field,
      ),
      // Sens du contenu (un lien reste de gauche à droite en arabe),
      // sans caractère caché : la copie reste fidèle.
      child: SelectableText(
        empty ? context.l10n.qrEmpty : shown,
        textDirection: empty ? null : directionOf(shown),
        textAlign: pageStart(context),
        style: TextStyle(
          fontSize: AppText.corps,
          color: empty ? context.colors.discret : context.colors.encre,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.detail});

  final QrDetail detail;

  @override
  Widget build(BuildContext context) {
    final value = detail.value;
    final badge = detail.badge;
    final level = detail.badgeLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  detail.label,
                  style: TextStyle(
                    fontSize: AppText.corps,
                    color: context.colors.secondaire,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      // Sens du contenu : « +216… » garde son « + » à gauche.
                      textDirection: directionOf(value),
                      textAlign: pageStart(context),
                      maxLines: 12,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: AppText.corps, color: context.colors.encre),
                    ),
                    if (badge != null && level != null) ...[
                      const SizedBox(height: AppSpace.xs),
                      StatusBadge(level: level, label: badge),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Niveau du Wi-Fi (mêmes règles que l'accueil, wifi_risk.dart).
class _WifiBlock extends StatelessWidget {
  const _WifiBlock({required this.report});

  final WifiReport report;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final body = TextStyle(
      fontSize: AppText.corps,
      height: AppText.interligne,
      color: context.colors.secondaire,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppDivider(),
        const SizedBox(height: AppSpace.xl),
        VerdictHeader(
          level: wifiStatus(report.level),
          label: report.level.label(l),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          report.title,
          style: TextStyle(
            fontSize: AppText.intitule,
            fontWeight: FontWeight.w500,
            color: context.colors.encre,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(report.explanation, style: body),
        for (final advice in report.advice) ...[
          const SizedBox(height: AppSpace.sm),
          Text('· $advice', style: body),
        ],
      ],
    );
  }
}

/// Plusieurs QR codes dans une image : la liste, pour choisir lequel
/// vérifier. Rien ne s'ouvre tout seul.
class QrChoiceScreen extends StatelessWidget {
  const QrChoiceScreen({super.key, required this.codes, this.checkDomain});

  final List<String> codes;
  final DomainChecker? checkDomain;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.chaux,
        foregroundColor: context.colors.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xxl),
          children: [
            PageHeader(title: l.qrImageChooseTitle, subtitle: l.qrImageChooseText),
            const SizedBox(height: AppSpace.lg),
            for (final raw in codes) ...[
              const AppDivider(),
              ListRow(
                icon: qrKindIcon(parseQr(raw)),
                title: qrKindLabel(l, parseQr(raw)),
                subtitle: _preview(raw),
                subtitleMaxLines: 2,
                chevron: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        QrResultScreen(raw: raw, checkDomain: checkDomain),
                  ),
                ),
              ),
            ],
            const AppDivider(),
          ],
        ),
      ),
    );
  }

  // Début du contenu, sur une ligne.
  static String _preview(String raw) {
    final line = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return line.length > 120 ? '${line.substring(0, 120)}…' : line;
  }
}
