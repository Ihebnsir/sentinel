import 'package:material_ui/material_ui.dart';

import '../services/app_analysis.dart';
import '../theme/app_colors.dart';
import '../utils/french_date.dart';
import '../utils/french_number.dart';
import 'blocklist_sections.dart';

const _divider = Divider(height: 1, thickness: 1, color: AppColors.ligne);

TextStyle get _muted =>
    TextStyle(fontSize: 13, color: AppColors.encre.withValues(alpha: 0.6));

/// Ex : « 19 octobre 2026 à 14 h 05 ».
String formatFrenchDateTime(DateTime date) {
  final minutes = date.minute.toString().padLeft(2, '0');
  return '${formatFrenchDate(date)} à ${date.hour} h $minutes';
}

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
    final running = analysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BlocklistSectionTitle('Analyser une application'),
        if (running != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analyse de ${running.appLabel} en cours',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.encre,
                  ),
                ),
                const SizedBox(height: 2),
                Text(running.progressAt(DateTime.now()), style: _muted),
                const SizedBox(height: 4),
                const Text(
                  'Les autres applications ne sont pas protégées par le '
                  "pare-feu jusqu'à la fin de l'analyse.",
                  style: TextStyle(fontSize: 13, color: AppColors.ocre),
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
              child: const Text("Arrêter l'analyse"),
            ),
          ),
        ] else ...[
          Text(
            firewallActive
                ? 'Découvrez quels sites une application contacte pendant '
                      'quelques minutes : traqueurs, publicités, sites dangereux.'
                : 'Activez le pare-feu pour analyser une application.',
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
                child: const Text('Choisir une application'),
              ),
            ),
        ],
        if (reports.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Rapports des dernières 24 heures', style: _muted),
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
                            '${_domains(report.domains.length)} · '
                            '${formatFrenchDateTime(report.endedAt)}',
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

  static String _domains(int n) =>
      '${formatFrenchNumber(n)} ${n > 1 ? 'domaines' : 'domaine'}';
}
