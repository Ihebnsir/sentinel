import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/app_analysis.dart';
import '../services/firewall_service.dart';
import '../services/protection_service.dart';
import '../services/wifi_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_analysis_section.dart';
import '../widgets/blocklist_sections.dart';
import '../widgets/dns_privacy_section.dart';
import 'app_analysis_screen.dart';
import 'app_report_screen.dart';

/// Écran du pare-feu DNS : interrupteur, compteurs, analyse d'une app,
/// listes de blocage, mises à jour, liste blanche et sources.
class FirewallScreen extends StatefulWidget {
  const FirewallScreen({super.key});

  @override
  State<FirewallScreen> createState() => _FirewallScreenState();
}

class _FirewallScreenState extends State<FirewallScreen> {
  final _service = FirewallService();
  final _wifiService = WifiService();
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;

  FirewallStatus? _status;
  FirewallConfig? _config;
  List<AppReport> _reports = const [];
  bool _busy = false; // démarrage ou arrêt en cours
  bool _updating = false; // téléchargement des listes en cours
  final _allowController = TextEditingController();
  String? _allowError;

  @override
  void initState() {
    super.initState();
    // Le pare-feu peut s'arrêter seul (bouton « Arrêter », autre VPN) :
    // on relit l'état au retour dans l'app et toutes les 2 secondes.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    _refresh();
    _loadConfig();
    _loadReports();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    _allowController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await _service.getConfig();
    if (!mounted) return;
    setState(() => _config = config);
  }

  // Appliqué tout de suite par Android, sans redémarrer le VPN.
  Future<void> _onCategoryChanged(
    BlocklistCategory category,
    bool enabled,
  ) async {
    final config = await _service.setCategoryEnabled(category.id, enabled);
    if (!mounted || config == null) return;
    setState(() => _config = config);
  }

  Future<void> _onAutoUpdateChanged(bool enabled) async {
    if (enabled && !await _askUpdateConsent()) return;
    await _service.setAutoUpdate(enabled);
    await _loadConfig();
  }

