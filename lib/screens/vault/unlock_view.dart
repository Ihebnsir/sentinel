import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../services/vault/vault_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vault_fields.dart';

/// Déverrouillage : mot de passe maître, puis Argon2 (≈ 1 s).
/// Après un échec, un délai croissant empêche d'essayer en rafale.
class UnlockView extends StatefulWidget {
  const UnlockView({super.key, required this.session});

  final VaultSession session;

  @override
  State<UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends State<UnlockView> {
  final _password = TextEditingController();
  bool _opening = false;
  bool _wrong = false;
  Timer? _countdown; // rafraîchit « Réessayez dans N s »

  Duration get _wait => widget.session.remainingWait;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _password.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdown?.cancel();
    if (_wait == Duration.zero) return;
    _countdown = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_wait == Duration.zero) timer.cancel();
      setState(() {});
    });
  }

  Future<void> _open() async {
    if (_opening || _wait > Duration.zero || _password.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _opening = true;
      _wrong = false;
    });
    final result = await widget.session.unlock(_password.text);
    // Ouvert : cet écran disparaît, rien d'autre à faire.
    if (!mounted || result == UnlockResult.ouvert) return;
    _password.clear();
    setState(() {
      _opening = false;
      _wrong = result == UnlockResult.incorrect;
    });
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.encre.withValues(alpha: 0.6);
    final waitSeconds = (_wait.inMilliseconds / 1000).ceil();
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        const Icon(Icons.lock_outline, size: 48, color: AppColors.bleu),
        const SizedBox(height: 16),
        const Text(
          'Coffre verrouillé',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.encre,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Entrez votre mot de passe maître.',
          style: TextStyle(fontSize: 15, color: muted),
        ),
        const SizedBox(height: 24),
        VaultTextField(
          controller: _password,
          label: 'Mot de passe maître',
          secret: true,
          enabled: !_opening,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _open(),
        ),
        if (_wrong || waitSeconds > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              [
                if (_wrong) 'Mot de passe incorrect.',
                if (waitSeconds > 0) 'Réessayez dans $waitSeconds s.',
              ].join(' '),
              style: const TextStyle(fontSize: 15, color: AppColors.rommen),
            ),
          ),
        if (_opening)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.bleu,
              backgroundColor: AppColors.ligne,
            ),
          ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
            onPressed:
                !_opening && waitSeconds == 0 && _password.text.isNotEmpty
                ? _open
                : null,
            child: Text(_opening ? 'Ouverture…' : 'Ouvrir le coffre'),
          ),
        ),
      ],
    );
  }
}
