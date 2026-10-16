import 'package:material_ui/material_ui.dart';

import '../../services/vault/password_strength.dart';
import '../../services/vault/vault_biometrics.dart';
import '../../services/vault/vault_session.dart';
import '../../theme/app_colors.dart';
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
/// récupération, suppression.
class VaultSettingsScreen extends StatefulWidget {
  const VaultSettingsScreen({super.key, required this.session});

  final VaultSession session;

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
      if (mounted && enabled) _snack("Ouverture par l'empreinte activée.");
    } on BiometricException catch (e) {
      if (!mounted) return;
      switch (e.error) {
        case BiometricError.annulee:
          break; // l'utilisateur a fermé la fenêtre : rien à dire
        case BiometricError.bloquee:
          _snack("Trop d'essais. Réessayez dans quelques instants.");
        case BiometricError.indisponible:
          _snack('Aucune empreinte enregistrée sur ce téléphone.');
        case BiometricError.invalidee:
        case BiometricError.echec:
          _snack("L'activation de l'empreinte a échoué.");
      }
    } catch (_) {
      if (mounted) _snack("L'enregistrement a échoué.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changePassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChangePasswordScreen(session: session),
      ),
    );
  }

  Future<void> _newRecoveryKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.chaux,
        surfaceTintColor: Colors.transparent,
        title: const Text('Nouvelle clé de récupération ?'),
        content: const Text(
          "L'ancienne clé ne fonctionnera plus. Pensez à noter la nouvelle.",
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.encre.withValues(alpha: 0.6),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.bleu),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Générer'),
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
      _snack('La création de la clé a échoué.');
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
      _snack('La suppression a échoué.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.encre.withValues(alpha: 0.6);
    return Scaffold(
      appBar: _appBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          children: [
            _title('Réglages du coffre'),
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
                          const Text(
                            "Ouvrir avec l'empreinte",
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.encre,
                            ),
                          ),
                          Text(
                            'Le mot de passe reste demandé au moins une fois '
                            'tous les 7 jours.',
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
            _SettingsRow(
              icon: Icons.password,
              label: 'Changer le mot de passe maître',
              onTap: _busy ? null : _changePassword,
            ),
            _divider,
            _SettingsRow(
              icon: Icons.key_outlined,
              label: 'Générer une nouvelle clé de récupération',
              onTap: _busy ? null : _newRecoveryKey,
            ),
            _divider,
            _SettingsRow(
              icon: Icons.delete_outline,
              label: 'Supprimer le coffre',
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
  static const _word = 'SUPPRIMER';
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.chaux,
      surfaceTintColor: Colors.transparent,
      title: const Text('Supprimer le coffre ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tous les mots de passe et notes seront définitivement effacés. '
            'Tapez $_word pour confirmer.',
          ),
          const SizedBox(height: 16),
          VaultTextField(
            controller: _typed,
            label: _word,
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
          child: const Text('Annuler'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.rommen),
          onPressed: _typed.text.trim() == _word
              ? () => Navigator.of(context).pop(true)
              : null,
          child: const Text('Supprimer'),
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
          const SnackBar(content: Text('Mot de passe maître changé.')),
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
        const SnackBar(content: Text("L'enregistrement a échoué.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          children: [
            _title('Changer le mot de passe maître'),
            const SizedBox(height: 24),
            VaultTextField(
              controller: _old,
              label: 'Mot de passe actuel',
              secret: true,
              enabled: !_saving,
              errorText: _wrongOld ? 'Mot de passe incorrect' : null,
              onChanged: (_) => setState(() => _wrongOld = false),
            ),
            const SizedBox(height: 16),
            VaultTextField(
              controller: _password,
              label: 'Nouveau mot de passe maître',
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
              label: 'Confirmation',
              secret: true,
              enabled: !_saving,
              errorText: _confirmation.text.isNotEmpty && !_matches
                  ? 'Les deux mots de passe diffèrent'
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
                child: Text(_saving ? 'Enregistrement…' : 'Changer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
