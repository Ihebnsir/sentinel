import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/app_analysis.dart';
import '../theme/app_colors.dart';
import 'blocklist_sections.dart';

const _divider = Divider(height: 1, thickness: 1, color: AppColors.ligne);

TextStyle get _muted =>
    TextStyle(fontSize: 13, color: AppColors.encre.withValues(alpha: 0.6));

/// « Analyser une application » sur l'écran du pare-feu : lancement,
/// analyse en cours et rapports des dernières 24 heures.
class AppAnalysisSection extends StatelessWidget {
  const AppAnalysisSection({
    super.key,
    required this.firewallActive,
    required this.analysis,
    required this.reports,
    required this.onChoose,
    required this.onStop,
    required this.onOpenReport,
  });

  final bool firewallActive;
  final AnalysisStatus? analysis; // null : aucune analyse en cours
  final List<AppReport> reports;
  final VoidCallback onChoose;
  final VoidCallback onStop;
  final ValueChanged<AppReport> onOpenReport;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final running = analysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BlocklistSectionTitle(l.analysisSectionTitle),
        if (running != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.analysisRunning(running.appLabel),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.encre,
                  ),
                ),
                const SizedBox(height: 2),
                Text(running.progressAt(l, DateTime.now()), style: _muted),
                const SizedBox(height: 4),
                Text(
                  l.analysisUnprotectedWarning,
                  style: const TextStyle(fontSize: 13, color: AppColors.ocre),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.rommen,
                padding: EdgeInsets.zero,
              ),
              onPressed: onStop,
              child: Text(l.analysisStop),
            ),
          ),
        ] else ...[
          Text(
            firewallActive ? l.analysisIntroActive : l.analysisIntroInactive,
            style: _muted,
          ),
          if (firewallActive)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.bleu,
                  padding: EdgeInsets.zero,
                ),
                onPressed: onChoose,
                child: Text(l.analysisChooseApp),
              ),
            ),
        ],
        if (reports.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(l.analysisRecentReports, style: _muted),
          const SizedBox(height: 4),
          _divider,
          for (final report in reports) ...[
            InkWell(
              onTap: () => onOpenReport(report),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.appLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.encre,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_domains(l, report.domains.length)} · '
                            '${l.dateTime(report.endedAt)}',
                            style: _muted,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.encre.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
            _divider,
          ],
        ],
      ],
    );
  }

  static String _domains(AppLocalizations l, int n) =>
      l.domainsCount(n, l.number(n));
}
