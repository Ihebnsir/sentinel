import 'package:material_ui/material_ui.dart';

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
                    const Text(
                      'Protection automatique',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.encre,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusSentence(status),
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
            label: 'Autoriser les notifications de Sentinel',
            onPressed: _service.openNotificationSettings,
          ),
        if (!active && _justDisabled && status.listenerAccess)
          _Link(
            label: "Retirer aussi l'accès dans les réglages Android",
            onPressed: _service.openListenerSettings,
          ),
        const Divider(height: 1, thickness: 1, color: AppColors.ligne),
      ],
    );
  }

  static String _statusSentence(ProtectionStatus status) {
    if (!status.isActive) return 'Désactivée';
    if (!status.notificationsAllowed) {
      return 'Notifications de Sentinel bloquées : '
          'vous ne serez pas prévenu en cas d\'arnaque.';
    }
    return "Analyse les messages reçus et vous prévient en cas d'arnaque.";
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Protection automatique',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            const SizedBox(height: 20),
            const _SheetSection(
              title: 'Ce que fait Sentinel',
              lines: [
                'Lit le texte des notifications de vos applications de '
                    'messagerie.',
                "L'analyse sur votre téléphone.",
                "Vous prévient si c'est une arnaque.",
              ],
            ),
            const SizedBox(height: 20),
            const _SheetSection(
              title: 'Ce que Sentinel ne fait jamais',
              lines: [
                'Envoyer vos messages sur Internet.',
                'Les enregistrer.',
                'Lire les notifications des autres applications.',
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
                  child: const Text('Plus tard'),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bleu,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Continuer'),
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
