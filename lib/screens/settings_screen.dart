import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../l10n/l10n.dart';
import '../services/apps_scanner_service.dart';
import '../services/language_store.dart';
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
    final l = context.l10n;
    showLicensePage(
      context: context,
      applicationName: 'Sentinel',
      applicationVersion: appVersion,
      applicationIcon: const Padding(
        padding: EdgeInsets.all(12),
        child: ArchIcon(filled: true, size: 48, color: AppColors.bleu),
      ),
      applicationLegalese: l.settingsLicenseLegalese,
    );
  }

  // Liste des langues ; null : celle du téléphone.
  Future<void> _chooseLanguage(
    BuildContext context,
    LanguageController language,
  ) async {
    final current = language.value?.languageCode;
    final l = context.l10n;
    final choice = await showModalBottomSheet<_LanguageChoice>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.chaux,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final code in [null, ...languageNames.keys])
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                title: Text(
                  code == null ? l.settingsLanguageSystem : languageNames[code]!,
                  style: const TextStyle(fontSize: 15, color: AppColors.encre),
                ),
                trailing: code == current
                    ? const Icon(Icons.check, color: AppColors.bleu)
                    : null,
                onTap: () => Navigator.of(context).pop(_LanguageChoice(code)),
              ),
          ],
        ),
      ),
    );
    if (choice != null) await language.choose(choice.code);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Absent quand l'écran est testé seul : la ligne Langue est masquée.
    final language = LanguageScope.maybeOf(context);
    final code = language?.value?.languageCode;
    final rows = <Widget>[
      if (language != null)
        _Row(
          icon: Icons.translate,
          title: l.settingsLanguage,
          subtitle: code == null
              ? l.settingsLanguageSystem
              : languageNames[code] ?? code,
          onTap: () => _chooseLanguage(context, language),
        ),
      _Row(
        icon: Icons.replay,
        title: l.settingsReplayOnboarding,
        onTap: () => _push(
          context,
          (route) => OnboardingScreen(onDone: () => Navigator.of(route).pop()),
        ),
      ),
      _Row(
        icon: Icons.privacy_tip_outlined,
        title: l.settingsPrivacy,
        onTap: () => _push(context, (_) => const PrivacyPolicyScreen()),
      ),
      _Row(
        icon: Icons.description_outlined,
        title: l.settingsLicenses,
        subtitle: l.settingsLicensesDetail,
        onTap: () => _showLicenses(context),
      ),
      _Row(
        icon: Icons.verified_user_outlined,
        title: l.settingsAudit,
        onTap: () => _push(context, (_) => const AuditSummaryScreen()),
      ),
      _Row(
        icon: Icons.bug_report_outlined,
        title: l.settingsReportFlaw,
        subtitle: l.settingsReportFlawDetail,
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
            Text(
              l.settingsTitle,
              style: const TextStyle(
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
                  l.settingsAppVersion(appVersion),
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

/// Noms des langues, chacun écrit dans sa propre langue.
const languageNames = {'fr': 'Français', 'ar': 'العربية', 'en': 'English'};

/// Choix dans la liste des langues (code null : langue du téléphone).
class _LanguageChoice {
  const _LanguageChoice(this.code);

  final String? code;
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
