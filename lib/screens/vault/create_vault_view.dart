import 'package:material_ui/material_ui.dart';

import '../../services/vault/password_strength.dart';
import '../../services/vault/vault_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vault_fields.dart';

/// Création du coffre : mot de passe maître, confirmation, avertissement.
class CreateVaultView extends StatefulWidget {
  const CreateVaultView({
    super.key,
    required this.session,
    required this.onCancel,
  });

  final VaultSession session;
  final VoidCallback onCancel;

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
        const SnackBar(content: Text('La création du coffre a échoué.')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.encre.withValues(alpha: 0.6);
    final showMismatch = _confirmation.text.isNotEmpty && !_matches;
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        const Text(
          'Créer mon coffre',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.encre,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choisissez un mot de passe maître : il ouvre le coffre et '
          'chiffre tout son contenu.',
          style: TextStyle(fontSize: 15, color: muted),
        ),
        const SizedBox(height: 8),
        const Text(
          'Personne, pas même Sentinel, ne peut retrouver ce mot de passe. '
          "Si vous l'oubliez, le coffre est perdu.",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.encre,
          ),
        ),
        const SizedBox(height: 24),
        VaultTextField(
          controller: _password,
          label: 'Mot de passe maître',
          secret: true,
          enabled: !_creating,
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
          enabled: !_creating,
          errorText: showMismatch ? 'Les deux mots de passe diffèrent' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: AppColors.ligne),
        // Toute la ligne est cliquable, pas seulement la case.
        InkWell(
          onTap: _creating
              ? null
              : () => setState(() => _understood = !_understood),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: _understood,
                  activeColor: AppColors.bleu,
                  onChanged: _creating
                      ? null
                      : (value) => setState(() => _understood = value == true),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    "J'ai compris que ce mot de passe ne peut pas être "
                    'récupéré',
                    style: TextStyle(fontSize: 15, color: AppColors.encre),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.ligne),
        if (_creating)
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
              onPressed: _creating ? null : widget.onCancel,
              child: const Text('Annuler'),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
              onPressed: _canCreate ? _create : null,
              child: Text(_creating ? 'Création…' : 'Créer mon coffre'),
            ),
          ],
        ),
      ],
    );
  }
}
