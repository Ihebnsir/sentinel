import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../models/device_security_status.dart';
import '../models/security_action.dart';
import '../models/wifi_status.dart';
import '../services/device_security_service.dart';
import '../services/firewall_service.dart';
import '../services/security_score_calculator.dart';
import '../services/wifi_risk.dart';
import '../services/wifi_service.dart';
import '../theme/app_colors.dart';
import '../widgets/action_tile.dart';
import '../widgets/network_protection_section.dart';
import '../widgets/score_arch.dart';
import '../widgets/wifi_alert.dart';
import '../widgets/wifi_section.dart';
import 'settings_screen.dart';

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
    final wifi = _wifi;
    final wifiReport = wifi == null ? null : assessWifi(l, wifi);
    return Scaffold(
      body: SafeArea(
        // RefreshIndicator : tirer vers le bas relance l'analyse.
        child: RefreshIndicator(
          color: context.colors.bleu,
          onRefresh: _refreshAll,
          // AlwaysScrollable : on peut tirer même si l'écran ne déborde pas.
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Salutation, et à droite l'accès discret aux réglages.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.homeGreeting,
                        style: TextStyle(
                          fontSize: 16,
                          color: context.colors.secondaire,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l.settingsTitle,
                      visualDensity: VisualDensity.compact,
                      color: context.colors.encre.withValues(alpha: 0.5),
                      icon: const Icon(Icons.settings_outlined, size: 22),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _title(l, report),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: context.colors.encre,
                  ),
                ),
                const SizedBox(height: 40),
                ..._content(l, status, report),
                // Hors Android (Windows) : section masquée.
                if (WifiService.isSupported && _wifiLoaded && !_loading) ...[
                  const SizedBox(height: 32),
                  WifiSection(report: wifiReport, onTap: _showWifiDetails),
                ],
                if (FirewallService.isSupported && !_loading) ...[
                  const SizedBox(height: 32),
                  const NetworkProtectionSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Le contenu sous le titre, selon l'état de l'analyse.
  List<Widget> _content(
    AppLocalizations l,
    DeviceSecurityStatus? status,
    SecurityReport? report,
  ) {
    if (_loading) {
      return [Center(child: ScoreArch.empty(message: l.homeAnalyzing))];
    }
    if (_failed) {
      return [_InfoMessage(l.commonAnalysisFailedPull)];
    }
    if (status == null || report == null) {
      return [_InfoMessage(l.homeAndroidOnly)];
    }

    final actions = report.actions;
    return [
      Center(child: ScoreArch(score: report.score)),
      const SizedBox(height: 12),
      Center(
        child: Text(
          _versionLine(l, status),
          style: TextStyle(
            fontSize: 13,
            color: context.colors.encre.withValues(alpha: 0.5),
          ),
        ),
      ),
      const SizedBox(height: 40),
      Text(
        l.homeToGainPoints,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.colors.encre,
        ),
      ),
      const SizedBox(height: 8),
      if (actions.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            l.homeNothingToFix,
            style: TextStyle(fontSize: 15, color: context.colors.secondaire),
          ),
        ),
      // Boucle for dans la liste : on crée une ligne par action,
      // avec un séparateur fin entre deux lignes (pas avant la première).
      for (var i = 0; i < actions.length; i++) ...[
        if (i > 0)
          Divider(height: 1, thickness: 1, color: context.colors.ligne),
        ActionTile(action: actions[i], onTap: _onTapFor(actions[i])),
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

/// Message centré affiché à la place de l'arche.
class _InfoMessage extends StatelessWidget {
  const _InfoMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: context.colors.secondaire),
        ),
      ),
    );
  }
}
