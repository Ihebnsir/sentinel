import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../services/vault/vault_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/loading_bar.dart';
import '../../widgets/vault_fields.dart';
import '../../widgets/ui.dart';

/// Déverrouillage : empreinte si elle est activée (Android), sinon mot
/// de passe maître, puis Argon2 (≈ 1 s). Après un échec, un délai
/// croissant empêche d'essayer en rafale.
class UnlockView extends StatefulWidget {
  const UnlockView({
    super.key,
    required this.session,
    required this.onForgotPassword,
    this.visible = true,
  });

  final VaultSession session;
  final VoidCallback onForgotPassword;

  /// L'onglet Coffre est affiché (sinon, pas d'empreinte automatique).
  final bool visible;

  @override
  State<UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends State<UnlockView> {
  final _password = TextEditingController();
  bool _opening = false;
  bool _wrong = false;
  String? _biometricMessage; // empreintes changées, trop d'essais…
  bool _promptedOnce = false; // l'empreinte n'est proposée seule qu'une fois
  Timer? _countdown; // rafraîchit « Réessayez dans N s »
  late final AppLifecycleListener _lifecycle;

  Duration get _wait => widget.session.remainingWait;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Verrouillé en arrière-plan : l'empreinte est proposée au retour.
    _lifecycle = AppLifecycleListener(onResume: _autoPrompt);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoPrompt());
  }

  @override
  void didUpdateWidget(UnlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Après la construction : la fenêtre d'empreinte change l'état.
    if (widget.visible && !oldWidget.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoPrompt());
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _countdown?.cancel();
    _password.dispose();
    super.dispose();
  }

  void _autoPrompt() {
    if (_promptedOnce || !mounted || !widget.visible) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (!widget.session.canUnlockWithBiometrics) return;
    _promptedOnce = true;
    _openWithBiometrics();
  }

  Future<void> _openWithBiometrics() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _biometricMessage = null;
    });
    final result = await widget.session.unlockWithBiometrics();
    if (!mounted || result == BiometricUnlockResult.ouvert) return;
    final l = context.l10n;
    setState(() {
      _opening = false;
      _biometricMessage = switch (result) {
        BiometricUnlockResult.empreintesChangees => l.vaultFingerprintsChanged,
        BiometricUnlockResult.bloque => l.vaultTooManyTries,
        BiometricUnlockResult.echec => l.vaultFingerprintFailed,
        _ => null, // annulé : le mot de passe reste disponible
      };
    });
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
    final l = context.l10n;
    final muted = context.colors.secondaire;
    final waitSeconds = (_wait.inMilliseconds / 1000).ceil();
    final session = widget.session;
    final biometric = session.canUnlockWithBiometrics;
    final info =
        _biometricMessage ??
        (session.biometricBroken
            ? l.vaultFingerprintsChanged
            : session.biometricNeedsPassword
            ? l.vaultWeeklyPassword
            : null);
    return ListView(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.xl),
      children: [
        // Porte bleue fermée, alignée sur le texte (et non centrée).
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: SidiBouIllustration(SidiBouMotif.porte, size: AppSize.archHero),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          l.vaultLockedTitle,
          style: TextStyle(
            fontSize: AppText.accroche,
            fontWeight: FontWeight.w600,
            color: context.colors.encre,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          biometric
              ? l.vaultUseFingerprintOrPassword
              : l.vaultEnterMasterPassword,
          style: TextStyle(fontSize: AppText.corps, color: muted),
        ),
        if (info != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.md),
            child: Text(
              info,
              style: TextStyle(fontSize: AppText.corps, color: context.colors.encre),
            ),
          ),
        if (biometric) ...[
          const SizedBox(height: AppSpace.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _opening ? null : _openWithBiometrics,
              icon: const Icon(Icons.fingerprint),
              label: Text(l.vaultOpenWithFingerprint),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            l.vaultOrWithPassword,
            style: TextStyle(fontSize: AppText.detail, color: muted),
          ),
          const SizedBox(height: AppSpace.sm),
        ] else
          const SizedBox(height: AppSpace.xl),
        VaultTextField(
          controller: _password,
          label: l.vaultMasterPassword,
          secret: true,
          enabled: !_opening,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _open(),
        ),
        if (_wrong || waitSeconds > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.md),
            child: Text(
              [
                if (_wrong) l.vaultWrongPassword,
                if (waitSeconds > 0) l.vaultRetryIn('$waitSeconds'),
              ].join(' '),
              style: TextStyle(fontSize: AppText.corps, color: context.colors.rommen),
            ),
          ),
        if (_opening)
          const Padding(padding: EdgeInsets.only(top: AppSpace.lg), child: LoadingBar()),
        const SizedBox(height: AppSpace.lg),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed:
                !_opening && waitSeconds == 0 && _password.text.isNotEmpty
                ? _open
                : null,
            child: Text(_opening ? l.vaultOpening : l.vaultOpen),
          ),
        ),
        // Les vieux coffres migrés n'ont pas toujours de clé.
        if (session.hasRecoveryKey) ...[
          const SizedBox(height: AppSpace.sm),
          const AppDivider(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _opening ? null : widget.onForgotPassword,
              child: Text(l.vaultForgotPassword),
            ),
          ),
        ],
      ],
    );
  }
}
