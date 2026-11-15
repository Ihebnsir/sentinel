import 'package:flutter/services.dart' show PlatformException;
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/app_risk_calculator.dart';
import '../services/apps/stalkerware_ioc.dart';
import '../services/apps_scanner_service.dart';
import '../services/sensitive_access.dart';
import '../services/sensitive_access_service.dart';
import '../theme/app_colors.dart';
import '../utils/debug_log.dart';
import '../widgets/app_icon.dart';
import '../widgets/loading_bar.dart';
import 'app_detail_screen.dart';

/// Ce que l'écran affiche.
enum _Step { checking, intro, loading, loaded, failed, unavailable }

/// « Accès sensibles » : apps qui ont pu utiliser caméra, micro ou
/// localisation, et quand (onglet Applications).
class SensitiveAccessScreen extends StatefulWidget {
  const SensitiveAccessScreen({super.key, this.service, this.clock});

  final SensitiveAccessService? service; // remplaçable dans les tests
  final DateTime Function()? clock; // idem

  @override
  State<SensitiveAccessScreen> createState() => _SensitiveAccessScreenState();
}

class _SensitiveAccessScreenState extends State<SensitiveAccessScreen>
    with WidgetsBindingObserver {
  late final _service = widget.service ?? SensitiveAccessService();
  _Step _step = _Step.checking;
  bool _askedOnce = false; // réglages déjà ouverts une fois
  bool _showSystemApps = false;
  List<AppAccessSummary> _summaries = const [];

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Retour depuis les réglages : l'autorisation a peut-être changé.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _step != _Step.loading) _check();
  }

  /// Rien n'est demandé ici : sans autorisation, on explique d'abord.
  Future<void> _check() async {
    if (!SensitiveAccessService.isAvailable && widget.service == null) {
      setState(() => _step = _Step.unavailable);
      return;
    }
    final granted = await _service.hasUsageAccess();
    if (!mounted) return;
    if (granted) {
      if (_step != _Step.loaded) setState(() => _step = _Step.loading);
      await _load();
    } else {
      setState(() => _step = _Step.intro);
    }
  }

  Future<void> _load() async {
    try {
      final apps = await _service.read();
      if (!mounted) return;
      setState(() {
        _summaries = summarizeAccess(apps, _now());
        _step = _Step.loaded;
      });
    } on PlatformException catch (e) {
      debugLog(() => 'Accès sensibles illisibles : ${e.message}');
      if (mounted) setState(() => _step = _Step.failed);
    }
  }

  void _openSettings() {
    setState(() => _askedOnce = true);
    _service.openUsageAccessSettings();
  }

  void _openDetail(AppAccessSummary summary) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SensitiveAccessDetailScreen(summary: summary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
        child: RefreshIndicator(
          color: context.colors.bleu,
          onRefresh: _check,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
            children: [
              Text(
                l.accessEntryTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: context.colors.encre,
                ),
              ),
              const SizedBox(height: 16),
              ..._body(l),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(AppLocalizations l) {
    switch (_step) {
      case _Step.checking:
        return const [];
      case _Step.unavailable:
        return [_Paragraph(l.accessAndroidOnly)];
      case _Step.intro:
        return _intro(l);
      case _Step.loading:
        return [
          const LoadingBar(),
          const SizedBox(height: 16),
          _Paragraph(l.accessLoading),
        ];
      case _Step.failed:
        return [_Paragraph(l.commonAnalysisFailedPull)];
      case _Step.loaded:
        return _results(l);
    }
  }

  /// Explication avant toute demande d'autorisation.
  List<Widget> _intro(AppLocalizations l) {
    return [
      Text(
        l.accessIntroTitle,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.colors.encre,
        ),
      ),
      const SizedBox(height: 12),
      _Paragraph(l.accessIntroWhat),
      _Paragraph(l.accessIntroPermission),
      _Paragraph(l.accessIntroPrivacy),
      _Paragraph(l.accessLimit, muted: true),
      if (_askedOnce)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            l.accessNotYetGranted,
            style: TextStyle(fontSize: 14, color: context.colors.ocre),
          ),
        ),
      const SizedBox(height: 16),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: context.colors.bleu),
        onPressed: _openSettings,
        child: Text(l.accessOpenSettings),
      ),
    ];
  }

  List<Widget> _results(AppLocalizations l) {
    final visible = _summaries
        .where((s) => _showSystemApps || !s.app.isSystemApp)
        .toList();
    final unusual = visible.where((s) => s.unusual).toList();
    final others = visible.where((s) => !s.unusual).toList();
    return [
      _Paragraph(l.accessLimit, muted: true),
      MergeSemantics(
        child: Row(
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
      ),
      if (visible.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: _Paragraph(l.accessNothing),
        ),
      if (unusual.isNotEmpty) ..._section(l.accessToReview, unusual),
      if (others.isNotEmpty)
        ..._section(unusual.isEmpty ? null : l.accessOtherApps, others),
      const SizedBox(height: 24),
      _Paragraph(l.accessRetention, muted: true),
      Divider(height: 1, thickness: 1, color: context.colors.ligne),
      _LinkRow(
        title: l.accessPrivacyDashboard,
        subtitle: l.accessPrivacyDashboardHint,
        onTap: _service.openPrivacyDashboard,
      ),
      Divider(height: 1, thickness: 1, color: context.colors.ligne),
      _LinkRow(title: l.accessRevoke, onTap: _service.openUsageAccessSettings),
    ];
  }

  List<Widget> _section(String? title, List<AppAccessSummary> items) {
    return [
      if (title != null)
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.colors.encre,
            ),
          ),
        ),
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0)
          Divider(height: 1, thickness: 1, color: context.colors.ligne),
        _AccessTile(summary: items[i], onTap: () => _openDetail(items[i])),
      ],
    ];
  }
}

