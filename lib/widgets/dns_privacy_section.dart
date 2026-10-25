import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/firewall_service.dart';
import '../theme/app_colors.dart';

const _divider = Divider(height: 1, thickness: 1, color: AppColors.ligne);

/// Texte de l'état du DNS vers Quad9 (SEN-10).
String upstreamLabel(AppLocalizations l, UpstreamMode mode) => switch (mode) {
  UpstreamMode.idle => l.upstreamIdle,
  UpstreamMode.dot => l.upstreamDot,
  UpstreamMode.doh => l.upstreamDoh,
  UpstreamMode.plain => l.upstreamPlain,
  UpstreamMode.failing => l.upstreamFailing,
};

/// État du DNS vers Quad9, et accord pour le DNS non chiffré (SEN-10).
/// L'interrupteur n'apparaît qu'en cas d'échec ou s'il est déjà activé.
class UpstreamSection extends StatelessWidget {
  const UpstreamSection({
    super.key,
    required this.mode,
    required this.plainAllowed,
    required this.onPlainChanged,
  });

  final UpstreamMode mode;
  final bool plainAllowed;
  final ValueChanged<bool>? onPlainChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = AppColors.encre.withValues(alpha: 0.6);
    final warning = mode == UpstreamMode.failing || mode == UpstreamMode.plain;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.upstreamLabel,
                  style: const TextStyle(fontSize: 15, color: AppColors.encre),
                ),
              ),
              Flexible(
                child: Text(
                  upstreamLabel(l, mode),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: warning ? AppColors.rommen : muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (mode == UpstreamMode.failing || plainAllowed) ...[
          if (mode == UpstreamMode.failing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l.upstreamFailingHelp,
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
          _divider,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.upstreamAllowPlain,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.encre,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Switch(value: plainAllowed, onChanged: onPlainChanged),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Avertissement « DNS privé strict » avec accès direct aux réglages (SEN-11).
class StrictPrivateDnsWarning extends StatelessWidget {
  const StrictPrivateDnsWarning({
    super.key,
    required this.server,
    required this.onOpenSettings,
  });

  final String server;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.dnsStrictTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.rommen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.dnsStrictMessage(server),
            style: const TextStyle(fontSize: 14, color: AppColors.encre),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.bleu,
              padding: EdgeInsets.zero,
            ),
            onPressed: onOpenSettings,
            child: Text(l.dnsStrictOpenSettings),
          ),
        ],
      ),
    );
  }
}
