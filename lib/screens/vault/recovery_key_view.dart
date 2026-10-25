import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../services/vault/recovery_key.dart';
import '../../services/vault/vault_platform.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vault_copy.dart';
import '../../widgets/vault_fields.dart';

/// « Votre clé de récupération » : affichée UNE seule fois. Pour
/// continuer, il faut retaper ses 4 derniers caractères.
class RecoveryKeyView extends StatefulWidget {
  const RecoveryKeyView({
    super.key,
    required this.recoveryKey,
    required this.clipboard,
    required this.onDone,
  });

  final String recoveryKey;
  final ClipboardGuard clipboard;
  final VoidCallback onDone;

  @override
  State<RecoveryKeyView> createState() => _RecoveryKeyViewState();
}

class _RecoveryKeyViewState extends State<RecoveryKeyView> {
  final _lastChars = TextEditingController();

  bool get _confirmed =>
      _lastChars.text.trim().toUpperCase() ==
      RecoveryKey.lastGroup(widget.recoveryKey);

  @override
  void dispose() {
    _lastChars.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    final wait = await copyFromVault(
      context,
      widget.clipboard,
      widget.recoveryKey,
    );
    if (wait == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.vaultKeyCopied('${wait.inSeconds}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = AppColors.encre.withValues(alpha: 0.6);
    final groups = widget.recoveryKey.split('-');
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        const Icon(Icons.key_outlined, size: 48, color: AppColors.bleu),
        const SizedBox(height: 16),
        Text(
          l.vaultYourRecoveryKey,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.encre,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.vaultWriteKeyDown,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.encre,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.vaultKeyShownOnce,
          style: TextStyle(fontSize: 15, color: muted),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: AppColors.ligne),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          // Groupes de 4 qui passent à la ligne sur les petits écrans.
          child: Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final group in groups)
                Text(
                  group,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: AppColors.encre,
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['Consolas', 'Courier New'],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.ligne),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.bleu),
            onPressed: _copy,
            icon: const Icon(Icons.copy, size: 18),
            label: Text(l.vaultCopy),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l.vaultRetypeLast4,
          style: TextStyle(fontSize: 15, color: muted),
        ),
        const SizedBox(height: 12),
        VaultTextField(
          controller: _lastChars,
          label: l.vaultLast4Label,
          // Visible, mais sans suggestions ni apprentissage du clavier.
          secret: true,
          revealed: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
            onPressed: _confirmed ? widget.onDone : null,
            child: Text(l.vaultKeyNoted),
          ),
        ),
      ],
    );
  }
}

/// Proposée une fois aux coffres créés avant la clé de récupération.
class RecoveryKeyOfferView extends StatefulWidget {
  const RecoveryKeyOfferView({
    super.key,
    required this.onCreate,
    required this.onLater,
  });

  final Future<void> Function() onCreate;
  final VoidCallback onLater;

  @override
  State<RecoveryKeyOfferView> createState() => _RecoveryKeyOfferViewState();
}

class _RecoveryKeyOfferViewState extends State<RecoveryKeyOfferView> {
  bool _creating = false;

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      await widget.onCreate();
    } catch (_) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.vaultKeyCreateFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = AppColors.encre.withValues(alpha: 0.6);
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        const Icon(Icons.key_outlined, size: 48, color: AppColors.bleu),
        const SizedBox(height: 16),
        Text(
          l.vaultKeyOfferTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.encre,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.vaultKeyOfferText,
          style: TextStyle(fontSize: 15, color: muted),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: muted),
              onPressed: _creating ? null : widget.onLater,
              child: Text(l.commonLater),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
              onPressed: _creating ? null : _create,
              child: Text(_creating ? l.vaultCreating : l.vaultCreateKey),
            ),
          ],
        ),
      ],
    );
  }
}
