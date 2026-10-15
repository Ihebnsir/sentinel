import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/phishing/message_analyzer.dart';
import '../services/phishing/phishing_model.dart';
import '../theme/app_colors.dart';

/// Onglet « Messages » : l'utilisateur colle un SMS ou un lien,
/// l'IA et les règles sur les liens disent s'il s'agit d'une arnaque.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _controller = TextEditingController();

  bool _analyzing = false;
  bool _failed = false; // le modèle n'a pas pu être chargé
  MessageAnalysis? _analysis;

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      final analysis = analyzeMessage(text, model.predict(text));
      if (!mounted) return;
      setState(() => _analysis = analysis);
    } catch (_) {
      // Modèle introuvable ou illisible.
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
              children: [
                const Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.encre,
                  ),
                ),
                const SizedBox(height: 20),
                _MessageField(
                  controller: _controller,
                  onChanged: _onTextChanged,
                ),
                const SizedBox(height: 8),
                _actions(),
                if (_analyzing)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.bleu,
                      backgroundColor: AppColors.ligne,
                    ),
                  ),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      "L'analyse a échoué. Réessayez.",
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.encre.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                if (analysis != null && !_analyzing)
                  _AnalysisResult(analysis: analysis),
              ],
            ),
          ),
          // Rappel discret, toujours visible.
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
            child: Text(
              "L'analyse se fait sur votre téléphone. "
              "Le message n'est envoyé nulle part.",
              style: TextStyle(
                fontSize: 12,
                color: AppColors.encre.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// « Coller » à gauche ; « Effacer » et « Analyser » à droite.
  Widget _actions() {
    return Row(
      children: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.bleu),
          onPressed: _paste,
          child: const Text('Coller'),
        ),
        const Spacer(),
        if (_controller.text.isNotEmpty)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.encre.withValues(alpha: 0.6),
            ),
            onPressed: _clear,
            child: const Text('Effacer'),
          ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
          // null = bouton désactivé (champ vide ou analyse en cours).
          onPressed: _hasText && !_analyzing ? _analyze : null,
          child: const Text('Analyser'),
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
      style: const TextStyle(fontSize: 15, color: AppColors.encre),
      decoration: InputDecoration(
        hintText: 'Collez un SMS, un message WhatsApp ou un lien',
        hintStyle: TextStyle(
          fontSize: 15,
          color: AppColors.encre.withValues(alpha: 0.45),
        ),
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: _border(AppColors.ligne),
        focusedBorder: _border(AppColors.bleu),
      ),
    );
  }
}

/// Verdict en grand, probabilité, raisons séparées par des traits, conseil.
class _AnalysisResult extends StatelessWidget {
  const _AnalysisResult({required this.analysis});

  final MessageAnalysis analysis;

  static Color _colorFor(Verdict verdict) => switch (verdict) {
        Verdict.arnaque => AppColors.rommen,
        Verdict.suspect => AppColors.ocre,
        Verdict.rien => AppColors.zitouna,
      };

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.encre.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text(
          analysis.verdict.label,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: _colorFor(analysis.verdict),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Probabilité d'arnaque : ${analysis.percent} %",
          style: TextStyle(fontSize: 15, color: muted),
        ),
        const SizedBox(height: 12),
        for (final reason in analysis.reasons) ...[
          const Divider(height: 1, thickness: 1, color: AppColors.ligne),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              reason,
              style: const TextStyle(fontSize: 15, color: AppColors.encre),
            ),
          ),
        ],
        const Divider(height: 1, thickness: 1, color: AppColors.ligne),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            analysis.advice,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.encre,
            ),
          ),
        ),
      ],
    );
  }
}
