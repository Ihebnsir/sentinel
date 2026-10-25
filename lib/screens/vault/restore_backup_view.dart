import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/vault/password_strength.dart';
import '../../services/vault/vault_backup.dart';
import '../../services/vault/vault_crypto.dart';
import '../../services/vault/vault_item.dart';
import '../../services/vault/vault_platform.dart';
import '../../services/vault/vault_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vault_fields.dart';

/// Message clair pour un fichier qui n'est pas une sauvegarde lisible.
String backupProblemText(BackupProblem problem) => switch (problem) {
  BackupProblem.vide => 'Ce fichier est vide.',
  BackupProblem.illisible =>
    "Ce fichier n'est pas une sauvegarde Sentinel, ou il est abîmé.",
  BackupProblem.versionInconnue =>
    "Cette sauvegarde vient d'une version plus récente de Sentinel. "
        "Mettez l'application à jour, puis réessayez.",
};

enum _Step { fichier, motDePasse, nouveauMotDePasse }

/// « Restaurer une sauvegarde » : fichier .sentinel, son mot de passe,
/// puis un nouveau mot de passe maître. Le coffre restauré est neuf
/// (nouvelle clé de récupération, montrée ensuite).
class RestoreBackupView extends StatefulWidget {
  const RestoreBackupView({
    super.key,
    required this.session,
    required this.onCancel,
  });

  final VaultSession session;
  final VoidCallback onCancel;

  @override
  State<RestoreBackupView> createState() => _RestoreBackupViewState();
}

class _RestoreBackupViewState extends State<RestoreBackupView> {
  final _backupPassword = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  _Step _step = _Step.fichier;
  bool _busy = false;
  String? _error;
  Uint8List? _bytes; // fichier chiffré choisi
  List<VaultItem>? _items; // déchiffrés, en attente du nouveau mot de passe

  bool get _matches => _password.text == _confirmation.text;

  bool get _canRestore =>
      isMasterPasswordAcceptable(_password.text) && _matches && !_busy;

  @override
  void dispose() {
    _backupPassword.dispose();
    _password.dispose();
    _confirmation.dispose();
    _bytes = null;
    _items = null;
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      final bytes = await VaultPlatform.openDocument(
        maxBytes: VaultBackup.maxBytes,
      );
      if (bytes != null) {
        VaultBackup.decode(bytes); // format vérifié avant le mot de passe
        _bytes = bytes;
        _step = _Step.motDePasse;
      }
    } on BackupFormatException catch (e) {
      error = backupProblemText(e.problem);
    } on PlatformException catch (e) {
      error = e.code == 'TROP_GROS'
          ? "Ce fichier est trop gros pour être une sauvegarde Sentinel."
          : 'Impossible de lire ce fichier.';
    } catch (_) {
      error = 'Impossible de lire ce fichier.';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Future<void> _checkPassword() async {
    final bytes = _bytes;
    if (bytes == null || _busy || _backupPassword.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      // Argon2 dans un isolate : l'écran reste fluide.
      _items = await widget.session.readBackup(bytes, _backupPassword.text);
      _backupPassword.clear();
      _step = _Step.nouveauMotDePasse;
    } on WrongPasswordException {
      error = "Mot de passe incorrect, ou fichier modifié depuis l'export.";
      _backupPassword.clear();
    } on BackupFormatException catch (e) {
      error = backupProblemText(e.problem);
    } catch (_) {
      error = 'Impossible de lire cette sauvegarde.';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Future<void> _restore() async {
    final items = _items;
    if (items == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      // Réussi : le coffre s'ouvre et la nouvelle clé s'affiche.
      await widget.session.restore(items, _password.text);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La restauration a échoué.')),
      );
    }
  }

  String get _intro => switch (_step) {
    _Step.fichier =>
      'Choisissez le fichier .sentinel créé avec « Exporter une sauvegarde '
          'chiffrée » sur votre ancien téléphone.',
    _Step.motDePasse => "Entrez le mot de passe choisi au moment de l'export.",
    _Step.nouveauMotDePasse =>
      'Sauvegarde ouverte : ${_items?.length ?? 0} élément(s). Choisissez '
          'le mot de passe maître de ce téléphone.',
  };

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.encre.withValues(alpha: 0.6);
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        const Text(
          'Restaurer une sauvegarde',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.encre,
          ),
        ),
        const SizedBox(height: 8),
        Text(_intro, style: TextStyle(fontSize: 15, color: muted)),
        const SizedBox(height: 24),
        if (_step == _Step.motDePasse)
          VaultTextField(
            controller: _backupPassword,
            label: 'Mot de passe de la sauvegarde',
            secret: true,
            enabled: !_busy,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _checkPassword(),
          ),
        if (_step == _Step.nouveauMotDePasse) ...[
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
            'Une nouvelle clé de récupération sera créée pour ce téléphone.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(fontSize: 14, color: AppColors.rommen),
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
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
              onPressed: switch (_step) {
                _Step.fichier => _busy ? null : _pickFile,
                _Step.motDePasse =>
                  !_busy && _backupPassword.text.isNotEmpty
                      ? _checkPassword
                      : null,
                _Step.nouveauMotDePasse => _canRestore ? _restore : null,
              },
              child: Text(switch (_step) {
                _Step.fichier => 'Choisir le fichier',
                _Step.motDePasse => 'Continuer',
                _Step.nouveauMotDePasse =>
                  _busy ? 'Restauration…' : 'Restaurer',
              }),
            ),
          ],
        ),
      ],
    );
  }
}
