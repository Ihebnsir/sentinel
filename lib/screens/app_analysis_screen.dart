import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../models/installed_app.dart';
import '../services/app_analysis.dart';
import '../services/apps_scanner_service.dart';
import '../services/firewall_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon.dart';

// Couleur : celle du thème (dividerTheme, ligne fine).
const _divider = Divider(height: 1, thickness: 1);

const _ownPackage = 'com.iheb.sentinel';

/// Choix de l'application à analyser, puis de la durée.
/// Renvoie true (Navigator.pop) si une analyse a été lancée.
class AppAnalysisScreen extends StatefulWidget {
  const AppAnalysisScreen({super.key});

  @override
  State<AppAnalysisScreen> createState() => _AppAnalysisScreenState();
}

class _AppAnalysisScreenState extends State<AppAnalysisScreen> {
  final _firewall = FirewallService();
  List<InstalledApp>? _apps; // null : chargement en cours
  bool _failed = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final apps = await AppsScannerService().scanApps();
      if (!mounted) return;
      setState(() {
        // Seulement les apps qu'on peut ouvrir (icône dans le lanceur),
        // sauf Sentinel : ses requêtes ne passent jamais par son VPN.
        _apps =
            [
              for (final app in apps ?? const <InstalledApp>[])
                if (app.hasLauncherIcon && app.packageName != _ownPackage) app,
            ]..sort(
              (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
            );
      });
    } on Exception {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _choose(InstalledApp app) async {
    if (_starting) return;
    final minutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.chaux,
      builder: (_) => _AnalysisSheet(app: app),
    );
    if (minutes == null || !mounted) return;
    setState(() => _starting = true);
    final error = await _firewall.startAnalysis(app.packageName, minutes);
    if (!mounted) return;
    if (error != null) {
      setState(() => _starting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message(context.l10n))));
      return;
    }
    // Le VPN se reconstruit en un instant, puis on ouvre l'app à observer.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _firewall.openApp(app.packageName);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final apps = _apps;
    final muted = TextStyle(fontSize: 15, color: context.colors.secondaire);
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
              l.analysisSectionTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.analysisScreenIntro,
              style: TextStyle(fontSize: 15, color: context.colors.encre),
            ),
            const SizedBox(height: 24),
            _divider,
            if (_failed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l.analysisListFailed, style: muted),
              )
            else if (apps == null || _starting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (apps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l.analysisNoApps, style: muted),
              )
            else
              for (final app in apps) ...[
                InkWell(
                  onTap: () => _choose(app),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        AppIcon(app: app, size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            app.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: context.colors.encre,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _divider,
              ],
          ],
        ),
      ),
    );
  }
}

/// Durée et explication AVANT de lancer. Renvoie les minutes, ou null.
class _AnalysisSheet extends StatefulWidget {
  const _AnalysisSheet({required this.app});

  final InstalledApp app;

  @override
  State<_AnalysisSheet> createState() => _AnalysisSheetState();
}

class _AnalysisSheetState extends State<_AnalysisSheet> {
  int _minutes = 5;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = widget.app.label;
    final duration = l.durationMinutesLong(_minutes, l.number(_minutes));
    final lines = [
      l.analysisSheetLine1(duration, name),
      l.analysisSheetLine2,
      l.analysisSheetLine3,
      l.analysisSheetLine4,
      l.analysisSheetLine5(name),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                AppIcon(app: widget.app, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.analysisSheetTitle(name),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: context.colors.encre,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final m in analysisMinutes)
                    ButtonSegment(
                      value: m,
                      label: Text(l.durationMinutes(m, l.number(m))),
                    ),
                ],
                selected: {_minutes},
                onSelectionChanged: (value) =>
                    setState(() => _minutes = value.first),
              ),
            ),
            const SizedBox(height: 12),
            for (final (index, line) in lines.indexed) ...[
              _divider,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  line,
                  style: TextStyle(
                    fontSize: 15,
                    // La fenêtre sans protection est mise en avant.
                    color: index == 1
                        ? context.colors.ocre
                        : context.colors.encre,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.secondaire,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.commonCancel),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.bleu,
                  ),
                  onPressed: () => Navigator.of(context).pop(_minutes),
                  child: Text(l.appsStartScan),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
