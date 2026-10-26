import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/phishing/known_brands.dart';
import '../services/phishing/message_analyzer.dart';
import '../services/phishing/phishing_model.dart';
import '../services/apps_scanner_service.dart';
import '../services/qr/qr_scanner_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auto_protection_section.dart';
import '../widgets/verdict_section.dart';
import 'qr_result_screen.dart';

/// Onglet « Messages » : l'utilisateur colle un SMS ou un lien,
/// l'IA et les règles sur les liens disent s'il s'agit d'une arnaque.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.sharedText});

  /// Texte reçu d'une autre app : il est collé puis analysé tout seul.
  final ValueListenable<SharedText?>? sharedText;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _controller = TextEditingController();

  final _qr = QrScannerService();
  bool _scanning = false;
  bool _analyzing = false;
  bool _failed = false; // le modèle n'a pas pu être chargé
  MessageAnalysis? _analysis;

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.sharedText?.addListener(_onShared);
  }

  @override
  void didUpdateWidget(MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sharedText != widget.sharedText) {
      oldWidget.sharedText?.removeListener(_onShared);
      widget.sharedText?.addListener(_onShared);
    }
  }

  @override
  void dispose() {
    widget.sharedText?.removeListener(_onShared);
    _controller.dispose();
    super.dispose();
  }

  // Un texte arrive d'une autre app : on le met dans le champ et on analyse.
  void _onShared() {
    final shared = widget.sharedText?.value;
    if (shared == null) return;
    _controller.text = shared.text;
    _onTextChanged(shared.text);
    _analyze();
  }

  // Le texte a changé : l'ancien résultat ne correspond plus.
  void _onTextChanged(String _) {
    setState(() {
      _analysis = null;
      _failed = false;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    _controller.text = text;
    _onTextChanged(text);
  }

  void _clear() {
    _controller.clear();
    _onTextChanged('');
  }

  /// Tout se passe sur le téléphone : rien n'est envoyé sur Internet.
  Future<void> _analyze() async {
    FocusScope.of(context).unfocus(); // ferme le clavier
    final text = _controller.text;
    setState(() => _analyzing = true);
    try {
      final model = await loadPhishingModel();
      await loadKnownBrands();
      final analysis = analyzeMessage(text, model.predict(text));
      // Le texte a changé entre-temps (nouveau partage) : résultat périmé.
      if (!mounted || _controller.text != text) return;
      setState(() => _analysis = analysis);
    } catch (_) {
      // Modèle introuvable ou illisible.
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  /// Scan d'un QR code : explication avant la première demande de caméra,
  /// puis écran de résultat. Rien n'est ouvert sans l'utilisateur.
  Future<void> _scanQr() async {
    final l = context.l10n;
    if (!await _qr.hasCameraPermission()) {
      if (!mounted || !await _explainCamera()) return;
    }
    setState(() => _scanning = true);
    final result = await _qr.scan(l.qrScanPrompt);
    if (!mounted) return;
    setState(() => _scanning = false);
    final error = result.error;
    final text = result.text;
    if (error != null) {
      _showScanError(error);
    } else if (text != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => QrResultScreen(raw: text)),
      );
    }
  }

  // Pourquoi la caméra, avant la demande d'Android. true : continuer.
  Future<bool> _explainCamera() async {
    final l = context.l10n;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.chaux,
        surfaceTintColor: Colors.transparent,
        title: Text(l.qrCameraTitle),
        content: Text(l.qrCameraText),
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
    return accepted == true;
  }

  void _showScanError(QrScanError error) {
    final l = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.message(l)),
        // Refus définitif : seuls les réglages d'Android peuvent le changer.
        action: error == QrScanError.permissionBlocked
            ? SnackBarAction(
                label: l.qrOpenSettings,
                onPressed: () =>
                    AppsScannerService().openAppSettings('com.iheb.sentinel'),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final analysis = _analysis;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
              children: [
                Text(
                  l.navMessages,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: context.colors.encre,
                  ),
                ),
                const SizedBox(height: 16),
                // Masquée hors Android (rien ne s'affiche).
                const AutoProtectionSection(),
                const SizedBox(height: 8),
                _QrScanRow(onTap: _scanning ? null : _scanQr),
                const SizedBox(height: 20),
                _MessageField(
                  controller: _controller,
                  onChanged: _onTextChanged,
                ),
                const SizedBox(height: 8),
                _actions(l),
                if (_analyzing)
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
                      style: TextStyle(
                        fontSize: 15,
                        color: context.colors.secondaire,
                      ),
                    ),
                  ),
                if (analysis != null && !_analyzing)
                  VerdictSection(
                    verdict: analysis.verdict,
                    subtitle: l.messagesProbability('${analysis.percent}'),
                    reasons: analysis.reasons(l),
                    advice: analysis.advice(l),
                  ),
              ],
            ),
          ),
          // Rappel discret, toujours visible.
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
            child: Text(
              l.messagesLocalNote,
              style: TextStyle(fontSize: 12, color: context.colors.discret),
            ),
          ),
        ],
      ),
    );
  }

  /// « Coller » à gauche ; « Effacer » et « Analyser » à droite.
  Widget _actions(AppLocalizations l) {
    return Row(
      children: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: context.colors.bleu),
          onPressed: _paste,
          child: Text(l.messagesPaste),
        ),
        const Spacer(),
        if (_controller.text.isNotEmpty)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.secondaire,
            ),
            onPressed: _clear,
            child: Text(l.messagesClear),
          ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: context.colors.bleu),
          // null = bouton désactivé (champ vide ou analyse en cours).
          onPressed: _hasText && !_analyzing ? _analyze : null,
          child: Text(l.messagesAnalyze),
        ),
      ],
    );
  }
}

/// Champ multiligne avec bordure fine, bleue quand on écrit dedans.
class _MessageField extends StatelessWidget {
  const _MessageField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color),
      );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: 4,
      maxLines: 8,
      keyboardType: TextInputType.multiline,
      style: TextStyle(fontSize: 15, color: context.colors.encre),
      decoration: InputDecoration(
        hintText: context.l10n.messagesHint,
        hintStyle: TextStyle(fontSize: 15, color: context.colors.discret),
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: _border(context.colors.ligne),
        focusedBorder: _border(context.colors.bleu),
      ),
    );
  }
}

/// Ligne « Scanner un QR code », entre deux traits fins.
class _QrScanRow extends StatelessWidget {
  const _QrScanRow({required this.onTap});

  final VoidCallback? onTap; // null pendant un scan

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: context.colors.ligne),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner, color: context.colors.bleu),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.qrScanButton,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: context.colors.bleu,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.qrScanSubtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.secondaire,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: context.colors.ligne),
      ],
    );
  }
}
