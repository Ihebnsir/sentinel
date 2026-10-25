import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../services/apps_scanner_service.dart';
import '../theme/app_colors.dart';
import '../widgets/text_page.dart';

/// Résumé du rapport docs/audit/RAPPORT_AUDIT.md (à mettre à jour avec lui).
const auditSections = [
  TextSection('Le cadre', [
    'Audit de sécurité selon le référentiel OWASP MASVS v2, du 21 au 24 '
        'octobre 2026, sur Sentinel 1.0.0 : analyse du code, du trafic '
        'réseau, du stockage et des composants Android.',
    "Il a été mené pour le propriétaire de l'application, sur son propre "
        "code : ce n'est pas un audit indépendant.",
  ]),
  TextSection('Les résultats', [
    '17 constats, dont un de sévérité élevée et quatre moyens.',
    '14 sont corrigés, chacun avec un test automatique. 3 sont acceptés en '
        "connaissance de cause (modèle anti-arnaque lisible car l'app est "
        'open source, pas d\'épinglage de certificat, un constat déjà '
        'conforme).',
    "Depuis, le pare-feu chiffre toutes ses requêtes et l'app ne contacte "
        'plus rien sans accord.',
  ]),
  TextSection('Les limites', [
    'Aucune application n\'est sûre à 100 %. Les principaux risques '
        'restants dépendent du téléphone : un Android trop ancien, ou un '
        'logiciel espion à qui l\'on a donné l\'accessibilité ou le root.',
  ]),
];

class AuditSummaryScreen extends StatelessWidget {
  const AuditSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TextPage(
      title: "Rapport d'audit de sécurité",
      sections: auditSections,
      footer: Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.bleu,
            padding: EdgeInsets.zero,
          ),
          onPressed: () => AppsScannerService().openWebPage(auditReportUrl),
          child: const Text('Lire le rapport complet sur GitHub'),
        ),
      ),
    );
  }
}