/// Noms des accès autorisés : « Caméra · Micro ».
String sensorNames(AppLocalizations l, Set<SensitiveSensor> sensors) => [
  for (final s in SensitiveSensor.values)
    if (sensors.contains(s))
      switch (s) {
        SensitiveSensor.camera => l.accessCamera,
        SensitiveSensor.microphone => l.accessMicrophone,
        SensitiveSensor.location => l.accessLocation,
      },
].join(' · ');

String _lastActivity(AppLocalizations l, AppAccessSummary s) {
  final last = s.lastUse;
  return last == null
      ? l.accessNoRecentActivity
      : l.accessLastActivity(l.dateTime(last));
}

/// Une ligne : icône, nom, accès, dernière activité, comptes, repères.
class _AccessTile extends StatelessWidget {
  const _AccessTile({required this.summary, required this.onTap});

  final AppAccessSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final small = TextStyle(fontSize: 13, color: c.secondaire);
    final flags = [
      if (summary.nightCount > 0) l.accessNight,
      if (summary.backgroundCount > 0) l.accessBackground,
      if (summary.app.backgroundLocation) l.accessLocationAlways,
    ];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon.bytes(summary.app.icon, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: c.encre,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sensorNames(l, summary.app.sensors),
                    style: TextStyle(fontSize: 13, color: c.encre),
                  ),
                  Text(_lastActivity(l, summary), style: small),
                  if (summary.count7d > 0)
                    Text(
                      l.accessCounts(
                        l.accessTimes(
                          summary.count24h,
                          l.number(summary.count24h),
                        ),
                        l.accessTimes(
                          summary.count7d,
                          l.number(summary.count7d),
                        ),
                      ),
                      style: small,
                    ),
                  if (flags.isNotEmpty)
                    Text(
                      flags.join(' · '),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: summary.unusual ? c.ocre : c.secondaire,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Détail d'une app : accès, comptes, moments, et liens.
class SensitiveAccessDetailScreen extends StatelessWidget {
  const SensitiveAccessDetailScreen({super.key, required this.summary});

  final AppAccessSummary summary;

  /// Ouvre l'analyse existante de l'app (scanner d'apps).
  Future<void> _openAnalysis(BuildContext context) async {
    final l = context.l10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final app = await AppsScannerService().scanApp(summary.app.packageName);
      if (app == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.analysisErrorUnknownApp)),
        );
        return;
      }
      StalkerwareIoc? ioc;
      try {
        ioc = await StalkerwareIoc.load();
      } on Exception catch (e) {
        debugLog(() => 'Indicateurs de stalkerware illisibles : $e');
      }
      final report = calculateAppRisk(app, ioc: ioc);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => AppDetailScreen(app: app, report: report),
        ),
      );
    } on PlatformException {
      messenger.showSnackBar(
        SnackBar(content: Text(l.commonAnalysisFailedPull)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final app = summary.app;
    Widget line() => Divider(height: 1, thickness: 1, color: c.ligne);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.chaux,
        foregroundColor: c.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppIcon.bytes(app.icon, size: 64),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    app.label,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: c.encre,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.packageName,
                    style: TextStyle(fontSize: 13, color: c.secondaire),
                  ),
                  const SizedBox(height: 24),
                  _InfoRow(l.accessDetailAllowed, sensorNames(l, app.sensors)),
                  line(),
                  _InfoRow(
                    l.accessDetailLast24h,
                    l.accessTimes(summary.count24h, l.number(summary.count24h)),
                  ),
                  line(),
                  _InfoRow(
                    l.accessDetailLast7d,
                    l.accessTimes(summary.count7d, l.number(summary.count7d)),
                  ),
                  if (summary.reasons.isNotEmpty || app.backgroundLocation) ...[
                    const SizedBox(height: 16),
                    if (summary.reasons.contains(UnusualReason.night))
                      _Paragraph(l.accessReasonNight, color: c.ocre),
                    if (summary.reasons.contains(
                      UnusualReason.backgroundCameraMic,
                    ))
                      _Paragraph(l.accessReasonBackground, color: c.ocre),
                    if (app.backgroundLocation)
                      _Paragraph(l.accessLocationAlways),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 4),
                    child: Text(
                      l.accessDetailMoments,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: c.encre,
                      ),
                    ),
                  ),
                  if (summary.sessions.isEmpty)
                    _Paragraph(l.accessNoRecentActivity),
                  for (var i = 0; i < summary.sessions.length; i++) ...[
                    if (i > 0) line(),
                    _MomentRow(summary.sessions[i]),
                  ],
                  const SizedBox(height: 16),
                  _Paragraph(l.accessLimit, muted: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: c.bleu),
                    onPressed: () =>
                        AppsScannerService().openAppSettings(app.packageName),
                    child: Text(l.detailManagePermissions),
                  ),
                  TextButton(
                    onPressed: () => _openAnalysis(context),
                    child: Text(l.accessSeeAnalysis),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un moment : date, heures, ouverte ou en arrière-plan, nuit.
class _MomentRow extends StatelessWidget {
  const _MomentRow(this.session);

  final UsageSession session;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final kind = session.kind == SessionKind.background
        ? l.accessMomentBackground
        : l.accessMomentForeground;
    final highlight = session.atNight || session.kind == SessionKind.background;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l.date(session.start)} · '
            '${l.accessMomentRange(l.time(session.start), l.time(session.end))}',
            style: TextStyle(fontSize: 15, color: c.encre),
          ),
          const SizedBox(height: 2),
          Text(
            session.atNight ? '$kind · ${l.accessNight}' : kind,
            style: TextStyle(
              fontSize: 13,
              color: highlight ? c.ocre : c.secondaire,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: context.colors.secondaire),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 15, color: context.colors.encre),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.title, this.subtitle, required this.onTap});

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 15, color: context.colors.bleu),
            ),
            if (sub != null)
              Text(
                sub,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.secondaire,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text, {this.muted = false, this.color});

  final String text;
  final bool muted;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: muted ? 13 : 15,
          color: color ?? (muted ? c.secondaire : c.encre),
        ),
      ),
    );
  }
}
