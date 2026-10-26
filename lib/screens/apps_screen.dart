import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../models/installed_app.dart';
import '../services/app_risk_calculator.dart';
import '../services/apps/stalkerware_ioc.dart';
import '../services/apps_scanner_service.dart';
import '../theme/app_colors.dart';
import '../utils/debug_log.dart';
import '../widgets/app_icon.dart';
import '../widgets/empty_state.dart';
import '../widgets/risk_level_text.dart';
import 'app_detail_screen.dart';
import 'spyware_advice_screen.dart';

/// Onglet « Applications » : analyse des applications installées.
/// StatefulWidget car il garde le résultat de l'analyse en mémoire.
class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

/// Une app et son rapport de risque, calculé une seule fois après le scan.
class _ScannedApp {
  const _ScannedApp(this.app, this.report);

  final InstalledApp app;
  final AppRiskReport report;
}

// WidgetsBindingObserver : permet d'être prévenu quand l'app revient au premier plan.
class _AppsScreenState extends State<AppsScreen> with WidgetsBindingObserver {
  final _service = AppsScannerService();

  bool _started = false; // l'utilisateur a lancé au moins une analyse
  bool _loading = false; // vrai seulement pendant la toute première analyse
  bool _failed = false; // Android a renvoyé une erreur
  bool _scanRunning = false; // évite de lancer deux analyses en même temps
  bool _showSystemApps = false;
  List<_ScannedApp>? _apps; // null : analyse indisponible (Windows)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Retour dans l'app (ex : après une désinstallation) : on relance,
  // seulement si une analyse a déjà réussi.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _apps != null) _scan();
  }

  void _startFirstScan() {
    setState(() {
      _started = true;
      _loading = true;
    });
    _scan();
  }

  /// Demande la liste à Android, calcule les risques et trie.
  Future<void> _scan() async {
    if (_scanRunning) return;
    _scanRunning = true;
    try {
      final apps = await _service.scanApps();
      final ioc = apps == null ? null : await _loadIoc();
      // L'écran a pu être fermé pendant l'attente.
      if (!mounted) return;
      setState(() {
        _apps = apps == null ? null : _sortedByRisk(apps, ioc);
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
      _scanRunning = false;
    }
  }

  /// Indicateurs de stalkerware ; null si le fichier est illisible
  /// (l'analyse continue avec les autres règles).
  static Future<StalkerwareIoc?> _loadIoc() async {
    try {
      return await StalkerwareIoc.load();
    } on Exception catch (e) {
      debugLog(() => 'Indicateurs de stalkerware illisibles : $e');
      return null;
    }
  }

  /// Apps évaluées d'abord, par score décroissant (à score égal, ordre
  /// alphabétique) ; puis les apps « Système », par ordre alphabétique.
  static List<_ScannedApp> _sortedByRisk(
    List<InstalledApp> apps,
    StalkerwareIoc? ioc,
  ) {
    final scanned = [
      for (final app in apps) _ScannedApp(app, calculateAppRisk(app, ioc: ioc)),
    ];
    scanned.sort((a, b) {
      final aSystem = a.report.level == RiskLevel.systeme;
      final bSystem = b.report.level == RiskLevel.systeme;
      if (aSystem != bSystem) return aSystem ? 1 : -1;
      final byScore = b.report.score.compareTo(a.report.score);
      if (byScore != 0) return byScore;
      return a.app.label.toLowerCase().compareTo(b.app.label.toLowerCase());
    });
    return scanned;
  }

  void _openDetail(_ScannedApp scanned) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppDetailScreen(
          app: scanned.app,
          report: scanned.report,
        ),
      ),
    );
  }

  // Pas de notification pour ce résultat : seulement ce bloc, visible
  // quand l'utilisateur ouvre lui-même l'onglet.
  void _openAdvice(_ScannedApp scanned) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SpywareAdviceScreen(app: scanned.app, report: scanned.report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return _page([Expanded(child: _emptyState())]);
    if (_loading) return _page(const [_ScanProgress()]);

    return SafeArea(
      // RefreshIndicator : tirer vers le bas relance l'analyse.
      child: RefreshIndicator(
        color: context.colors.bleu,
        onRefresh: _scan,
        // AlwaysScrollable : on peut tirer même si la liste est courte.
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          children: [
            const _PageTitle(),
            ..._results(),
          ],
        ),
      ),
    );
  }

  /// Page simple, sans défilement : titre puis contenu.
  Widget _page(List<Widget> children) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [const _PageTitle(), ...children],
        ),
      ),
    );
  }

  Widget _emptyState() {
    final l = context.l10n;
    return EmptyState(
      icon: Icons.apps_outlined,
      title: l.appsEmptyTitle,
      message: l.appsEmptyMessage,
      buttonLabel: l.appsStartScan,
      onPressed: _startFirstScan,
    );
  }

  /// Le contenu sous le titre, selon le résultat de l'analyse.
  List<Widget> _results() {
    final l = context.l10n;
    final apps = _apps;
    if (_failed) {
      return [_InfoMessage(l.commonAnalysisFailedPull)];
    }
    if (apps == null) {
      return [_InfoMessage(l.appsAndroidOnly)];
    }

    final visible = _showSystemApps
        ? apps
        : apps.where((s) => !s.app.isSystemApp).toList();
    // Toujours affichés, même cachés parmi les apps système.
    final spyware = apps.where((s) => s.report.spywareSuspected).toList();

    return [
      if (spyware.isNotEmpty) _SpywareBlock(apps: spyware, onTap: _openAdvice),
      const SizedBox(height: 8),
      Text(
        appsScanSummary(l, [for (final s in visible) s.report]),
        style: TextStyle(fontSize: 15, color: context.colors.secondaire),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              l.appsShowSystem,
              style: TextStyle(fontSize: 15, color: context.colors.encre),
            ),
          ),
          Switch(
            value: _showSystemApps,
            onChanged: (value) => setState(() => _showSystemApps = value),
          ),
        ],
      ),
      const SizedBox(height: 8),
      // Une ligne par app, avec un séparateur fin entre deux lignes.
      for (var i = 0; i < visible.length; i++) ...[
        if (i > 0)
          Divider(height: 1, thickness: 1, color: context.colors.ligne),
        _AppTile(
          scanned: visible[i],
          onTap: () => _openDetail(visible[i]),
        ),
      ],
    ];
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.navApps,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: context.colors.encre,
      ),
    );
  }
}

