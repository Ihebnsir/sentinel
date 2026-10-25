import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../services/breach/breach_checker.dart';
import '../../services/vault/password_strength.dart';
import '../../services/vault/vault_backup.dart';
import '../../services/vault/vault_biometrics.dart';
import '../../services/vault/vault_platform.dart';
import '../../services/vault/vault_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breach_consent_sheet.dart';
import '../../widgets/vault_fields.dart';

const _divider = Divider(height: 1, thickness: 1, color: AppColors.ligne);

/// Ferme l'écran (et une boîte de dialogue éventuelle) si le coffre se
/// verrouille ou est supprimé.
mixin _ClosesWhenLocked<T extends StatefulWidget> on State<T> {
  VaultSession get session;
  bool closing = false;

  @override
  void initState() {
    super.initState();
    session.addListener(_onSession);
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (closing || !mounted) return;
    if (session.status == VaultStatus.ouvert) {
      setState(() {});
      return;
    }
    closing = true;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r == route);
    navigator.pop();
  }
}

/// Barre du haut discrète, comme le détail d'un élément.
AppBar _appBar() => AppBar(
  backgroundColor: AppColors.chaux,
  foregroundColor: AppColors.encre,
  elevation: 0,
  scrolledUnderElevation: 0,
  surfaceTintColor: Colors.transparent,
);

Widget _title(String text) => Text(
  text,
  style: const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.encre,
  ),
);

/// Réglages du coffre ouvert : empreinte, mot de passe, clé de
/// récupération, sauvegarde chiffrée, suppression.
class VaultSettingsScreen extends StatefulWidget {
  const VaultSettingsScreen({
    super.key,
    required this.session,
    required this.breaches,
  });

  final VaultSession session;
  final BreachChecker breaches;

  @override
  State<VaultSettingsScreen> createState() => _VaultSettingsScreenState();
}

