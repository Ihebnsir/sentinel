import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../services/breach/breach_checker.dart';
import '../../services/vault/password_generator.dart';
import '../../services/vault/password_health.dart';
import '../../services/vault/vault_item.dart';
import '../../services/vault/vault_platform.dart';
import '../../services/vault/vault_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vault_copy.dart';
import '../../widgets/vault_fields.dart';

/// Détail et modification d'un élément ([item] null : nouvel élément).
/// Se ferme tout seul si le coffre se verrouille.
class VaultItemScreen extends StatefulWidget {
  const VaultItemScreen({
    super.key,
    required this.session,
    required this.clipboard,
    required this.type,
    this.item,
    this.breaches,
    this.showGenerator = false,
  });

  final VaultSession session;
  final ClipboardGuard clipboard;
  final VaultItemType type;
  final VaultItem? item;

  /// Résultats des fuites (null : pas d'affichage).
  final BreachChecker? breaches;

  /// Générateur ouvert dès l'arrivée (depuis « Santé des mots de passe »).
  final bool showGenerator;

  @override
  State<VaultItemScreen> createState() => _VaultItemScreenState();
}

class _VaultItemScreenState extends State<VaultItemScreen> {
  late final _titre = TextEditingController(text: widget.item?.titre);
  late final _identifiant = TextEditingController(
    text: widget.item?.identifiant,
  );
  late final _motDePasse = TextEditingController(text: widget.item?.motDePasse);
  late final _siteWeb = TextEditingController(text: widget.item?.siteWeb);
  late final _note = TextEditingController(text: widget.item?.note);

  bool _saving = false;
  late bool _showGenerator = widget.showGenerator;
  bool _revealPassword = false;
  GeneratorOptions _options = const GeneratorOptions();

  bool get _isPassword => widget.type == VaultItemType.motDePasse;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_closeIfLocked);
  }

  @override
  void dispose() {
    widget.session.removeListener(_closeIfLocked);
    for (final controller in [
      _titre,
      _identifiant,
      _motDePasse,
      _siteWeb,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _closing = false;

  void _closeIfLocked() {
    if (_closing || !mounted) return;
    if (widget.session.status == VaultStatus.ouvert) return;
    _closing = true;
    // Ferme aussi une éventuelle boîte de dialogue ouverte par-dessus.
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r == route);
    navigator.pop();
  }

  void _generate() {
    setState(() {
      _motDePasse.text = generatePassword(_options);
      _revealPassword = true; // on montre ce qui vient d'être créé
    });
  }

  void _changeOptions(GeneratorOptions options) {
    _options = options;
    _generate();
  }

  Future<void> _copyPassword() async {
    if (_motDePasse.text.isEmpty) return;
    final wait = await copyFromVault(
      context,
      widget.clipboard,
      _motDePasse.text,
    );
    if (wait == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.vaultPasswordCopied('${wait.inSeconds}')),
      ),
    );
  }

  Future<void> _save() async {
    final titre = _titre.text.trim();
    if (titre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.vaultNeedTitle)),
      );
      return;
    }
    final now = DateTime.now();
    final existing = widget.item;
    final item = existing == null
        ? VaultItem(
            id: _newId(),
            type: widget.type,
            titre: titre,
            identifiant: _isPassword ? _identifiant.text.trim() : '',
            motDePasse: _isPassword ? _motDePasse.text : '',
            siteWeb: _isPassword ? _siteWeb.text.trim() : '',
            note: _note.text,
            creeLe: now,
            modifieLe: now,
          )
        : existing.copyWith(
            titre: titre,
            identifiant: _identifiant.text.trim(),
            motDePasse: _motDePasse.text,
            siteWeb: _siteWeb.text.trim(),
            note: _note.text,
            modifieLe: now,
          );
    await _run(() => widget.session.save(item));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.chaux,
        surfaceTintColor: Colors.transparent,
        title: Text(context.l10n.vaultDeleteItemTitle(widget.item!.titre)),
        content: Text(context.l10n.vaultDeleteItemText),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.secondaire,
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.colors.rommen),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.vaultDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => widget.session.delete(widget.item!.id));
  }

  // Enregistre (ou supprime), puis revient à la liste.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      if (mounted && !_closing) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted || _closing) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.vaultSaveFailed)),
      );
    }
  }

  static String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = context.colors.secondaire;
    return Scaffold(
      // Barre du haut discrète, sans ombre (comme le détail d'une app).
      appBar: AppBar(
        backgroundColor: context.colors.chaux,
        foregroundColor: context.colors.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (widget.item != null)
            IconButton(
              tooltip: l.vaultDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                children: [
                  Text(
                    widget.item == null
                        ? (_isPassword ? l.vaultNewPassword : l.vaultNewNote)
                        : widget.type.label(l),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: context.colors.encre,
                    ),
                  ),
                  const SizedBox(height: 24),
                  VaultTextField(controller: _titre, label: l.vaultFieldTitle),
                  if (_isPassword) ..._passwordFields(l, muted),
                  const SizedBox(height: 16),
                  VaultTextField(
                    controller: _note,
                    label: _isPassword ? l.vaultFieldNote : l.vaultTypeNote,
                    minLines: _isPassword ? 2 : 6,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.bleu,
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? l.vaultSaving : l.vaultSave),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _passwordFields(AppLocalizations l, Color muted) => [
    const SizedBox(height: 16),
    VaultTextField(
      controller: _identifiant,
      label: l.vaultFieldUsername,
      keyboardType: TextInputType.emailAddress,
    ),
    const SizedBox(height: 16),
    VaultTextField(
      controller: _motDePasse,
      label: l.vaultTypePassword,
      secret: true,
      revealed: _revealPassword,
    ),
    // Fuite connue pour le mot de passe affiché (disparaît s'il change).
    if (widget.breaches case final breaches?)
      ListenableBuilder(
        listenable: Listenable.merge([breaches, _motDePasse]),
        builder: (context, _) {
          final count = breaches.countFor(_motDePasse.text) ?? 0;
          if (count == 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              breachMessage(l, count),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.rommen,
              ),
            ),
          );
        },
      ),
    Row(
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: context.colors.bleu),
          onPressed: _copyPassword,
          icon: const Icon(Icons.copy, size: 18),
          label: Text(l.vaultCopy),
        ),
        const Spacer(),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: context.colors.bleu),
          onPressed: () {
            setState(() => _showGenerator = !_showGenerator);
            if (_showGenerator) _generate();
          },
          icon: const Icon(Icons.autorenew, size: 18),
          label: Text(_showGenerator ? l.vaultHideGenerator : l.vaultGenerate),
        ),
      ],
    ),
    if (_showGenerator)
      _GeneratorPanel(
        options: _options,
        onChanged: _changeOptions,
        onRegenerate: _generate,
      ),
    const SizedBox(height: 16),
    VaultTextField(
      controller: _siteWeb,
      label: l.vaultFieldWebsite,
      keyboardType: TextInputType.url,
    ),
  ];
}