/// Bloc sobre en haut de la liste : logiciel espion possible.
/// Chaque ligne mène aux conseils, jamais directement à la désinstallation.
class _SpywareBlock extends StatelessWidget {
  const _SpywareBlock({required this.apps, required this.onTap});

  final List<_ScannedApp> apps;
  final void Function(_ScannedApp) onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, thickness: 1, color: context.colors.rommen),
          const SizedBox(height: 14),
          Text(
            l.appsSpywareFound,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.colors.rommen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.appsSpywareReadAdvice,
            style: TextStyle(
              fontSize: 14,
              color: context.colors.encre.withValues(alpha: 0.7),
            ),
          ),
          for (final scanned in apps)
            InkWell(
              onTap: () => onTap(scanned),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    AppIcon(app: scanned.app, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        scanned.app.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.colors.encre,
                        ),
                      ),
                    ),
                    Text(
                      l.appsSeeAdvice,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.rommen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          Divider(height: 1, thickness: 1, color: context.colors.rommen),
        ],
      ),
    );
  }
}

/// Chargement sobre : une fine barre bleue et une phrase.
class _ScanProgress extends StatelessWidget {
  const _ScanProgress();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            minHeight: 2,
            color: context.colors.bleu,
            backgroundColor: context.colors.ligne,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.appsScanning,
            style: TextStyle(fontSize: 15, color: context.colors.secondaire),
          ),
        ],
      ),
    );
  }
}

/// Une ligne : icône, nom + raison principale, niveau à droite.
class _AppTile extends StatelessWidget {
  const _AppTile({required this.scanned, required this.onTap});

  final _ScannedApp scanned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final report = scanned.report;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            AppIcon(app: scanned.app, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scanned.app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.colors.encre,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    report.level == RiskLevel.systeme
                        ? l.appsSystemApp
                        : report.mainReason(l) ?? l.appsNoWorry,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.secondaire,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            RiskLevelText(level: report.level),
          ],
        ),
      ),
    );
  }
}

/// Message centré affiché à la place de la liste.
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
