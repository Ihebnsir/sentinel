import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../models/device_security_status.dart';
import '../models/security_action.dart';
import '../models/wifi_status.dart';
import '../services/device_security_service.dart';
import '../services/firewall_service.dart';
import '../services/weekly_report_service.dart';
import '../services/security_score_calculator.dart';
import '../services/wifi_risk.dart';
import '../services/wifi_service.dart';
import '../theme/app_colors.dart';
import '../widgets/action_tile.dart';
import '../widgets/arch_icon.dart';
import '../widgets/network_protection_section.dart';
import '../widgets/score_arch.dart';
import '../widgets/wifi_alert.dart';
import '../widgets/wifi_section.dart';
import 'settings_screen.dart';
import 'weekly_report_screen.dart';
import '../widgets/ui.dart';

/// L'écran d'accueil : salutation, score et actions conseillées.
/// StatefulWidget car il garde le résultat de l'audit en mémoire.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// WidgetsBindingObserver : permet d'être prévenu quand l'app revient au premier plan.
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _service = DeviceSecurityService();

  bool _loading = true; // vrai seulement pendant la toute première analyse
  bool _failed = false; // Android a renvoyé une erreur
  bool _auditRunning = false; // évite de lancer deux analyses en même temps
  DeviceSecurityStatus? _status; // null : analyse indisponible (Windows)

  // Wi-Fi : une situation, pas un réglage, donc hors du score.
  final _wifiService = WifiService();
  WifiStatus? _wifi; // null : pas encore lu ou indisponible
  bool _wifiLoaded = false; // première lecture terminée

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runAudit();
    _refreshWifi();
    _wifiService.startListening(_onWifiChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wifiService.stopListening();
    super.dispose();
  }

  // Retour dans l'app (ex : après un passage dans les paramètres) : on relance.
  // En arrière-plan, on arrête d'écouter le Wi-Fi.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runAudit();
      _refreshWifi();
      _wifiService.startListening(_onWifiChanged);
    } else if (state == AppLifecycleState.paused) {
      _wifiService.stopListening();
    }
  }

  /// Tirer vers le bas : analyse du téléphone et du Wi-Fi.
  Future<void> _refreshAll() async {
    await Future.wait([_runAudit(), _refreshWifi()]);
  }

  /// Lit l'état du Wi-Fi actuel.
  Future<void> _refreshWifi() async {
    WifiStatus? wifi;
    try {
      wifi = await _wifiService.getWifiStatus();
    } on Exception {
      wifi = null; // affiché « Information indisponible »
    }
    if (!mounted) return;
    setState(() {
      _wifi = wifi;
      _wifiLoaded = true;
    });
  }

  /// Le réseau a changé pendant que l'app est ouverte.
  void _onWifiChanged(WifiStatus wifi) {
    if (!mounted) return;
    final l = context.l10n;
    final previous = _wifi;
    final before = previous == null ? null : assessWifi(l, previous).level;
    final report = assessWifi(l, wifi);
    setState(() {
      _wifi = wifi;
      _wifiLoaded = true;
    });
    // Alerte seulement quand on passe d'un réseau sûr à un réseau dangereux.
    if (before != null &&
        before != WifiLevel.danger &&
        report.level == WifiLevel.danger) {
      showWifiAlert(
        context,
        message: l.homeWifiAlert(report.title),
        onDetails: _showWifiDetails,
      );
    }
  }

  /// Ouvre la feuille de détails du Wi-Fi.
  void _showWifiDetails() {
    final wifi = _wifi;
    if (wifi == null) return;
    showWifiDetails(
      context,
      status: wifi,
      report: assessWifi(context.l10n, wifi),
      onOpenPrivateDns: _wifiService.openPrivateDnsSettings,
    );
  }

  /// Demande l'état du téléphone à Android puis calcule le score.
  Future<void> _runAudit() async {
    if (_auditRunning) return;
    _auditRunning = true;
    try {
      final status = await _service.getSecurityStatus();
      // L'écran a pu être fermé pendant l'attente.
      if (!mounted) return;
      if (status != null) {
        // Bilan de la semaine : score de début et de fin de semaine.
        final score = calculateSecurityScore(
          context.l10n,
          status,
          DateTime.now(),
        ).score;
        unawaited(const WeeklyReportService().recordScore(score));
      }
      setState(() {
        _status = status;

        _failed = false;
        _loading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    } finally {
      _auditRunning = false;
    }
  }

  /// Titre principal selon l'état de l'analyse et le score.
  String _title(AppLocalizations l, SecurityReport? report) {
    if (_failed) return l.homeTitleFailed;
    if (report == null) return l.homeTitleDefault;
    if (report.actions.isEmpty || report.score >= 70) {
      return l.homeTitleProtected;
    }
    if (report.score >= 45) return l.homeTitleToImprove;
    return l.homeTitleExposed;
  }

  /// Ligne discrète sous l'arche, ex : « Android 15 · correctif du 5 août 2026 ».
  String _versionLine(AppLocalizations l, DeviceSecurityStatus status) {
    final patch = status.securityPatch;
    if (patch == null) return l.homeAndroidVersion(status.androidVersion);
    return l.homeAndroidVersionPatch(status.androidVersion, l.date(patch));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Calculés à chaque affichage : les textes suivent la langue choisie.
    final status = _status;
    final report = status == null
        ? null
        : calculateSecurityScore(l, status, DateTime.now());
    return Scaffold(
      body: SafeArea(
        // RefreshIndicator : tirer vers le bas relance l'analyse.
        child: RefreshIndicator(
          color: context.colors.bleu,
          onRefresh: _refreshAll,
          // AlwaysScrollable : on peut tirer même si l'écran ne déborde pas.
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.md,
              AppSpace.page,
              AppSpace.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre, et à droite l'accès discret aux réglages.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      // Centre la 1re ligne du titre sur l'engrenage.
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xs),
                        child: PageHeader(title: _title(l, report)),
                      ),
                    ),
                    IconButton(
                      tooltip: l.settingsTitle,
                      color: context.colors.secondaire,
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                // 1. Le score, 2. ce qu'il reste à faire, 3. les protections.
                ..._content(l, status, report),
                if (!_loading) ..._protections(l),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Le score et les actions conseillées, selon l'état de l'analyse.
  List<Widget> _content(
    AppLocalizations l,
    DeviceSecurityStatus? status,
    SecurityReport? report,
  ) {
    if (_loading) {
      return [Center(child: ScoreArch.empty(message: l.homeAnalyzing))];
    }
    if (_failed) {
      return [InfoMessage(l.commonAnalysisFailedPull)];
    }
    if (status == null || report == null) {
      return [InfoMessage(l.homeAndroidOnly)];
    }

    // Les plus importantes d'abord (celles qui rapportent le plus).
    final actions = [...report.actions]
      ..sort((a, b) => b.points.compareTo(a.points));
    return [
      Center(child: ScoreArch(score: report.score)),
      const SizedBox(height: AppSpace.md),
      Center(
        child: Text(
          _versionLine(l, status),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppText.detail,
            color: context.colors.discret,
          ),
        ),
      ),
      const SizedBox(height: AppSpace.section),
      SectionHeader(title: l.homeToGainPoints),
      if (actions.isEmpty)
        // Rien à faire : l'arche de Sentinel, comme les autres états vides.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          child: Row(
            children: [
              ExcludeSemantics(
                child: ArchIcon(
                  filled: true,
                  size: AppSize.appIconLarge,
                  color: context.colors.bleu,
                ),
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Text(
                  l.homeNothingToFix,
                  style: TextStyle(
                    fontSize: AppText.corps,
                    color: context.colors.secondaire,
                  ),
                ),
              ),
            ],
          ),
        ),
      // Une ligne par action, séparateur fin entre deux lignes.
      for (var i = 0; i < actions.length; i++) ...[
        if (i > 0) const AppDivider(),
        ActionTile(action: actions[i], onTap: _onTapFor(actions[i])),
      ],
    ];
  }

  /// « Vos protections » : Wi-Fi, pare-feu et bilan de la semaine.
  /// Hors Android (Windows), seules les lignes disponibles s'affichent.
  List<Widget> _protections(AppLocalizations l) {
    final wifi = _wifi;
    final rows = <Widget>[
      if (WifiService.isSupported && _wifiLoaded)
        WifiSection(
          report: wifi == null ? null : assessWifi(l, wifi),
          onTap: _showWifiDetails,
          showTitle: false,
        ),
      if (FirewallService.isSupported)
        const NetworkProtectionSection(showTitle: false),
      if (WeeklyReportService.isSupported)
        _WeeklyEntry(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const WeeklyReportScreen()),
          ),
        ),
    ];
    if (rows.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpace.section),
      SectionHeader(title: l.homeProtections),
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const AppDivider(),
        rows[i],
      ],
    ];
  }

  /// Tap sur une action : ouvre le bon écran des paramètres Android.
  /// Pas de cible (root) : null, la ligne n'est pas cliquable.
  VoidCallback? _onTapFor(SecurityAction action) {
    final target = action.settingsTarget;
    if (target == null) return null;
    return () => _service.openSettings(target);
  }
}

/// Entrée discrète vers le « Bilan de la semaine ».
class _WeeklyEntry extends StatelessWidget {
  const _WeeklyEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListRow(
      icon: Icons.insights_outlined,
      title: l.weeklyTitle,
      subtitle: l.weeklyHomeEntryDetail,
      onTap: onTap,
      chevron: true,
    );
  }
}
