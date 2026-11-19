import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../l10n/l10n.dart';
import '../models/installed_app.dart';
import '../services/app_analysis.dart';
import '../services/apps_scanner_service.dart';
import '../services/firewall_service.dart';
import '../theme/app_colors.dart';
import '../widgets/actions_row.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';

// Couleur : celle du thème (dividerTheme, ligne fine).
const _divider = Divider(height: 1, thickness: 1);

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
                if (app.hasLauncherIcon && app.packageName != ownPackageName) app,
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
    final muted = TextStyle(fontSize: AppText.corps, color: context.colors.secondaire);
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
          padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xl),
          children: [
            Text(
              l.analysisSectionTitle,
              style: TextStyle(
                fontSize: AppText.titreSecondaire,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              l.analysisScreenIntro,
              style: TextStyle(fontSize: AppText.corps, color: context.colors.encre),
            ),
            const SizedBox(height: AppSpace.xl),
            _divider,
            if (_failed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                child: Text(l.analysisListFailed, style: muted),
              )
            else if (apps == null || _starting)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xxxl),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: l.commonLoading,
                  ),
                ),
              )
            else if (apps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                child: Text(l.analysisNoApps, style: muted),
              )
            else
              for (final app in apps) ...[
                InkWell(
                  onTap: () => _choose(app),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
                    child: Row(
                      children: [
                        AppIcon(app: app, size: AppSize.appIcon),
                        const SizedBox(width: AppSpace.lg),
                        Expanded(
                          child: Text(
                            app.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppText.intitule,
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
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                AppIcon(app: widget.app, size: AppSize.appIconSmall),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    l.analysisSheetTitle(name),
                    style: TextStyle(
                      fontSize: AppText.titreSecondaire,
                      fontWeight: FontWeight.w600,
                      color: context.colors.encre,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
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
            const SizedBox(height: AppSpace.md),
            for (final (index, line) in lines.indexed) ...[
              _divider,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                child: Text(
                  line,
                  style: TextStyle(
                    fontSize: AppText.corps,
                    // La fenêtre sans protection est mise en avant.
                    color: index == 1
                        ? context.colors.ocre
                        : context.colors.encre,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.xl),
            ActionsRow(
              children: [
                TextButton(
                  style: mutedButtonStyle(context),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.commonCancel),
                ),
                FilledButton(
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
