import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../models/wifi_status.dart';
import '../services/wifi_risk.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Statut selon le niveau du Wi-Fi.
StatusLevel wifiStatus(WifiLevel level) => switch (level) {
  WifiLevel.danger => StatusLevel.danger,
  WifiLevel.faible => StatusLevel.warning,
  WifiLevel.correct || WifiLevel.excellent => StatusLevel.ok,
  WifiLevel.pasDeWifi || WifiLevel.inconnu => StatusLevel.neutral,
};

/// Couleur selon le niveau du Wi-Fi.
Color wifiLevelColor(AppColors c, WifiLevel level) =>
    wifiStatus(level).color(c);

/// Section « Réseau Wi-Fi » de l'accueil : une ligne et son statut.
/// [report] null : information indisponible (ligne non cliquable).
/// [showTitle] false : l'accueil la range sous « Vos protections ».
class WifiSection extends StatelessWidget {
  const WifiSection({
    super.key,
    required this.report,
    this.onTap,
    this.showTitle = true,
  });

  final WifiReport? report;
  final VoidCallback? onTap;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final report = this.report;
    final level = report == null
        ? StatusLevel.neutral
        : wifiStatus(report.level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) SectionHeader(title: l.wifiSectionTitle),
        ListRow(
          icon: report?.level == WifiLevel.pasDeWifi
              ? Icons.wifi_off
              : Icons.wifi,
          iconColor: level.color(context.colors),
          title: report?.title ?? l.wifiUnavailableTitle,
          subtitle: report?.summary ?? l.wifiUnavailableSummary,
          onTap: report == null ? null : onTap,
          trailing: report == null
              ? null
              : StatusBadge(level: level, label: report.level.label(l)),
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
        StatusBadge(
          level: wifiStatus(report.level),
          label: report.level.label(l),
        ),
        const SizedBox(height: AppSpace.sm),
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