class _VaultSettingsScreenState extends State<VaultSettingsScreen>
    with _ClosesWhenLocked {
  @override
  VaultSession get session => widget.session;

  bool _busy = false;

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleBiometric(bool enabled) async {
    setState(() => _busy = true);
    try {
      await session.setBiometricEnabled(enabled);
      if (mounted && enabled) _snack(context.l10n.vaultFingerprintEnabled);
    } on BiometricException catch (e) {
      if (!mounted) return;
      final l = context.l10n;
      switch (e.error) {
        case BiometricError.annulee:
          break; // l'utilisateur a fermé la fenêtre : rien à dire
        case BiometricError.bloquee:
          _snack(l.vaultBiometricTooManyTries);
        case BiometricError.indisponible:
          _snack(l.vaultNoFingerprint);
        case BiometricError.invalidee:
        case BiometricError.echec:
          _snack(l.vaultFingerprintActivationFailed);
      }
    } catch (_) {
      if (mounted) _snack(context.l10n.vaultSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Activer demande l'accord ; désactiver efface aussi les résultats.
  Future<void> _toggleBreaches(bool enabled) async {
    if (enabled && !await askBreachConsent(context)) return;
    await widget.breaches.setConsent(enabled);
    if (mounted) setState(() {});
  }

  void _changePassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChangePasswordScreen(session: session),
      ),
    );
  }

  void _exportBackup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ExportBackupScreen(session: session),
      ),
    );
  }

  Future<void> _newRecoveryKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.chaux,
        surfaceTintColor: Colors.transparent,
        title: Text(context.l10n.vaultNewKeyTitle),
        content: Text(context.l10n.vaultNewKeyText),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.encre.withValues(alpha: 0.6),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.bleu),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.vaultGenerate),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await session.createRecoveryKey();
      // L'onglet Coffre affiche maintenant la clé : on y retourne.
      if (mounted && !closing) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(context.l10n.vaultKeyCreateFailed);
    }
  }

  Future<void> _deleteVault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteDialog(),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await session.deleteVault(); // l'écran se ferme tout seul
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(context.l10n.vaultDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = AppColors.encre.withValues(alpha: 0.6);
    return Scaffold(
      appBar: _appBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          children: [
            _title(l.vaultSettingsTitle),
            const SizedBox(height: 24),
            // Empreinte : Android avec capteur seulement (masqué sur Windows).
            if (session.biometricsAvailable) ...[
              _divider,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.fingerprint, color: AppColors.bleu),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.vaultOpenWithFingerprint,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.encre,
                            ),
                          ),
                          Text(
                            l.vaultFingerprintWeekly,
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: session.biometricEnabled,
                      activeTrackColor: AppColors.bleu,
                      onChanged: _busy ? null : _toggleBiometric,
                    ),
                  ],
                ),
              ),
            ],
            _divider,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.travel_explore, color: AppColors.bleu),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.healthCheckButton,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.encre,
                          ),
                        ),
                        Text(
                          l.vaultBreachSettingDetail,
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: widget.breaches.consent,
                    activeTrackColor: AppColors.bleu,
                    onChanged: _busy ? null : _toggleBreaches,
                  ),
                ],
              ),
            ),
            _divider,
            _SettingsRow(
              icon: Icons.password,
              label: l.vaultChangeMaster,
              onTap: _busy ? null : _changePassword,
            ),
            _divider,
            _SettingsRow(
              icon: Icons.key_outlined,
              label: l.vaultNewRecoveryKey,
              onTap: _busy ? null : _newRecoveryKey,
            ),
            _divider,
            // Sélecteur de fichiers d'Android : masqué sur Windows.
            if (VaultPlatform.supportsDocuments) ...[
              _SettingsRow(
                icon: Icons.save_alt,
                label: l.vaultExport,
                onTap: _busy ? null : _exportBackup,
              ),
              _divider,
            ],
            _SettingsRow(
              icon: Icons.delete_outline,
              label: l.vaultDeleteVault,
              color: AppColors.rommen,
              onTap: _busy ? null : _deleteVault,
            ),
            _divider,
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.bleu,
                  backgroundColor: AppColors.ligne,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne cliquable : icône, texte, chevron.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.encre,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: color == AppColors.encre ? AppColors.bleu : color,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 15, color: color)),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.encre.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation : il faut taper SUPPRIMER.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog();

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Mot à taper, dans la langue de l'app (« SUPPRIMER »).
    final word = l.vaultDeleteWord;
    return AlertDialog(
      backgroundColor: AppColors.chaux,
      surfaceTintColor: Colors.transparent,
      title: Text(l.vaultDeleteVaultTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.vaultDeleteVaultText(word)),
          const SizedBox(height: 16),
          VaultTextField(
            controller: _typed,
            label: word,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.encre.withValues(alpha: 0.6),
          ),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.rommen),
          onPressed: _typed.text.trim() == word
              ? () => Navigator.of(context).pop(true)
              : null,
          child: Text(l.vaultDelete),
        ),
      ],
    );
  }
}

/// Ancien mot de passe + nouveau + confirmation. Nouveau sel ; seul
/// l'emplacement « mot de passe » change, les données restent intactes.
class _ChangePasswordScreen extends StatefulWidget {
  const _ChangePasswordScreen({required this.session});

  final VaultSession session;