  Future<void> _onUpdateNow() async {
    // Sans l'option automatique, on redemande l'accord à chaque fois.
    if (_config?.autoUpdate != true && !await _askUpdateConsent()) return;
    setState(() => _updating = true);
    final ok = await _service.updateNow();
    if (!mounted) return;
    setState(() => _updating = false);
    await _loadConfig();
    if (!mounted) return;
    final l = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l.firewallUpdated : l.firewallUpdateFailed),
      ),
    );
  }

  Future<bool> _askUpdateConsent() async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.chaux,
      builder: (_) => const _UpdateConsentSheet(),
    );
    return accepted == true && mounted;
  }

  Future<void> _onAddAllowed() async {
    final domain = normalizeDomainInput(_allowController.text);
    if (domain == null) {
      setState(() => _allowError = context.l10n.firewallInvalidDomain);
      return;
    }
    final saved = await _service.addAllowed(domain);
    if (!mounted) return;
    if (saved == null) {
      setState(() => _allowError = context.l10n.firewallDomainRefused);
      return;
    }
    _allowController.clear();
    setState(() => _allowError = null);
    await _loadConfig();
  }

  Future<void> _onRemoveAllowed(String domain) async {
    await _service.removeAllowed(domain);
    await _loadConfig();
  }

  Future<void> _refresh() async {
    final status = await _service.getStatus();
    if (!mounted) return;
    // Fin d'analyse (durée écoulée, arrêt) : un nouveau rapport existe.
    final analysisEnded = _status?.analysis != null && status?.analysis == null;
    setState(() => _status = status);
    if (analysisEnded) await _loadReports();
  }

  // Rapports de moins de 24 h (Android supprime les plus anciens).
  Future<void> _loadReports() async {
    final reports = await _service.getReports();
    if (!mounted) return;
    setState(() => _reports = reports);
  }

  Future<void> _onChooseApp() async {
    final started = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AppAnalysisScreen()),
    );
    if (started == true) await _refresh();
  }

  Future<void> _onStopAnalysis() async {
    await _service.stopAnalysis();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _refresh();
    await _loadReports(); // au cas où l'état aurait déjà été relu
  }

  Future<void> _onOpenReport(AppReport report) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AppReportScreen(report: report)),
    );
    if (deleted == true) await _loadReports();
  }

  // SEN-11 : avec un DNS privé strict, le pare-feu couperait tous les
  // sites. On explique et on propose les réglages, sans activer.
  Future<void> _explainStrictPrivateDns(String server) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.dnsStrictTitle),
        content: Text(context.l10n.dnsStrictMessage(server)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonOpenSettings),
          ),
        ],
      ),
    );
    if (open == true) await _wifiService.openPrivateDnsSettings();
  }

  // SEN-10 : accord explicite pour le DNS en clair, sur ce réseau seulement.
  Future<void> _onPlainDnsChanged(bool allowed) async {
    await _service.setPlainDnsAllowed(allowed);
    await _refresh();
  }

  Future<void> _onSwitch(bool value) async {
    if (_busy) return;
    final strict = _status?.strictPrivateDns;
    if (value && strict != null) {
      await _explainStrictPrivateDns(strict);
      return;
    }
    if (value) {
      final accepted = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.chaux,
        builder: (_) => const _ExplanationSheet(),
      );
      if (accepted != true || !mounted) return;
      setState(() => _busy = true);
      // Écran « Demande de connexion » d'Android (la première fois).
      if (await _service.prepare()) {
        // Android 13+ : sans cette autorisation, la notification
        // (et son bouton « Arrêter ») reste invisible.
        await ProtectionService().requestNotificationPermission();
        await _service.start();
      }
    } else {
      setState(() => _busy = true);
      await _service.stop();
    }
    // Le service démarre ou s'arrête en quelques instants.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = _status;
    final config = _config;
    final muted = AppColors.encre.withValues(alpha: 0.6);
    final active = status?.active ?? false;

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
              l.firewallTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.firewallIntro,
              style: const TextStyle(fontSize: 15, color: AppColors.encre),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, thickness: 1, color: AppColors.ligne),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.firewallTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.encre,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status == null
                              ? l.commonAndroidOnly
                              : (active ? l.commonOn : l.commonOff),
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: active,
                    onChanged: status == null || _busy ? null : _onSwitch,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.ligne),
            if (status?.strictPrivateDns case final server?) ...[
              StrictPrivateDnsWarning(
                server: server,
                onOpenSettings: _wifiService.openPrivateDnsSettings,
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.ligne),
            ],
            if (active && status != null) ...[
              UpstreamSection(
                mode: status.upstream,
                plainAllowed: status.plainDnsAllowed,
                onPlainChanged: _busy ? null : _onPlainDnsChanged,
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.ligne),
              const SizedBox(height: 24),
              Text(
                l.firewallSinceActivation,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.encre,
                ),
              ),
              const SizedBox(height: 4),
              _CountRow(
                label: l.firewallQueriesAnalyzed,
                value: status.totalQueries,
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.ligne),
              _CountRow(
                label: l.firewallQueriesBlocked,
                value: status.blockedQueries,
              ),
              // Détail par catégorie (une requête compte pour une seule).
              for (final category
                  in config?.categories ?? const <BlocklistCategory>[])
                if (category.enabled ||
                    (status.blockedByCategory[category.id] ?? 0) > 0) ...[
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.ligne,
                  ),
                  _CountRow(
                    label: category.displayName(l),
                    value: status.blockedByCategory[category.id] ?? 0,
                  ),
                ],
              if (status.listsLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l.firewallListsLoading,
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ),
            ],
            if (status != null)
              AppAnalysisSection(
                firewallActive: active,
                analysis: status.analysis,
                reports: _reports,
                onChoose: _onChooseApp,
                onStop: _onStopAnalysis,
                onOpenReport: _onOpenReport,
              ),
            if (config != null) ...[
              BlocklistCategoriesSection(
                categories: config.categories,
                onChanged: _onCategoryChanged,
              ),
              AutoUpdateSection(
                config: config,
                busy: _updating || config.updating,
                onAutoUpdateChanged: _onAutoUpdateChanged,
                onUpdateNow: _onUpdateNow,
              ),
              AllowlistSection(
                domains: config.allowlist,
                controller: _allowController,
                error: _allowError,
                onAdd: _onAddAllowed,
                onRemove: _onRemoveAllowed,
              ),
            ],
            const SizedBox(height: 24),
            Text(
              l.firewallOneVpn,
              style: TextStyle(fontSize: 13, color: muted),
            ),
            if (config != null && config.sources.isNotEmpty)
              BlocklistSourcesSection(sources: config.sources),
          ],
        ),
      ),
    );
  }
}

/// Ligne « libellé … nombre ».
class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.encre.withValues(alpha: 0.6),
              ),
            ),
          ),
          Text(
            context.l10n.number(value),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.encre,
            ),
          ),
        ],
      ),
    );
  }
}

/// Explication avant l'écran de consentement VPN d'Android.
/// Retourne true (Continuer) ou false / null (Plus tard).
class _ExplanationSheet extends StatelessWidget {
  const _ExplanationSheet();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lines = [
      l.firewallExplain1,
      l.firewallExplain2,
      l.firewallExplain3,
      l.firewallExplain4,
      l.firewallExplain5,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.firewallTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            const SizedBox(height: 12),
            for (final line in lines) ...[
              const Divider(height: 1, thickness: 1, color: AppColors.ligne),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  line,
                  style: const TextStyle(fontSize: 15, color: AppColors.encre),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.encre.withValues(alpha: 0.6),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l.commonLater),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bleu,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l.commonContinue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Accord avant de télécharger les listes. Retourne true (Accepter).
class _UpdateConsentSheet extends StatelessWidget {
  const _UpdateConsentSheet();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lines = [l.firewallConsent1, l.firewallConsent2, l.firewallConsent3];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.firewallUpdateTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            const SizedBox(height: 12),
            for (final line in lines) ...[
              const Divider(height: 1, thickness: 1, color: AppColors.ligne),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  line,
                  style: const TextStyle(fontSize: 15, color: AppColors.encre),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.encre.withValues(alpha: 0.6),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l.commonLater),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bleu,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l.commonAccept),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
