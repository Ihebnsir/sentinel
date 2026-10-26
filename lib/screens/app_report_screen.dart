import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../models/installed_app.dart';
import '../services/app_analysis.dart';
import '../services/app_risk_calculator.dart';
import '../services/apps/stalkerware_ioc.dart';
import '../services/apps_scanner_service.dart';
import '../services/firewall_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon.dart';
import '../widgets/blocklist_sections.dart';
import 'app_detail_screen.dart';

// Couleur : celle du thème (dividerTheme, ligne fine).
const _divider = Divider(height: 1, thickness: 1);

TextStyle _muted(BuildContext context) =>
    TextStyle(fontSize: 13, color: context.colors.secondaire);

/// Rapport d'une analyse : résumé, compteurs, domaines par catégorie.
/// Renvoie true (Navigator.pop) si le rapport a été supprimé ou a expiré.
class AppReportScreen extends StatefulWidget {
  const AppReportScreen({
    super.key,
    required this.report,
    this.now = DateTime.now,
  });

  final AppReport report;

  /// Horloge (remplacée dans les tests).
  final DateTime Function() now;

  @override
  State<AppReportScreen> createState() => _AppReportScreenState();
}

class _AppReportScreenState extends State<AppReportScreen> {
  InstalledApp? _app; // null : app introuvable (désinstallée) ou hors Android
  AppRiskReport? _risk;

  Timer? _expiry; // ferme l'écran à l'expiration du rapport (SEN-14)

  @override
  void initState() {
    super.initState();
    final now = widget.now();
    final left = widget.report.isExpiredAt(now)
        ? Duration.zero
        : widget.report.expiresAt.difference(now);
    _expiry = Timer(left, _onExpired);
    _loadApp();
  }

  // Icône et écran détail : on retrouve l'app parmi celles installées.
  Future<void> _loadApp() async {
    try {
      final apps = await AppsScannerService().scanApps();
      final app = apps
          ?.where((a) => a.packageName == widget.report.packageName)
          .firstOrNull;
      if (app == null) return;
      StalkerwareIoc? ioc;
      try {
        ioc = await StalkerwareIoc.load();
      } on Exception {
        ioc = null; // le détail reste disponible avec les autres règles
      }
      if (!mounted) return;
      setState(() {
        _app = app;
        _risk = calculateAppRisk(app, ioc: ioc);
      });
    } on Exception {
      // Liste indisponible : le rapport s'affiche sans icône.
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  // Un rapport expiré n'est jamais affiché : on ferme l'écran, la liste
  // se recharge (le fichier est déjà supprimé ou le sera à la lecture).
  void _onExpired() {
    if (mounted) Navigator.of(context).pop(true);
  }

  void _openDetail() {
    final app = _app;
    final risk = _risk;
    if (app == null || risk == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppDetailScreen(app: app, report: risk),
      ),
    );
  }

  Future<void> _delete() async {
    await FirewallService().deleteReport(widget.report.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final report = widget.report;
    final app = _app;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.chaux,
        foregroundColor: context.colors.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          children: [
            Row(
              children: [
                if (app != null) ...[
                  AppIcon(app: app, size: 48),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Text(
                    report.appLabel,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: context.colors.encre,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l.reportDateLine(
                l.dateTime(report.startedAt),
                report.durationLabel(l),
              ),
              style: _muted(context),
            ),
            const SizedBox(height: 16),
            Text(
              report.summary(l),
              style: TextStyle(fontSize: 17, color: context.colors.encre),
            ),
            const SizedBox(height: 16),
            _divider,
            _CountRow(l.reportDomainsContacted, report.domains.length),
            _divider,
            _CountRow(
              l.reportDangerousSites,
              report.dangerousCount,
              color: report.dangerousCount > 0 ? context.colors.rommen : null,
            ),
            _divider,
            _CountRow(
              l.categoryTrackers,
              report.countOf(ReportCategory.trackers),
            ),
            _divider,
            _CountRow(l.categoryAds, report.countOf(ReportCategory.ads)),
            _divider,
            if (report.truncated)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l.reportTruncated, style: _muted(context)),
              ),
            for (final group in report.groups) ...[
              BlocklistSectionTitle(
                '${group.category.label(l)} (${l.number(group.domains.length)})',
              ),
              for (final domain in group.domains) ...[
                _DomainRow(domain),
                _divider,
              ],
            ],
            const SizedBox(height: 24),
            if (app != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.bleu,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: _openDetail,
                  child: Text(l.reportSeeApp),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.rommen,
                  padding: EdgeInsets.zero,
                ),
                onPressed: _delete,
                child: Text(l.reportDelete),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.reportLocalOnly(l.dateTime(report.expiresAt)),
              style: _muted(context),
            ),
            const SizedBox(height: 8),
            Text(l.reportApproximate, style: _muted(context)),
          ],
        ),
      ),
    );
  }
}

/// Ligne « libellé … nombre ».
class _CountRow extends StatelessWidget {
  const _CountRow(this.label, this.value, {this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: context.colors.secondaire),
            ),
          ),
          Text(
            context.l10n.number(value),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: color ?? context.colors.encre,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un domaine : nom, marque imitée, nombre de requêtes, bloqué ou non.
class _DomainRow extends StatelessWidget {
  const _DomainRow(this.domain);

  final ReportDomain domain;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final count = l.reportRequests(domain.count, l.number(domain.count));
    final brand = domain.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  domain.name,
                  style: TextStyle(fontSize: 15, color: context.colors.encre),
                ),
                if (brand != null)
                  Text(
                    l.reportImitates(brand),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.rommen,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(count, style: _muted(context)),
              if (domain.blocked)
                Text(
                  l.reportBlocked,
                  style: TextStyle(fontSize: 13, color: context.colors.zitouna),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
