import 'package:material_ui/material_ui.dart';

import '../models/device_security_status.dart';
import '../models/security_action.dart';
import '../models/wifi_status.dart';
import '../services/device_security_service.dart';
import '../services/firewall_service.dart';
import '../services/security_score_calculator.dart';
import '../services/wifi_risk.dart';
import '../services/wifi_service.dart';
import '../theme/app_colors.dart';
import '../utils/french_date.dart';
import '../widgets/action_tile.dart';
import '../widgets/network_protection_section.dart';
import '../widgets/score_arch.dart';
import '../widgets/wifi_section.dart';

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
  SecurityReport? _report;

  // Wi-Fi : une situation, pas un réglage, donc hors du score.
  final _wifiService = WifiService();
  WifiStatus? _wifi; // null : pas encore lu ou indisponible
  WifiReport? _wifiReport;
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
      _wifiReport = wifi == null ? null : assessWifi(wifi);
      _wifiLoaded = true;
    });
  }

  /// Le réseau a changé pendant que l'app est ouverte.
  void _onWifiChanged(WifiStatus wifi) {
    if (!mounted) return;
    final before = _wifiReport?.level;
    final report = assessWifi(wifi);
    setState(() {
      _wifi = wifi;
      _wifiReport = report;
      _wifiLoaded = true;
    });
    // Alerte seulement quand on passe d'un réseau sûr à un réseau dangereux.
    if (before != null &&
        before != WifiLevel.danger &&
        report.level == WifiLevel.danger) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.rommen,
          content: Text('${report.title} : évitez la banque et les achats.'),
          action: SnackBarAction(
            label: 'Détails',
            textColor: Colors.white,
            onPressed: _showWifiDetails,
          ),
        ),
      );
    }
  }

  /// Ouvre la feuille de détails du Wi-Fi.
  void _showWifiDetails() {
    final wifi = _wifi;
    final report = _wifiReport;
    if (wifi == null || report == null) return;
    showWifiDetails(
      context,
      status: wifi,
      report: report,
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
        _report = status == null
            ? null
            : calculateSecurityScore(status, DateTime.now());
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
  String _title() {
    final report = _report;
    if (_failed) return 'Analyse impossible';
    if (report == null) return 'Sécurité du téléphone';
    if (report.actions.isEmpty || report.score >= 70) {
      return 'Votre téléphone est bien protégé';
    }
    if (report.score >= 45) return 'Quelques points à renforcer';
    return 'Votre téléphone est exposé';
  }

  /// Ligne discrète sous l'arche, ex : « Android 15 · correctif du 5 août 2026 ».
  String _versionLine(DeviceSecurityStatus status) {
    final patch = status.securityPatch;
    final android = 'Android ${status.androidVersion}';
    if (patch == null) return android;
    return '$android · correctif du ${formatFrenchDate(patch)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // RefreshIndicator : tirer vers le bas relance l'analyse.
        child: RefreshIndicator(
          color: AppColors.bleu,
          onRefresh: _refreshAll,
          // AlwaysScrollable : on peut tirer même si l'écran ne déborde pas.
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, Iheb',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.encre.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _title(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.encre,
                  ),
                ),
                const SizedBox(height: 40),
                ..._content(),
                // Hors Android (Windows) : section masquée.
                if (WifiService.isSupported && _wifiLoaded && !_loading) ...[
                  const SizedBox(height: 32),
                  WifiSection(report: _wifiReport, onTap: _showWifiDetails),
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
  List<Widget> _content() {
    final status = _status;
    final report = _report;

    if (_loading) {
      return const [
        Center(child: ScoreArch.empty(message: 'Analyse en cours…')),
      ];
    }
    if (_failed) {
      return const [
        _InfoMessage("L'analyse a échoué. Tirez vers le bas pour réessayer."),
      ];
    }
    if (status == null || report == null) {
      return const [
        _InfoMessage("L'analyse du téléphone est disponible sur Android."),
      ];
    }

    final actions = report.actions;
    return [
      Center(child: ScoreArch(score: report.score)),
      const SizedBox(height: 12),
      Center(
        child: Text(
          _versionLine(status),
          style: TextStyle(
            fontSize: 13,
            color: AppColors.encre.withValues(alpha: 0.5),
          ),
        ),
      ),
      const SizedBox(height: 40),
      const Text(
        'Pour gagner des points',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.encre,
        ),
      ),
      const SizedBox(height: 8),
      if (actions.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Rien à corriger pour le moment.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.encre.withValues(alpha: 0.6),
            ),
          ),
        ),
      // Boucle for dans la liste : on crée une ligne par action,
      // avec un séparateur fin entre deux lignes (pas avant la première).
      for (var i = 0; i < actions.length; i++) ...[
        if (i > 0)
          const Divider(height: 1, thickness: 1, color: AppColors.ligne),
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
          style: TextStyle(
            fontSize: 16,
            color: AppColors.encre.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
