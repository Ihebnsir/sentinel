import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/phishing/message_analyzer.dart';
import '../services/report/report_client.dart';
import '../services/report/report_limiter.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_bar.dart';

/// Écran « Signaler ce message » : aperçu DÉJÀ anonymisé et modifiable,
/// avis de l'utilisateur, ce qui part (et ce qui ne part pas), envoi.
/// Renvoie true au retour si le signalement est enregistré.
class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.text,
    required this.analysis,
    required this.client,
    required this.limiter,
  });

  final String text; // message d'origine (jamais affiché tel quel)
  final MessageAnalysis analysis;
  final ReportClient client;
  final ReportLimiter limiter;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // L'aperçu montre le texte anonymisé : l'original n'apparaît jamais.
  late final _controller = TextEditingController(
    text: Report.clean(widget.text),
  );
  UserFeedback? _feedback;
  bool _sending = false;
  String? _error;

  bool get _canSend =>
      !_sending && _feedback != null && _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final feedback = _feedback;
    if (feedback == null) return;
    final l = context.l10n;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (!await widget.limiter.canSend()) {
        throw const ReportException(ReportProblem.tooMany);
      }
      await widget.client.send(
        Report(
          text: _controller.text,
          verdict: widget.analysis.verdict,
          probability: widget.analysis.probability,
          feedback: feedback,
        ),
      );
      await widget.limiter.recordSent();
      if (mounted) Navigator.of(context).pop(true);
    } on ReportException catch (e) {
      // Pas de nouvel essai automatique : l'utilisateur réessaie s'il veut.
      if (mounted) setState(() => _error = e.message(l));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = context.colors.secondaire;
    final error = _error;
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
            Semantics(
              header: true,
              child: Text(
                l.reportTitle,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: context.colors.encre,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(l.reportIntro, style: TextStyle(fontSize: 15, color: muted)),
            const SizedBox(height: 20),
            Text(
              l.reportPreviewLabel,
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 8),
            _PreviewField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              l.reportReminder,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.ocre,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l.reportQuestion,
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 4),
            for (final (value, label) in [
              (UserFeedback.arnaque, l.reportFeedbackScam),
              (UserFeedback.pasArnaque, l.reportFeedbackNotScam),
              (UserFeedback.neSaitPas, l.reportFeedbackUnsure),
            ])
              _ChoiceRow(
                label: label,
                selected: _feedback == value,
                onTap: _sending ? null : () => setState(() => _feedback = value),
              ),
            Divider(height: 1, thickness: 1, color: context.colors.ligne),
            const SizedBox(height: 24),
            _InfoBlock(title: l.reportSentTitle, text: l.reportSentText),
            _InfoBlock(
              title: l.reportWhereTitle,
              text: l.reportWhereText(widget.client.host),
            ),
            _InfoBlock(title: l.reportNotSentTitle, text: l.reportNotSentText),
            if (_sending)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LoadingBar(label: l.reportSending),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(fontSize: 15, color: context.colors.rommen),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: muted),
                  onPressed: _sending
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(l.commonCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.bleu,
                  ),
                  // null = désactivé : pas d'avis choisi ou texte vide.
                  onPressed: _canSend ? _send : null,
                  child: Text(l.reportSend),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Texte anonymisé, modifiable (bordure fine, bleue quand on écrit).
class _PreviewField extends StatelessWidget {
  const _PreviewField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('report-preview'),
      controller: controller,
      onChanged: onChanged,
      minLines: 4,
      maxLines: 10,
      maxLength: 2000, // limite du serveur
      keyboardType: TextInputType.multiline,
      style: TextStyle(fontSize: 15, color: context.colors.encre),
      decoration: InputDecoration(
        counterText: '',
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: _border(context.colors.ligne),
        focusedBorder: _border(context.colors.bleu),
      ),
    );
  }
}

/// Un choix d'avis : trait fin au-dessus, rond coché ou non.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.colors.bleu : context.colors.encre;
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: context.colors.ligne),
        Semantics(
          inMutuallyExclusiveGroup: true,
          checked: selected,
          button: true,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? context.colors.bleu
                          : context.colors.discret,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 16, color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Petit titre + texte (ce qui est envoyé, où, ce qui ne l'est pas).
class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.colors.encre,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(fontSize: 14, color: context.colors.secondaire),
          ),
        ],
      ),
    );
  }
}
