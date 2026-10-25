import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/breach/breach_checker.dart';
import '../services/vault/vault_platform.dart';
import '../services/vault/vault_session.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state.dart';
import 'vault/create_vault_view.dart';
import 'vault/recover_view.dart';
import 'vault/recovery_key_view.dart';
import 'vault/restore_backup_view.dart';
import 'vault/unlock_view.dart';
import 'vault/vault_list_view.dart';
import 'vault/vault_settings_screen.dart';

/// Onglet « Coffre » : mots de passe et notes chiffrés sur le téléphone.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key, this.visible = false});

  /// L'onglet est affiché : on protège l'écran des captures.
  final bool visible;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  /// Temps en arrière-plan avant le verrouillage automatique.
  static const autoLockDelay = Duration(seconds: 30);

  final _session = VaultSession();
  final _clipboard = ClipboardGuard();
  final _breaches = BreachChecker(); // résultats effacés au verrouillage
  late final AppLifecycleListener _lifecycle;

  bool _creating = false; // formulaire de création affiché
  bool _recovering = false; // « Mot de passe oublié » affiché
  bool _restoring = false; // « Restaurer une sauvegarde » affiché
  DateTime? _hiddenAt;
  Timer? _autoLock;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _session.load();
    _breaches.loadConsent();
    _lifecycle = AppLifecycleListener(
      onHide: _onHide,
      onShow: _onShow,
      onResume: _clipboard.retryIfPending,
    );
    // Écran éteint = téléphone verrouillé : on ferme tout de suite.
    VaultPlatform.onScreenOff(_session.lock);
    VaultPlatform.setSecure(widget.visible);
  }

  @override
  void didUpdateWidget(VaultScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      VaultPlatform.setSecure(widget.visible);
    }
  }

  @override
  void dispose() {
    VaultPlatform.setSecure(false);
    VaultPlatform.onScreenOff(null);
    _lifecycle.dispose();
    _autoLock?.cancel();
    _clipboard.dispose();
    _breaches.dispose();
    _session.removeListener(_onSessionChanged);
    _session.dispose(); // efface la clé
    super.dispose();
  }

  void _onSessionChanged() {
    if (_session.status != VaultStatus.absent) {
      _creating = false;
      _restoring = false;
    }
    if (_session.status != VaultStatus.verrouille) _recovering = false;
    if (_session.status != VaultStatus.ouvert) _breaches.clear();
    setState(() {});
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            VaultSettingsScreen(session: _session, breaches: _breaches),
      ),
    );
  }

  // L'app passe en arrière-plan : verrouillage dans 30 s.
  void _onHide() {
    _hiddenAt = DateTime.now();
    _autoLock?.cancel();
    _autoLock = Timer(autoLockDelay, _session.lock);
  }

  // Retour dans l'app. Le minuteur a pu être gelé par le système :
  // on vérifie aussi le temps réellement écoulé.
  void _onShow() {
    _autoLock?.cancel();
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt != null &&
        DateTime.now().difference(hiddenAt) >= autoLockDelay) {
      _session.lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final opened = _session.status == VaultStatus.ouvert;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  l.navVault,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.encre,
                  ),
                ),
                const Spacer(),
                if (opened)
                  IconButton(
                    tooltip: l.vaultSettingsTitle,
                    color: AppColors.bleu,
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: _openSettings,
                  ),
                if (opened)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.bleu,
                    ),
                    onPressed: _session.lock,
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: Text(l.vaultLock),
                  ),
              ],
            ),
            Expanded(child: _body(l)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l) {
    switch (_session.status) {
      case VaultStatus.chargement:
        return const SizedBox.shrink();
      case VaultStatus.absent:
        if (_restoring) {
          return RestoreBackupView(
            session: _session,
            onCancel: () => setState(() => _restoring = false),
          );
        }
        if (_creating) {
          return CreateVaultView(
            session: _session,
            onCancel: () => setState(() => _creating = false),
            onRestore: () => setState(() => _restoring = true),
          );
        }
        return EmptyState(
          icon: Icons.lock_outline,
          title: l.vaultEmptyTitle,
          message: l.vaultEmptyMessage,
          buttonLabel: l.vaultCreate,
          onPressed: () => setState(() => _creating = true),
        );
      case VaultStatus.verrouille:
        if (_recovering) {
          return RecoverView(
            session: _session,
            onCancel: () => setState(() => _recovering = false),
          );
        }
        return UnlockView(
          session: _session,
          onForgotPassword: () => setState(() => _recovering = true),
          visible: widget.visible,
        );
      case VaultStatus.ouvert:
        // Clé de récupération neuve : montrée une fois avant la liste.
        final recoveryKey = _session.pendingRecoveryKey;
        if (recoveryKey != null) {
          return RecoveryKeyView(
            key: ValueKey(recoveryKey),
            recoveryKey: recoveryKey,
            clipboard: _clipboard,
            onDone: _session.recoveryKeyNoted,
          );
        }
        if (_session.offerRecoveryKey) {
          return RecoveryKeyOfferView(
            onCreate: _session.createRecoveryKey,
            onLater: _session.declineRecoveryKeyOffer,
          );
        }
        return VaultListView(
          session: _session,
          clipboard: _clipboard,
          breaches: _breaches,
        );
      case VaultStatus.illisible:
        return EmptyState(
          icon: Icons.error_outline,
          title: l.vaultUnreadableTitle,
          message: l.vaultUnreadableMessage,
        );
    }
  }
}
