import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../services/apps_scanner_service.dart';
import '../theme/app_colors.dart';
import '../widgets/arch_icon.dart';
import 'audit_summary_screen.dart';
import 'onboarding_screen.dart';
import 'privacy_policy_screen.dart';

/// Réglages / À propos, ouvert par l'icône discrète de l'accueil.
/// [openUrl] : remplaçable dans les tests (par défaut, le navigateur).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.openUrl});

  final void Function(String url)? openUrl;

  void _open(String url) =>
      (openUrl ?? AppsScannerService().openWebPage).call(url);

  void _push(BuildContext context, Widget Function(BuildContext) builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'Sentinel',
      applicationVersion: appVersion,
      applicationIcon: const Padding(
        padding: EdgeInsets.all(12),
        child: ArchIcon(filled: true, size: 48, color: AppColors.bleu),
      ),
      applicationLegalese: 'Licence MIT',
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _Row(
        icon: Icons.replay,
        title: 'Revoir la présentation',
        onTap: () => _push(
          context,
          (route) => OnboardingScreen(onDone: () => Navigator.of(route).pop()),
        ),
      ),
      _Row(
        icon: Icons.privacy_tip_outlined,
        title: 'Politique de confidentialité',
        onTap: () => _push(context, (_) => const PrivacyPolicyScreen()),
      ),
      _Row(
        icon: Icons.description_outlined,
        title: 'Licences',
        subtitle: 'Bibliothèques, police, listes de blocage, logiciels espions',
        onTap: () => _showLicenses(context),
      ),
      _Row(
        icon: Icons.verified_user_outlined,
        title: "Rapport d'audit de sécurité",
        onTap: () => _push(context, (_) => const AuditSummaryScreen()),
      ),
      _Row(
        icon: Icons.bug_report_outlined,
        title: 'Signaler une faille',
        subtitle: 'En privé, via GitHub (ouvre le navigateur)',
        onTap: () => _open(securityPolicyUrl),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.chaux,
        foregroundColor: AppColors.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          children: [
            const Text(
              'Réglages',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const ArchIcon(filled: true, size: 32, color: AppColors.bleu),
                const SizedBox(width: 16),
                Text(
                  'Sentinel $appVersion',
                  style: const TextStyle(fontSize: 16, color: AppColors.encre),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Une ligne fine entre deux réglages, comme sur l'accueil.
            for (final row in rows) ...[
              const Divider(height: 1, thickness: 1, color: AppColors.ligne),
              row,
            ],
          ],
        ),
      ),
    );
  }
}

/// Une ligne de réglage : icône, titre, détail facultatif.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.encre.withValues(alpha: 0.6)),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, color: AppColors.encre),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.encre.withValues(alpha: 0.5),
              ),
            ),
      onTap: onTap,
    );
  }
}
