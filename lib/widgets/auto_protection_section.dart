import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/protection_service.dart';
import '../theme/app_colors.dart';

/// Ligne « Protection automatique » de l'onglet Messages.
/// Le Switch reflète toujours l'état RÉEL lu côté Android.
/// N'affiche rien hors Android (Windows, web…).
class AutoProtectionSection extends StatefulWidget {
  const AutoProtectionSection({super.key});

  @override
  State<AutoProtectionSection> createState() => _AutoProtectionSectionState();
}

class _AutoProtectionSectionState extends State<AutoProtectionSection> {
  final _service = ProtectionService();
  late final AppLifecycleListener _lifecycle;

  ProtectionStatus? _status;

  // L'utilisateur est parti dans les réglages Android pour accorder l'accès.
  bool _waitingForAccess = false;

  // Vient de désactiver : on propose de retirer aussi l'accès.
  bool _justDisabled = false;

  @override
  void initState() {
    super.initState();
    // Au retour dans l'app (depuis les réglages), on relit l'état réel.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    var status = await _service.getStatus();
    if (status != null) {
      final waiting = _waitingForAccess;
      _waitingForAccess = false;
      if (waiting && status.listenerAccess) {
        // Accès accordé dans les réglages : on termine l'activation.
        await _enable();
        status = await _service.getStatus();
      } else if (status.enabled && !status.listenerAccess) {
        // Accès retiré dans les réglages Android : l'option se coupe.
        await _service.setEnabled(false);
        status = await _service.getStatus();
      }
    }
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _enable() async {
    await _service.setEnabled(true);
    // Demandée seulement maintenant, quand l'utilisateur en a besoin.
    await _service.requestNotificationPermission();
  }

  Future<void> _onSwitch(bool value) async {
    if (value) {
      final accepted = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.chaux,
        builder: (_) => const _ExplanationSheet(),
      );
      if (accepted != true || !mounted) return;
      setState(() => _justDisabled = false);
      if (_status?.listenerAccess ?? false) {
        await _enable();
        await _refresh();
      } else {
        _waitingForAccess = true;
        await _service.openListenerSettings();
      }
    } else {
      await _service.setEnabled(false);
      _justDisabled = true;
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = _status;
    if (status == null) return const SizedBox.shrink();
    final muted = AppColors.encre.withValues(alpha: 0.6);
    final active = status.isActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1, color: AppColors.ligne),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.autoProtectionTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.encre,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusSentence(l, status),
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(value: active, onChanged: _onSwitch),
            ],
          ),
        ),
        if (active && !status.notificationsAllowed)
          _Link(
            label: l.autoProtectionAllowNotifications,
            onPressed: _service.openNotificationSettings,
          ),
        if (!active && _justDisabled && status.listenerAccess)
          _Link(
            label: l.autoProtectionRemoveAccess,
            onPressed: _service.openListenerSettings,
          ),
        const Divider(height: 1, thickness: 1, color: AppColors.ligne),
      ],
    );
  }

  static String _statusSentence(AppLocalizations l, ProtectionStatus status) {
    if (!status.isActive) return l.commonOffFeminine;
    if (!status.notificationsAllowed) {
      return l.autoProtectionNotificationsBlocked;
    }
    return l.autoProtectionOn;
  }
}

/// Petit lien bleu, aligné à gauche.
class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.bleu,
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// Explication avant d'accorder l'accès aux notifications.
/// Retourne true (Continuer) ou false / null (Plus tard).
class _ExplanationSheet extends StatelessWidget {
  const _ExplanationSheet();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.autoProtectionTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            const SizedBox(height: 20),
            _SheetSection(
              title: l.autoProtectionDoesTitle,
              lines: [
                l.autoProtectionDoes1,
                l.autoProtectionDoes2,
                l.autoProtectionDoes3,
              ],
            ),
            const SizedBox(height: 20),
            _SheetSection(
              title: l.autoProtectionNeverTitle,
              lines: [
                l.autoProtectionNever1,
                l.autoProtectionNever2,
                l.autoProtectionNever3,
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.encre.withValues(alpha: 0.6),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l.commonLater),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bleu,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l.commonContinue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Un titre puis des lignes séparées par des traits fins.
class _SheetSection extends StatelessWidget {
  const _SheetSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.encre,
          ),
        ),
        const SizedBox(height: 8),
        for (final line in lines) ...[
          const Divider(height: 1, thickness: 1, color: AppColors.ligne),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              line,
              style: const TextStyle(fontSize: 15, color: AppColors.encre),
            ),
          ),
        ],
      ],
    );
  }
}
