import 'package:material_ui/material_ui.dart';

import '../services/firewall_service.dart';
import '../theme/app_colors.dart';

const _divider = Divider(height: 1, thickness: 1, color: AppColors.ligne);

/// Texte de l'état du DNS vers Quad9 (SEN-10).
String upstreamLabel(UpstreamMode mode) => switch (mode) {
  UpstreamMode.idle => 'En attente de la première requête',
  UpstreamMode.dot => 'Chiffré (DNS-over-TLS)',
  UpstreamMode.doh => 'Chiffré (DNS-over-HTTPS)',
  UpstreamMode.plain => 'Non chiffré : autorisé sur ce réseau',
  UpstreamMode.failing => 'Quad9 injoignable de façon chiffrée',
};

/// Explication quand le DNS chiffré ne passe pas sur ce réseau.
const upstreamFailingHelp =
    "Ce réseau bloque le DNS chiffré : les sites ne s'ouvrent pas. Sentinel "
    "n'envoie jamais vos requêtes en clair sans votre accord. Si vous faites "
    'confiance à ce réseau, vous pouvez l\'autoriser ci-dessous : les noms '
    'des sites visités deviendront alors visibles sur le réseau.';

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
    final muted = AppColors.encre.withValues(alpha: 0.6);
    final warning = mode == UpstreamMode.failing || mode == UpstreamMode.plain;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Requêtes vers Quad9',
                  style: TextStyle(fontSize: 15, color: AppColors.encre),
                ),
              ),
              Flexible(
                child: Text(
                  upstreamLabel(mode),
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
                upstreamFailingHelp,
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
          _divider,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Autoriser le DNS non chiffré sur ce réseau',
                    style: TextStyle(fontSize: 15, color: AppColors.encre),
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

/// Texte de l'avertissement « DNS privé strict » (SEN-11).
String strictPrivateDnsMessage(String server) =>
    'Votre DNS privé est réglé sur « $server » (mode strict). Avec le '
    "pare-feu, plus aucun site ne s'ouvrirait. Choisissez « Automatique » "
    'dans les réglages : Sentinel chiffre déjà vos requêtes DNS.';

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DNS privé incompatible',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.rommen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strictPrivateDnsMessage(server),
            style: const TextStyle(fontSize: 14, color: AppColors.encre),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.bleu,
              padding: EdgeInsets.zero,
            ),
            onPressed: onOpenSettings,
            child: const Text('Ouvrir les réglages du DNS privé'),
          ),
        ],
      ),
    );
  }
}
