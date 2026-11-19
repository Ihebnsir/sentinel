import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../models/wifi_status.dart';
import '../services/wifi_risk.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Couleur selon le niveau du Wi-Fi.
Color wifiLevelColor(AppColors c, WifiLevel level) => switch (level) {
  WifiLevel.danger => c.rommen,
  WifiLevel.faible => c.ocre,
  WifiLevel.correct || WifiLevel.excellent => c.zitouna,
  WifiLevel.pasDeWifi || WifiLevel.inconnu => c.discret,
};

/// Section « Réseau Wi-Fi » de l'accueil : titre et une ligne.
/// [report] null : information indisponible (ligne non cliquable).
class WifiSection extends StatelessWidget {
  const WifiSection({super.key, required this.report, this.onTap});

  final WifiReport? report;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final report = this.report;
    final color = report == null
        ? context.colors.discret
        : wifiLevelColor(context.colors, report.level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.wifiSectionTitle,
          style: TextStyle(
            fontSize: AppText.section,
            fontWeight: FontWeight.w600,
            color: context.colors.encre,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        InkWell(
          onTap: report == null ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
            child: Row(
              children: [
                Icon(
                  report?.level == WifiLevel.pasDeWifi
                      ? Icons.wifi_off
                      : Icons.wifi,
                  color: color,
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report?.title ?? l.wifiUnavailableTitle,
                        style: TextStyle(
                          fontSize: AppText.intitule,
                          fontWeight: FontWeight.w500,
                          color: context.colors.encre,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        report?.summary ?? l.wifiUnavailableSummary,
                        style: TextStyle(
                          fontSize: AppText.detail,
                          color: context.colors.secondaire,
                        ),
                      ),
                    ],
                  ),
                ),
                if (report != null) ...[
                  const SizedBox(width: AppSpace.md),
                  Text(
                    report.level.label(l),
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
    backgroundColor: context.colors.chaux,
    elevation: 0,
    showDragHandle: true,
    // La feuille peut dépasser la moitié de l'écran si besoin.
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, AppSpace.xl),
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

  String _dnsText(AppLocalizations l) => switch (status.privateDnsActive) {
    true => l.commonOn,
    false => l.commonOff,
    null => l.commonUnknown,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = context.colors.secondaire;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          report.level.label(l),
          style: TextStyle(
            fontSize: AppText.corps,
            fontWeight: FontWeight.w600,
            color: wifiLevelColor(context.colors, report.level),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          report.title,
          style: TextStyle(
            fontSize: AppText.titreSecondaire,
            fontWeight: FontWeight.w600,
            color: context.colors.encre,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          report.explanation,
          style: TextStyle(fontSize: AppText.corps, color: context.colors.encre),
        ),
        if (status.connected) ...[
          const SizedBox(height: AppSpace.xl),
          _InfoRow(
            label: l.wifiDetailProtection,
            value: status.security.label(l),
          ),
          const AppDivider(),
          _InfoRow(
            label: l.wifiDetailCaptive,
            value: status.captivePortal ? l.commonYes : l.commonNo,
          ),
          const AppDivider(),
          _InfoRow(label: l.wifiDetailPrivateDns, value: _dnsText(l)),
        ],
        if (report.advice.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xl),
          Text(
            l.wifiOurAdvice,
            style: TextStyle(
              fontSize: AppText.section,
              fontWeight: FontWeight.w600,
              color: context.colors.encre,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          for (final tip in report.advice)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: AppSpace.xs),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: AppSize.iconSmall,
                      color: context.colors.bleu,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontSize: AppText.corps,
                        color: context.colors.encre,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (report.suggestPrivateDns) ...[
          const SizedBox(height: AppSpace.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onOpenPrivateDns,
              child: Text(l.wifiEnablePrivateDns),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            l.wifiPrivateDnsHelp,
            style: TextStyle(fontSize: AppText.detail, color: muted),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: AppText.corps, color: context.colors.secondaire),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: AppText.corps,
              fontWeight: FontWeight.w500,
              color: context.colors.encre,
            ),
          ),
        ],
      ),
    );
  }
}
