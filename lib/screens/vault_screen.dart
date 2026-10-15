import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../services/vault/vault_platform.dart';
import '../services/vault/vault_session.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state.dart';
import 'vault/create_vault_view.dart';
import 'vault/unlock_view.dart';
import 'vault/vault_list_view.dart';

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
  late final AppLifecycleListener _lifecycle;

  bool _creating = false; // formulaire de création affiché
  DateTime? _hiddenAt;
  Timer? _autoLock;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _session.load();
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
    _session.removeListener(_onSessionChanged);
    _session.dispose(); // efface la clé
    super.dispose();
  }

  void _onSessionChanged() {
    if (_session.status != VaultStatus.absent) _creating = false;
    setState(() {});
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
    final opened = _session.status == VaultStatus.ouvert;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Coffre',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.encre,
                  ),
                ),
                const Spacer(),
                if (opened)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.bleu,
                    ),
                    onPressed: _session.lock,
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Verrouiller'),
                  ),
              ],
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_session.status) {
      case VaultStatus.chargement:
        return const SizedBox.shrink();
      case VaultStatus.absent:
        if (_creating) {
          return CreateVaultView(
            session: _session,
            onCancel: () => setState(() => _creating = false),
          );
        }
        return EmptyState(
          icon: Icons.lock_outline,
          title: 'Vos mots de passe, chiffrés',
          message: 'Stockez vos mots de passe et notes secrètes. '
              'Ils sont chiffrés sur votre téléphone et personne '
              "d'autre ne peut les lire.",
          buttonLabel: 'Créer mon coffre',
          onPressed: () => setState(() => _creating = true),
        );
      case VaultStatus.verrouille:
        return UnlockView(session: _session);
      case VaultStatus.ouvert:
        return VaultListView(session: _session, clipboard: _clipboard);
      case VaultStatus.illisible:
        return const EmptyState(
          icon: Icons.error_outline,
          title: 'Coffre illisible',
          message: 'Le fichier du coffre semble endommagé ou modifié. '
              "Sentinel ne peut pas l'ouvrir.",
        );
    }
  }
}
