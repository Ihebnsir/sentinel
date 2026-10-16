import 'package:material_ui/material_ui.dart';

import '../../services/vault/password_strength.dart';
import '../../services/vault/vault_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vault_fields.dart';

/// « Mot de passe oublié ? » : clé de récupération, puis nouveau mot de
/// passe maître. Ensuite, une NOUVELLE clé est affichée.
class RecoverView extends StatefulWidget {
  const RecoverView({super.key, required this.session, required this.onCancel});

  final VaultSession session;
  final VoidCallback onCancel;

  @override
  State<RecoverView> createState() => _RecoverViewState();
}

class _RecoverViewState extends State<RecoverView> {
  final _recoveryKey = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  bool _keyChecked = false; // étape 2 : nouveau mot de passe
  bool _busy = false;
  bool _wrongKey = false;

  bool get _matches => _password.text == _confirmation.text;

  bool get _canSave =>
      isMasterPasswordAcceptable(_password.text) && _matches && !_busy;

  @override
  void dispose() {
    _recoveryKey.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _checkKey() async {
    if (_busy || _recoveryKey.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final ok = await widget.session.recoveryKeyMatches(_recoveryKey.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _wrongKey = !ok;
      _keyChecked = ok;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      // Argon2 pour le nouveau mot de passe : environ une seconde.
      final ok = await widget.session.recover(
        _recoveryKey.text,
        _password.text,
      );
      // Réussi : le coffre s'ouvre et la nouvelle clé s'affiche.
      if (!mounted || ok) return;
      setState(() {
        _busy = false;
        _keyChecked = false;
        _wrongKey = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L'enregistrement a échoué.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.encre.withValues(alpha: 0.6);
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        const Text(
          'Mot de passe oublié',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.encre,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _keyChecked
              ? 'Clé acceptée. Choisissez un nouveau mot de passe maître.'
              : 'Entrez la clé de récupération notée à la création du '
                    'coffre. Les tirets et les minuscules sont acceptés.',
          style: TextStyle(fontSize: 15, color: muted),
        ),
        const SizedBox(height: 24),
        if (!_keyChecked) ...[
          VaultTextField(
            controller: _recoveryKey,
            label: 'Clé de récupération',
            // Visible, mais sans suggestions ni apprentissage du clavier.
            secret: true,
            revealed: true,
            enabled: !_busy,
            errorText: _wrongKey ? 'Clé de récupération incorrecte' : null,
            onChanged: (_) => setState(() => _wrongKey = false),
            onSubmitted: (_) => _checkKey(),
          ),
        ] else ...[
          VaultTextField(
            controller: _password,
            label: 'Nouveau mot de passe maître',
            secret: true,
            enabled: !_busy,
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
            enabled: !_busy,
            errorText: _confirmation.text.isNotEmpty && !_matches
                ? 'Les deux mots de passe diffèrent'
                : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            'Une nouvelle clé de récupération sera créée ; '
            "l'ancienne ne fonctionnera plus.",
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.bleu,
              backgroundColor: AppColors.ligne,
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: muted),
              onPressed: _busy ? null : widget.onCancel,
              child: const Text('Annuler'),
            ),
            const Spacer(),
            if (!_keyChecked)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
                onPressed: !_busy && _recoveryKey.text.trim().isNotEmpty
                    ? _checkKey
                    : null,
                child: const Text('Continuer'),
              )
            else
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
                onPressed: _canSave ? _save : null,
                child: Text(_busy ? 'Enregistrement…' : 'Enregistrer'),
              ),
          ],
        ),
      ],
    );
  }
}
