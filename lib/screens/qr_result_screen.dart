import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/phishing/known_brands.dart';
import '../services/phishing/message_analyzer.dart';
import '../services/phishing/phishing_model.dart';
import '../services/qr/qr_content.dart';
import '../services/qr/qr_safety.dart';
import '../services/qr/qr_scanner_service.dart';
import '../services/wifi_risk.dart';
import '../theme/app_colors.dart';
import '../widgets/verdict_section.dart';
import '../widgets/wifi_section.dart';

/// Charge l'IA anti-arnaque et renvoie sa fonction de prédiction.
typedef PredictorLoader =
    Future<PhishingPrediction Function(String)> Function();

/// Résultat d'un QR code : contenu brut, détails, verdict, et une action
/// proposée (jamais lancée sans confirmation de l'utilisateur).
class QrResultScreen extends StatefulWidget {
  const QrResultScreen({
    super.key,
    required this.raw,
    this.loadPredictor,
    this.service,
  });

  final String raw; // texte lu dans le QR code
  final PredictorLoader? loadPredictor; // remplacé dans les tests
  final QrScannerService? service;

  @override
  State<QrResultScreen> createState() => _QrResultScreenState();
}

class _QrResultScreenState extends State<QrResultScreen> {
  late final QrContent _content = parseQr(widget.raw);
  late final QrScannerService _service = widget.service ?? QrScannerService();
  QrAssessment? _assessment;
  bool _failed = false; // l'IA n'a pas pu être chargée

  @override
  void initState() {
    super.initState();
    _assess();
  }

  // Tout se passe sur le téléphone : rien n'est envoyé sur Internet.
  Future<void> _assess() async {
    try {
      // L'IA n'est chargée que s'il y a un lien ou un texte à analyser.
      final predict = textToAnalyze(_content) == null
          ? _noText
          : await (widget.loadPredictor ?? _loadModel)();
      final assessment = assessQr(_content, predict);
      if (mounted) setState(() => _assessment = assessment);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  static PhishingPrediction _noText(String _) =>
      throw StateError('Aucun texte à analyser');

  static Future<PhishingPrediction Function(String)> _loadModel() async {
    final model = await loadPhishingModel();
    await loadKnownBrands();
    return model.predict;
  }

  // Confirmation, puis action. Rien ne s'ouvre sans « Continuer ».
  Future<void> _onAction(QrAssessment assessment) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.chaux,
        surfaceTintColor: Colors.transparent,
        title: Text(_actionTitle(l, assessment)),
        content: Text(_confirmText(l, assessment.content)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.secondaire,
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.bleu),
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
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
          children: [
            Text(
              l.qrResultTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              qrKindLabel(l, _content),
              style: TextStyle(fontSize: 15, color: muted),
            ),
            const SizedBox(height: 20),
            Text(l.qrRawContent, style: TextStyle(fontSize: 13, color: muted)),
            const SizedBox(height: 8),
            _RawContent(raw: widget.raw),
            const SizedBox(height: 12),
            for (final (label, value) in qrDetails(l, _content))
              _InfoRow(label: label, value: value),
            if (assessment == null && !_failed)
              Padding(
                padding: EdgeInsets.only(top: 24),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: context.colors.bleu,
                  backgroundColor: context.colors.ligne,
                ),
              ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  l.messagesFailed,
                  style: TextStyle(fontSize: 15, color: muted),
                ),
              ),
            if (assessment != null) ..._result(l, assessment),
          ],
        ),
      ),
    );
  }

  List<Widget> _result(AppLocalizations l, QrAssessment assessment) {
    final analysis = assessment.analysis;
    final verdict = assessment.verdict;
    final wifi = assessment.wifiStatus;
    final reasons = [
      for (final w in assessment.warnings) w.reason(l),
      ...?analysis?.reasons(l),
    ];
    final action = assessment.action;
    return [
      if (wifi != null) _WifiBlock(report: assessWifi(l, wifi)),
      if (verdict != null)
        VerdictSection(
          verdict: verdict,
          subtitle: analysis == null
              ? null
              : l.messagesProbability('${analysis.percent}'),
          reasons: reasons,
          advice: adviceFor(l, verdict),
        )
      else
        // Pas de verdict (Wi-Fi, paiement…) : avertissements seuls.
        for (final reason in reasons) ...[
          const SizedBox(height: 12),
          Text(
            reason,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.colors.encre,
            ),
          ),
        ],
      if (action != null) ...[
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.bleu),
            // null : désactivé (arnaque probable).
            onPressed: assessment.actionAllowed
                ? () => _onAction(assessment)
                : null,
            child: Text(_actionTitle(l, assessment)),
          ),
        ),
        if (!assessment.actionAllowed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l.qrActionBlocked,
              style: TextStyle(fontSize: 13, color: context.colors.secondaire),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.ligne),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        empty ? context.l10n.qrEmpty : raw,
        style: TextStyle(
          fontSize: 14,
          color: context.colors.encre.withValues(alpha: empty ? 0.45 : 1),
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
        Divider(height: 1, thickness: 1, color: context.colors.ligne),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.colors.secondaire,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 15, color: context.colors.encre),
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
      fontSize: 15,
      height: 1.45,
      color: context.colors.encre.withValues(alpha: 0.8),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, thickness: 1, color: context.colors.ligne),
        const SizedBox(height: 20),
        Text(
          report.level.label(l),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: wifiLevelColor(context.colors, report.level),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          report.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: context.colors.encre,
          ),
        ),
        const SizedBox(height: 8),
        Text(report.explanation, style: body),
        for (final advice in report.advice) ...[
          const SizedBox(height: 6),
          Text('· $advice', style: body),
        ],
      ],
    );
  }
}
