import 'package:material_ui/material_ui.dart';

import '../models/wifi_status.dart';
import '../services/wifi_risk.dart';
import '../theme/app_colors.dart';

/// Couleur selon le niveau du Wi-Fi.
Color wifiLevelColor(WifiLevel level) => switch (level) {
  WifiLevel.danger => AppColors.rommen,
  WifiLevel.faible => AppColors.ocre,
  WifiLevel.correct || WifiLevel.excellent => AppColors.zitouna,
  WifiLevel.pasDeWifi ||
  WifiLevel.inconnu => AppColors.encre.withValues(alpha: 0.45),
};

/// Section « Réseau Wi-Fi » de l'accueil : titre et une ligne.
/// [report] null : information indisponible (ligne non cliquable).
class WifiSection extends StatelessWidget {
  const WifiSection({super.key, required this.report, this.onTap});

  final WifiReport? report;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    final color = report == null
        ? AppColors.encre.withValues(alpha: 0.45)
        : wifiLevelColor(report.level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Réseau Wi-Fi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.encre,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: report == null ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Icon(
                  report?.level == WifiLevel.pasDeWifi
                      ? Icons.wifi_off
                      : Icons.wifi,
                  color: color,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report?.title ?? 'Information indisponible',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.encre,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report?.summary ??
                            "Android n'a pas pu lire l'état du Wi-Fi.",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.encre.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (report != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    report.level.label,
                    style: TextStyle(fontWeight: FontWeight.w600, color: color),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Feuille de détails : explication, état du réseau et conseils.
Future<void> showWifiDetails(
  BuildContext context, {
  required WifiStatus status,
  required WifiReport report,
  required VoidCallback onOpenPrivateDns,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.chaux,
    elevation: 0,
    showDragHandle: true,
    // La feuille peut dépasser la moitié de l'écran si besoin.
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
        child: _WifiDetails(
          status: status,
          report: report,
          onOpenPrivateDns: onOpenPrivateDns,
        ),
      ),
    ),
  );
}

class _WifiDetails extends StatelessWidget {
  const _WifiDetails({
    required this.status,
    required this.report,
    required this.onOpenPrivateDns,
  });

  final WifiStatus status;
  final WifiReport report;
  final VoidCallback onOpenPrivateDns;

  String get _dnsText => switch (status.privateDnsActive) {
    true => 'Activé',
    false => 'Désactivé',
    null => 'Inconnu',
  };

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.encre.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          report.level.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: wifiLevelColor(report.level),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          report.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.encre,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          report.explanation,
          style: const TextStyle(fontSize: 15, color: AppColors.encre),
        ),
        if (status.connected) ...[
          const SizedBox(height: 20),
          _InfoRow(label: 'Protection', value: status.security.label),
          const Divider(height: 1, thickness: 1, color: AppColors.ligne),
          _InfoRow(
            label: 'Page de connexion',
            value: status.captivePortal ? 'Oui' : 'Non',
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.ligne),
          _InfoRow(label: 'DNS privé', value: _dnsText),
        ],
        if (report.advice.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Nos conseils',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.encre,
            ),
          ),
          const SizedBox(height: 8),
          for (final tip in report.advice)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: AppColors.bleu,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.encre,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (report.suggestPrivateDns) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.bleu,
                elevation: 0,
              ),
              onPressed: onOpenPrivateDns,
              child: const Text('Activer le DNS privé'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ouvre « Réseau et Internet ». Le DNS privé se trouve parfois '
            'sous « Avancé » ou « Plus de paramètres de connexion ».',
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
      ],
    );
  }
}

/// Une ligne « libellé … valeur » des détails.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.encre.withValues(alpha: 0.6),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.encre,
            ),
          ),
        ],
      ),
    );
  }
}