/// Réglages du générateur, séparés par des traits fins.
/// Chaque changement crée aussitôt un nouveau mot de passe.
class _GeneratorPanel extends StatelessWidget {
  const _GeneratorPanel({
    required this.options,
    required this.onChanged,
    required this.onRegenerate,
  });

  final GeneratorOptions options;
  final ValueChanged<GeneratorOptions> onChanged;
  final VoidCallback onRegenerate;

  // Couleur : celle du thème (ligne fine).
  static const _divider = Divider(height: 1, thickness: 1);

  Widget _switch(
    BuildContext context,
    String label,
    bool value,
    ValueChanged<bool> onToggle,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 15, color: context.colors.encre),
          ),
        ),
        Switch(
          value: value,
          activeTrackColor: context.colors.bleu,
          onChanged: onToggle,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _divider,
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            l.generatorLength(options.length, l.number(options.length)),
            style: TextStyle(fontSize: 15, color: context.colors.encre),
          ),
        ),
        Slider(
          value: options.length.toDouble(),
          min: GeneratorOptions.minLength.toDouble(),
          max: GeneratorOptions.maxLength.toDouble(),
          divisions: GeneratorOptions.maxLength - GeneratorOptions.minLength,
          activeColor: context.colors.bleu,
          inactiveColor: context.colors.ligne,
          label: '${options.length}',
          onChanged: (value) =>
              onChanged(options.copyWith(length: value.round())),
        ),
        _divider,
        _switch(
          context,
          l.generatorUppercase,
          options.uppercase,
          (v) => onChanged(options.copyWith(uppercase: v)),
        ),
        _divider,
        _switch(
          context,
          l.generatorDigits,
          options.digits,
          (v) => onChanged(options.copyWith(digits: v)),
        ),
        _divider,
        _switch(
          context,
          l.generatorSymbols,
          options.symbols,
          (v) => onChanged(options.copyWith(symbols: v)),
        ),
        _divider,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: context.colors.bleu),
            onPressed: onRegenerate,
            child: Text(l.generatorNewPassword),
          ),
        ),
      ],
    );
  }
}
