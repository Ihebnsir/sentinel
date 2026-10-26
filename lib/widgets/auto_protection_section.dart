import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/protection_service.dart';
import '../theme/app_colors.dart';
import 'actions_row.dart';

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
        backgroundColor: context.colors.chaux,
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
    final muted = context.colors.secondaire;
    final active = status.isActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, thickness: 1, color: context.colors.ligne),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          // MergeSemantics : TalkBack lit le texte avec l'interrupteur.
          child: MergeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.autoProtectionTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: context.colors.encre,
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
        Divider(height: 1, thickness: 1, color: context.colors.ligne),
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
          foregroundColor: context.colors.bleu,
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
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
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
            ActionsRow(
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.secondaire,
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l.commonLater),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.bleu,
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
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.colors.encre,
          ),
        ),
        const SizedBox(height: 8),
        for (final line in lines) ...[
          Divider(height: 1, thickness: 1, color: context.colors.ligne),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              line,
              style: TextStyle(fontSize: 15, color: context.colors.encre),
            ),
          ),
        ],
      ],
    );
  }
}
