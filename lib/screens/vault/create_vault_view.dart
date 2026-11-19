import 'package:material_ui/material_ui.dart';

import '../../services/vault/password_strength.dart';
import '../../services/vault/vault_platform.dart';
import '../../l10n/l10n.dart';
import '../../services/vault/vault_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/actions_row.dart';
import '../../widgets/loading_bar.dart';
import '../../widgets/vault_fields.dart';
import '../../widgets/ui.dart';

/// Création du coffre : mot de passe maître, confirmation, avertissement.
class CreateVaultView extends StatefulWidget {
  const CreateVaultView({
    super.key,
    required this.session,
    required this.onCancel,
    this.onRestore,
  });

  final VaultSession session;
  final VoidCallback onCancel;

  /// « Restaurer une sauvegarde » (Android seulement).
  final VoidCallback? onRestore;

  @override
  State<CreateVaultView> createState() => _CreateVaultViewState();
}

class _CreateVaultViewState extends State<CreateVaultView> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _understood = false;
  bool _creating = false;

  bool get _matches => _password.text == _confirmation.text;

  bool get _canCreate =>
      isMasterPasswordAcceptable(_password.text) &&
      _matches &&
      _understood &&
      !_creating;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    setState(() => _creating = true);
    try {
      // Argon2 dans un isolate : l'écran reste fluide.
      await widget.session.create(_password.text);
      _password.clear();
      _confirmation.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.vaultCreateFailed)),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = context.colors.secondaire;
    final showMismatch = _confirmation.text.isNotEmpty && !_matches;
    return ListView(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.xl),
      children: [
        Text(
          l.vaultCreate,
          style: TextStyle(
            fontSize: AppText.accroche,
            fontWeight: FontWeight.w600,
            color: context.colors.encre,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          l.vaultCreateIntro,
          style: TextStyle(fontSize: AppText.corps, color: muted),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          l.vaultCreateWarning,
          style: TextStyle(
            fontSize: AppText.corps,
            fontWeight: FontWeight.w500,
            color: context.colors.encre,
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        VaultTextField(
          controller: _password,
          label: l.vaultMasterPassword,
          secret: true,
          enabled: !_creating,
          onChanged: (_) => setState(() {}),
        ),
        if (_password.text.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          PasswordStrengthLine(password: _password.text),
        ],
        const SizedBox(height: AppSpace.lg),
        VaultTextField(
          controller: _confirmation,
          label: l.vaultConfirmation,
          secret: true,
          enabled: !_creating,
          errorText: showMismatch ? l.vaultPasswordsDiffer : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpace.lg),
        const AppDivider(),
        // Toute la ligne est cliquable, pas seulement la case.
        // MergeSemantics : TalkBack lit la case et son texte ensemble.
        MergeSemantics(
          child: InkWell(
            onTap: _creating
                ? null
                : () => setState(() => _understood = !_understood),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: Row(
                children: [
                  Checkbox(
                    value: _understood,
                    activeColor: context.colors.bleu,
                    onChanged: _creating
                        ? null
                        : (value) => setState(() => _understood = value == true),
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      l.vaultUnderstood,
                      style: TextStyle(fontSize: AppText.corps, color: context.colors.encre),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const AppDivider(),
        if (_creating)
          const Padding(
            padding: EdgeInsets.only(top: AppSpace.lg),
            child: LoadingBar(),
          ),
        const SizedBox(height: AppSpace.lg),
        ActionsRow(
          children: [
            TextButton(
              style: mutedButtonStyle(context),
              onPressed: _creating ? null : widget.onCancel,
              child: Text(l.commonCancel),
            ),
            FilledButton(
              onPressed: _canCreate ? _create : null,
              child: Text(_creating ? l.vaultCreating : l.vaultCreate),
            ),
          ],
        ),
        // Nouveau téléphone : reprendre un coffre exporté.
        if (widget.onRestore != null && VaultPlatform.supportsDocuments) ...[
          const SizedBox(height: AppSpace.xl),
          const AppDivider(),
          const SizedBox(height: AppSpace.sm),
          TextButton.icon(
            onPressed: _creating ? null : widget.onRestore,
            icon: const Icon(Icons.restore, size: AppSize.iconSmall),
            label: Text(l.vaultRestoreBackup),
          ),
        ],
      ],
    );
  }
}
