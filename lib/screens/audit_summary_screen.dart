import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../l10n/l10n.dart';
import '../services/apps_scanner_service.dart';
import '../theme/app_colors.dart';
import '../widgets/text_page.dart';

/// Résumé du rapport docs/audit/RAPPORT_AUDIT.md (à mettre à jour avec lui).
List<TextSection> auditSections(AppLocalizations l) => [
  TextSection(l.auditFrameTitle, [l.auditFrame1, l.auditFrame2]),
  TextSection(l.auditResultsTitle, [
    l.auditResults1,
    l.auditResults2,
    l.auditResults3,
  ]),
  TextSection(l.auditLimitsTitle, [l.auditLimits1]),
];

class AuditSummaryScreen extends StatelessWidget {
  const AuditSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextPage(
      title: l.settingsAudit,
      sections: auditSections(l),
      footer: Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: context.colors.bleu,
            padding: EdgeInsets.zero,
          ),
          onPressed: () => AppsScannerService().openWebPage(auditReportUrl),
          child: Text(l.auditReadFull),
        ),
      ),
    );
  }
}
