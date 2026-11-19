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
class QrResultScreen extends StatefulWidget {
  const QrResultScreen({
    super.key,
    required this.raw,
    this.checkDomain,
    this.service,
  });

  final String raw; // texte lu dans le QR code
  final DomainChecker? checkDomain; // remplacé dans les tests
  final QrScannerService? service;

  @override
  State<QrResultScreen> createState() => _QrResultScreenState();
}

class _QrResultScreenState extends State<QrResultScreen> {
  late final QrContent _content = parseQr(widget.raw);
  late final QrScannerService _service = widget.service ?? QrScannerService();
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
        content: Text(_confirmText(l, assessment.content)),
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
            for (final (label, value) in qrDetails(l, _content))
              _InfoRow(label: label, value: value),
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
      for (final w in assessment.warnings) w.reason(l),
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
          advice: verdict.advice(l),
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
String _confirmText(AppLocalizations l, QrContent content) => switch (content) {
  QrLink(:final url) => l.qrConfirmLink(url),
  QrPhone(:final number) => l.qrConfirmCall(number),
  QrSms(:final number) => l.qrConfirmSms(number),
  QrPayment(:final recipient) => l.qrConfirmPayment(recipient),
  _ => '',
};

/// Type de contenu, ex : « Réseau Wi-Fi ».
String qrKindLabel(AppLocalizations l, QrContent content) => switch (content) {
  QrLink() => l.qrKindLink,
  QrUnsafeLink() => l.qrKindUnsafeLink,
  QrWifi() => l.qrKindWifi,
  QrPhone() => l.qrKindPhone,
  QrSms() => l.qrKindSms,
  QrPayment() => l.qrKindPayment,
  QrText() => l.qrKindText,
};

/// Détails lisibles (libellé, valeur) selon le type.
List<(String, String)> qrDetails(
  AppLocalizations l,
  QrContent content,
) => switch (content) {
  QrWifi(:final ssid, :final security, :final hasPassword) => [
    (l.qrWifiName, ssid),
    (l.qrWifiSecurity, security.label(l)),
    (l.qrWifiPassword, hasPassword ? l.qrWifiPasswordYes : l.qrWifiPasswordNo),
  ],
  QrPhone(:final number) => [(l.qrPhoneNumber, number)],
  QrSms(:final number, :final body) => [
    (l.qrSmsRecipient, number),
    if (body.isNotEmpty) (l.qrSmsText, body),
  ],
  QrPayment(:final recipient, :final amount, :final currency) => [
    (l.qrPaymentRecipient, recipient.isEmpty ? l.qrNotSpecified : recipient),
    (
      l.qrPaymentAmount,
      amount == null ? l.qrNotSpecified : '$amount ${currency ?? ''}'.trim(),
    ),
  ],
  _ => const [],
};

/// Le texte brut dans un cadre fin, sélectionnable (copier à la main).
class _RawContent extends StatelessWidget {
  const _RawContent({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    final empty = raw.trim().isEmpty;
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
        empty ? context.l10n.qrEmpty : raw,
        textDirection: empty ? null : directionOf(raw),
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
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
                  label,
                  style: TextStyle(
                    fontSize: AppText.corps,
                    color: context.colors.secondaire,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                flex: 2,
                child: Text(
                  value,
                  // Sens du contenu : « +216… » garde son « + » à gauche.
                  textDirection: directionOf(value),
                  textAlign: pageStart(context),
                  style: TextStyle(fontSize: AppText.corps, color: context.colors.encre),
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
        Text(
          report.level.label(l),
          style: TextStyle(
            fontSize: AppText.titre,
            fontWeight: FontWeight.w600,
            color: wifiLevelColor(context.colors, report.level),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
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
