import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/firewall_service.dart';
import '../theme/app_colors.dart';

// Couleur : celle du thème (dividerTheme, ligne fine).
const _divider = Divider(height: 1, thickness: 1);

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
    final muted = context.colors.secondaire;
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
                  style: TextStyle(fontSize: 15, color: context.colors.encre),
                ),
              ),
              Flexible(
                child: Text(
                  upstreamLabel(l, mode),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: warning ? context.colors.rommen : muted,
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
            // MergeSemantics : TalkBack lit le texte avec l'interrupteur.
            child: MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.upstreamAllowPlain,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.colors.encre,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(value: plainAllowed, onChanged: onPlainChanged),
                ],
              ),
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.colors.rommen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.dnsStrictMessage(server),
            style: TextStyle(fontSize: 14, color: context.colors.encre),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.bleu,
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