  @override
  State<_ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<_ChangePasswordScreen>
    with _ClosesWhenLocked {
  @override
  VaultSession get session => widget.session;

  final _old = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  bool _wrongOld = false;

  bool get _matches => _password.text == _confirmation.text;

  bool get _canSave =>
      _old.text.isNotEmpty &&
      isMasterPasswordAcceptable(_password.text) &&
      _matches &&
      !_saving;

  @override
  void dispose() {
    _old.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _wrongOld = false;
    });
    try {
      // Deux Argon2 (vérifier l'ancien, dériver le nouveau).
      final ok = await session.changeMasterPassword(_old.text, _password.text);
      if (!mounted || closing) return;
      if (ok) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.vaultMasterChanged)),
        );
        return;
      }
      _old.clear();
      setState(() {
        _saving = false;
        _wrongOld = true;
      });
    } catch (_) {
      if (!mounted || closing) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.vaultSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: _appBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          children: [
            _title(l.vaultChangeMaster),
            const SizedBox(height: 24),
            VaultTextField(
              controller: _old,
              label: l.vaultCurrentPassword,
              secret: true,
              enabled: !_saving,
              errorText: _wrongOld ? l.vaultWrongPasswordShort : null,
              onChanged: (_) => setState(() => _wrongOld = false),
            ),
            const SizedBox(height: 16),
            VaultTextField(
              controller: _password,
              label: l.vaultNewMasterPassword,
              secret: true,
              enabled: !_saving,
              onChanged: (_) => setState(() {}),
            ),
            if (_password.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              PasswordStrengthLine(password: _password.text),
            ],
            const SizedBox(height: 16),
            VaultTextField(
              controller: _confirmation,
              label: l.vaultConfirmation,
              secret: true,
              enabled: !_saving,
              errorText: _confirmation.text.isNotEmpty && !_matches
                  ? l.vaultPasswordsDiffer
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.bleu,
                  backgroundColor: AppColors.ligne,
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
                onPressed: _canSave ? _save : null,
                child: Text(_saving ? l.vaultSaving : l.vaultChange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sauvegarde chiffrée : un mot de passe d'export (mêmes règles que le
/// mot de passe maître), puis le sélecteur de fichiers d'Android.
class _ExportBackupScreen extends StatefulWidget {
  const _ExportBackupScreen({required this.session});

  final VaultSession session;

  @override
  State<_ExportBackupScreen> createState() => _ExportBackupScreenState();
}

class _ExportBackupScreenState extends State<_ExportBackupScreen>
    with _ClosesWhenLocked {
  @override
  VaultSession get session => widget.session;

  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;

  bool get _matches => _password.text == _confirmation.text;

  bool get _canExport =>
      isMasterPasswordAcceptable(_password.text) && _matches && !_saving;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  // Ex. sentinel-coffre-2026-10-25.sentinel
  static String _fileName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'sentinel-coffre-${now.year}-${two(now.month)}-${two(now.day)}'
        '.${VaultBackup.extension}';
  }

  Future<void> _export() async {
    final l = context.l10n;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    String message;
    var done = false;
    try {
      // Argon2 d'abord : le fichier est prêt avant d'ouvrir le sélecteur.
      final bytes = await session.createBackup(_password.text);
      done = await VaultPlatform.saveDocument(_fileName(DateTime.now()), bytes);
      message = done ? l.exportSaved : l.exportCancelled;
    } on PlatformException {
      message = l.exportFileFailed;
    } catch (_) {
      message = l.exportFailed;
    }
    if (!mounted || closing) return;
    final messenger = ScaffoldMessenger.of(context);
    if (done) {
      _password.clear();
      _confirmation.clear();
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = AppColors.encre.withValues(alpha: 0.6);
    return Scaffold(
      appBar: _appBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          children: [
            _title(l.vaultExport),
            const SizedBox(height: 8),
            Text(
              l.exportIntro,
              style: TextStyle(fontSize: 15, color: muted),
            ),
            const SizedBox(height: 8),
            Text(
              l.exportStore,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.encre,
              ),
            ),
            const SizedBox(height: 24),
            VaultTextField(
              controller: _password,
              label: l.exportPasswordLabel,
              secret: true,
              enabled: !_saving,
              onChanged: (_) => setState(() {}),
            ),
            if (_password.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              PasswordStrengthLine(password: _password.text),
            ],
            const SizedBox(height: 16),
            VaultTextField(
              controller: _confirmation,
              label: l.vaultConfirmation,
              secret: true,
              enabled: !_saving,
              errorText: _confirmation.text.isNotEmpty && !_matches
                  ? l.vaultPasswordsDiffer
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.bleu,
                  backgroundColor: AppColors.ligne,
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
                onPressed: _canExport ? _export : null,
                child: Text(_saving ? l.exportEncrypting : l.exportButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
