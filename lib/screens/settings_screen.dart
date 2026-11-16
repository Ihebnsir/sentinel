import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../l10n/l10n.dart';
import '../services/apps_scanner_service.dart';
import '../services/language_store.dart';
import '../services/protection_service.dart';
import '../services/theme_store.dart';
import '../services/weekly_report_service.dart';
import '../theme/app_colors.dart';
import '../widgets/arch_icon.dart';
import 'audit_summary_screen.dart';
import 'onboarding_screen.dart';
import 'privacy_policy_screen.dart';

/// Réglages / À propos, ouvert par l'icône discrète de l'accueil.
/// [openUrl] : remplaçable dans les tests (par défaut, le navigateur).
/// [weekly] et [requestNotifications] : idem (bilan de la semaine).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.openUrl,
    this.weekly = const WeeklyReportService(),
    this.requestNotifications,
  });

  final void Function(String url)? openUrl;
  final WeeklyReportService weekly;
  final Future<bool> Function()? requestNotifications;

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
      applicationIcon: Padding(
        padding: EdgeInsets.all(12),
        child: ArchIcon(filled: true, size: 48, color: context.colors.bleu),
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
      backgroundColor: context.colors.chaux,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final code in [null, ...languageNames.keys])
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                title: Text(
                  code == null ? l.settingsLanguageSystem : languageNames[code]!,
                  style: TextStyle(fontSize: 15, color: context.colors.encre),
                ),
                trailing: code == current
                    ? Icon(Icons.check, color: context.colors.bleu)
                    : null,
                onTap: () => Navigator.of(context).pop(_LanguageChoice(code)),
              ),
          ],
        ),
      ),
    );
    if (choice != null) await language.choose(choice.code);
  }

  // Clair, sombre ou comme le téléphone.
  Future<void> _chooseTheme(BuildContext context, ThemeController theme) async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colors.chaux,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in themeModes)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                title: Text(
                  themeModeLabel(l, mode),
                  style: TextStyle(fontSize: 15, color: context.colors.encre),
                ),
                trailing: mode == theme.value
                    ? Icon(Icons.check, color: context.colors.bleu)
                    : null,
                onTap: () => Navigator.of(context).pop(mode),
              ),
          ],
        ),
      ),
    );
    if (choice != null) await theme.choose(choice);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Absents quand l'écran est testé seul : lignes Langue et Apparence
    // masquées.
    final language = LanguageScope.maybeOf(context);
    final theme = ThemeScope.maybeOf(context);
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
      if (theme != null)
        _Row(
          icon: Icons.dark_mode_outlined,
          title: l.settingsTheme,
          subtitle: themeModeLabel(l, theme.value),
          onTap: () => _chooseTheme(context, theme),
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
            Text(
              l.settingsTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ArchIcon(filled: true, size: 32, color: context.colors.bleu),
                const SizedBox(width: 16),
                Text(
                  l.settingsAppVersion(appVersion),
                  style: TextStyle(fontSize: 16, color: context.colors.encre),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Une ligne fine entre deux réglages, comme sur l'accueil.
            for (final row in rows) ...[
              Divider(height: 1, thickness: 1, color: context.colors.ligne),
              row,
            ],
            // Masquée hors Android (rien n'écoute le canal).
            _WeeklyNotificationRow(
              service: weekly,
              requestNotifications:
                  requestNotifications ??
                  ProtectionService().requestNotificationPermission,
            ),
          ],
        ),
      ),
    );
  }
}

/// Noms des langues, chacun écrit dans sa propre langue.
const languageNames = {'fr': 'Français', 'ar': 'العربية', 'en': 'English'};

/// Choix du thème, dans l'ordre affiché.
const themeModes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

String themeModeLabel(AppLocalizations l, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l.settingsThemeSystem,
  ThemeMode.light => l.settingsThemeLight,
  ThemeMode.dark => l.settingsThemeDark,
};

/// Choix dans la liste des langues (code null : langue du téléphone).
class _LanguageChoice {
  const _LanguageChoice(this.code);

  final String? code;
}

/// Notification hebdomadaire du bilan (désactivée par défaut).
class _WeeklyNotificationRow extends StatefulWidget {
  const _WeeklyNotificationRow({
    required this.service,
    required this.requestNotifications,
  });

  final WeeklyReportService service;
  final Future<bool> Function() requestNotifications;

  @override
  State<_WeeklyNotificationRow> createState() => _WeeklyNotificationRowState();
}

class _WeeklyNotificationRowState extends State<_WeeklyNotificationRow> {
  bool? _enabled; // null : option indisponible, ligne masquée

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await widget.service.notificationsEnabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _toggle(bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final denied = context.l10n.settingsWeeklyNotificationDenied;
    // Android 13+ : l'autorisation est demandée au moment d'activer.
    if (value && !await widget.requestNotifications()) {
      messenger.showSnackBar(SnackBar(content: Text(denied)));
      return;
    }
    await widget.service.setNotificationsEnabled(value);
    if (mounted) setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    if (enabled == null) return const SizedBox.shrink();
    final l = context.l10n;
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: context.colors.ligne),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(
            Icons.notifications_none,
            color: context.colors.secondaire,
          ),

          title: Text(
            l.settingsWeeklyNotification,
            style: TextStyle(fontSize: 15, color: context.colors.encre),
          ),
          subtitle: Text(
            l.settingsWeeklyNotificationDetail,
            style: TextStyle(fontSize: 13, color: context.colors.discret),
          ),
          value: enabled,
          onChanged: _toggle,
        ),
      ],
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
      leading: Icon(icon, color: context.colors.secondaire),
      title: Text(
        title,
        style: TextStyle(fontSize: 15, color: context.colors.encre),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.discret,
              ),
            ),
      onTap: onTap,
    );
  }
}
