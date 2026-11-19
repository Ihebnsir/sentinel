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
import '../../widgets/loading_bar.dart';
import '../../widgets/vault_fields.dart';
import '../../widgets/ui.dart';

// Couleur : celle du thème (dividerTheme, ligne fine).
const _divider = Divider(height: 1, thickness: 1);

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
AppBar _appBar(BuildContext context) => AppBar(
  backgroundColor: context.colors.chaux,
  foregroundColor: context.colors.encre,
  elevation: 0,
  scrolledUnderElevation: 0,
  surfaceTintColor: Colors.transparent,
);

Widget _title(BuildContext context, String text) => Text(
  text,
  style: TextStyle(
    fontSize: AppText.titreSecondaire,
    fontWeight: FontWeight.w600,
    color: context.colors.encre,
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
        title: Text(context.l10n.vaultNewKeyTitle),
        content: Text(context.l10n.vaultNewKeyText),
        actions: [
          TextButton(
            style: mutedButtonStyle(context),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
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
    final muted = context.colors.secondaire;
    return Scaffold(
      appBar: _appBar(context),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xl),
          children: [
            _title(context, l.vaultSettingsTitle),
            const SizedBox(height: AppSpace.xl),
            // Empreinte : Android avec capteur seulement (masqué sur Windows).
            if (session.biometricsAvailable) ...[
              _divider,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                // MergeSemantics : TalkBack lit le texte avec l'interrupteur.
                child: MergeSemantics(
                  child: Row(
                    children: [
                      Icon(Icons.fingerprint, color: context.colors.bleu),
                      const SizedBox(width: AppSpace.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.vaultOpenWithFingerprint,
                              style: TextStyle(
                                fontSize: AppText.corps,
                                color: context.colors.encre,
                              ),
                            ),
                            Text(
                              l.vaultFingerprintWeekly,
                              style: TextStyle(fontSize: AppText.detail, color: muted),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: session.biometricEnabled,
                        activeTrackColor: context.colors.bleu,
                        onChanged: _busy ? null : _toggleBiometric,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            _divider,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              // MergeSemantics : TalkBack lit le texte avec l'interrupteur.
              child: MergeSemantics(
                child: Row(
                  children: [
                    Icon(Icons.travel_explore, color: context.colors.bleu),
                    const SizedBox(width: AppSpace.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.healthCheckButton,
                            style: TextStyle(
                              fontSize: AppText.corps,
                              color: context.colors.encre,
                            ),
                          ),
                          Text(
                            l.vaultBreachSettingDetail,
                            style: TextStyle(fontSize: AppText.detail, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: widget.breaches.consent,
                      activeTrackColor: context.colors.bleu,
                      onChanged: _busy ? null : _toggleBreaches,
                    ),
                  ],
                ),
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
              color: context.colors.rommen,
              onTap: _busy ? null : _deleteVault,
            ),
            _divider,
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: AppSpace.lg),
                child: LoadingBar(),
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
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color; // null : couleur du texte (icône bleue)

  @override
  Widget build(BuildContext context) {
    return ListRow(
      icon: icon,
      iconColor: color,
      title: label,
      titleColor: color,
      onTap: onTap,
      chevron: true,
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
      title: Text(l.vaultDeleteVaultTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.vaultDeleteVaultText(word)),
          const SizedBox(height: AppSpace.lg),
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
          style: mutedButtonStyle(context),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.commonCancel),
        ),
        TextButton(
          style: dangerButtonStyle(context),
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
      appBar: _appBar(context),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xl),
          children: [
            _title(context, l.vaultChangeMaster),
            const SizedBox(height: AppSpace.xl),
            VaultTextField(
              controller: _old,
              label: l.vaultCurrentPassword,
              secret: true,
              enabled: !_saving,
              errorText: _wrongOld ? l.vaultWrongPasswordShort : null,
              onChanged: (_) => setState(() => _wrongOld = false),
            ),
            const SizedBox(height: AppSpace.lg),
            VaultTextField(
              controller: _password,
              label: l.vaultNewMasterPassword,
              secret: true,
              enabled: !_saving,
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
              enabled: !_saving,
              errorText: _confirmation.text.isNotEmpty && !_matches
                  ? l.vaultPasswordsDiffer
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: AppSpace.lg),
                child: LoadingBar(),
              ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
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
    final muted = context.colors.secondaire;
    return Scaffold(
      appBar: _appBar(context),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xl),
          children: [
            _title(context, l.vaultExport),
            const SizedBox(height: AppSpace.sm),
            Text(
              l.exportIntro,
              style: TextStyle(fontSize: AppText.corps, color: muted),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              l.exportStore,
              style: TextStyle(
                fontSize: AppText.corps,
                fontWeight: FontWeight.w500,
                color: context.colors.encre,
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            VaultTextField(
              controller: _password,
              label: l.exportPasswordLabel,
              secret: true,
              enabled: !_saving,
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
              enabled: !_saving,
              errorText: _confirmation.text.isNotEmpty && !_matches
                  ? l.vaultPasswordsDiffer
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: AppSpace.lg),
                child: LoadingBar(),
              ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
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
