import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../services/vault/recovery_key.dart';
import '../../services/vault/vault_platform.dart';
import '../../theme/app_colors.dart';
import '../../widgets/actions_row.dart';
import '../../widgets/vault_copy.dart';
import '../../widgets/vault_fields.dart';
import '../../widgets/ui.dart';

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
    final muted = context.colors.secondaire;
    final groups = widget.recoveryKey.split('-');
    return ListView(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.xl),
      children: [
        Icon(Icons.key_outlined, size: AppSize.iconHero, color: context.colors.bleu),
        const SizedBox(height: AppSpace.lg),
        Text(
          l.vaultYourRecoveryKey,
          style: TextStyle(
            fontSize: AppText.accroche,
            fontWeight: FontWeight.w600,
            color: context.colors.encre,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          l.vaultWriteKeyDown,
          style: TextStyle(
            fontSize: AppText.corps,
            fontWeight: FontWeight.w500,
            color: context.colors.encre,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          l.vaultKeyShownOnce,
          style: TextStyle(fontSize: AppText.corps, color: muted),
        ),
        const SizedBox(height: AppSpace.lg),
        const AppDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          // Groupes de 4 qui passent à la ligne sur les petits écrans.
          child: Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final group in groups)
                Text(
                  group,
                  style: TextStyle(
                    fontSize: AppText.titreSecondaire,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: context.colors.encre,
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['Consolas', 'Courier New'],
                  ),
                ),
            ],
          ),
        ),
        const AppDivider(),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _copy,
            icon: const Icon(Icons.copy, size: AppSize.iconSmall),
            label: Text(l.vaultCopy),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          l.vaultRetypeLast4,
          style: TextStyle(fontSize: AppText.corps, color: muted),
        ),
        const SizedBox(height: AppSpace.md),
        VaultTextField(
          controller: _lastChars,
          label: l.vaultLast4Label,
          // Visible, mais sans suggestions ni apprentissage du clavier.
          secret: true,
          revealed: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpace.lg),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
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
    final muted = context.colors.secondaire;
    return ListView(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.xl),
      children: [
        Icon(Icons.key_outlined, size: AppSize.iconHero, color: context.colors.bleu),
        const SizedBox(height: AppSpace.lg),
        Text(
          l.vaultKeyOfferTitle,
          style: TextStyle(
            fontSize: AppText.accroche,
            fontWeight: FontWeight.w600,
            color: context.colors.encre,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          l.vaultKeyOfferText,
          style: TextStyle(fontSize: AppText.corps, color: muted),
        ),
        const SizedBox(height: AppSpace.xl),
        ActionsRow(
          children: [
            TextButton(
              style: mutedButtonStyle(context),
              onPressed: _creating ? null : widget.onLater,
              child: Text(l.commonLater),
            ),
            FilledButton(
              onPressed: _creating ? null : _create,
              child: Text(_creating ? l.vaultCreating : l.vaultCreateKey),
            ),
          ],
        ),
      ],
    );
  }
}
