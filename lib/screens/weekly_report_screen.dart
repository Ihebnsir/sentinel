import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../services/app_analysis.dart';
import '../services/weekly_report_service.dart';
import '../theme/app_colors.dart';
import '../widgets/score_arch.dart';
import '../widgets/ui.dart';

/// « Bilan de la semaine » : semaine en cours et précédente, en chiffres.
/// [service] : remplaçable dans les tests.
class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({
    super.key,
    this.service = const WeeklyReportService(),
  });

  final WeeklyReportService service;

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  bool _loading = true;
  WeeklyReport? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final report = await widget.service.load();
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.chaux,
        foregroundColor: context.colors.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(top: false, child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final l = context.l10n;
    final report = _report;
    final title = Text(
      l.weeklyTitle,
      style: TextStyle(
        fontSize: AppText.titreSecondaire,
        fontWeight: FontWeight.w600,
        color: context.colors.encre,
      ),
    );
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xl),
        child: title,
      );
    }
    if (report == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xl),
        children: [
          title,
          const SizedBox(height: AppSpace.xxxl),
          Text(
            l.weeklyAndroidOnly,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: AppText.intitule, color: context.colors.secondaire),
          ),
        ],
      );
    }

    final week = report.current;
    final previous = report.previous;
    final scoreEnd = week.scoreEnd;
    final scoreStart = week.scoreStart;
    final previousScore = previous?.scoreEnd;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xl),
      children: [
        title,
        const SizedBox(height: AppSpace.xs),
        Text(
          l.weeklyPeriod(l.date(week.start), l.date(week.end)),
          style: TextStyle(fontSize: AppText.detail, color: context.colors.discret),
        ),
        const SizedBox(height: AppSpace.xxl),
        Center(
          child: scoreEnd == null
              ? ScoreArch.empty(message: l.weeklyNoScore)
              : ScoreArch(score: scoreEnd),
        ),
        const SizedBox(height: AppSpace.md),
        if (scoreStart != null && scoreEnd != null)
          _centered(
            context,
            l.weeklyScoreChange(l.number(scoreStart), l.number(scoreEnd)),
          ),
        if (previousScore != null)
          _centered(context, l.weeklyLastWeekScore(l.number(previousScore))),
        const SizedBox(height: AppSpace.xxl),
        _ColumnsHeader(),
        _Section(
          title: l.weeklyFirewall,
          rows: [
            for (final id in weeklyFirewallCategories)
              _Line(
                _categoryLabel(l, id),
                week.blockedIn(id),
                previous?.blockedIn(id),
              ),
            _Line(
              l.weeklyBlockedTotal,
              week.blockedTotal,
              previous?.blockedTotal,
            ),
          ],
        ),
        _Section(
          title: l.weeklyLinks,
          rows: [
            _Line(
              l.weeklyLinksChecked,
              week.linksChecked,
              previous?.linksChecked,
            ),
          ],
        ),
        _Section(
          title: l.weeklyApps,
          rows: [
            _gaugeLine(
              l.weeklyRiskyApps,
              WeeklyGauge.riskyApps,
              week,
              previous,
            ),
          ],
        ),
        _Section(
          title: l.weeklyPasswords,
          rows: [
            _gaugeLine(
              l.weeklyPasswordsWeak,
              WeeklyGauge.passwordsWeak,
              week,
              previous,
            ),
            _gaugeLine(
              l.weeklyPasswordsReused,
              WeeklyGauge.passwordsReused,
              week,
              previous,
            ),
            _gaugeLine(
              l.weeklyPasswordsBreached,
              WeeklyGauge.passwordsBreached,
              week,
              previous,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xl),
        Text(
          l.weeklyPrivacyNote,
          style: TextStyle(fontSize: AppText.detail, color: context.colors.discret),
        ),
      ],
    );
  }

  Widget _centered(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.xs),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: AppText.detail, color: context.colors.secondaire),
    ),
  );

  static _Line _gaugeLine(
    String label,
    WeeklyGauge gauge,
    WeekSummary week,
    WeekSummary? previous,
  ) => _Line(label, week.gauges[gauge], previous?.gauges[gauge]);

  static String _categoryLabel(AppLocalizations l, String id) => switch (id) {
    'malware' => ReportCategory.malware.label(l),
    'impersonation' => ReportCategory.impersonation.label(l),
    'trackers' => ReportCategory.trackers.label(l),
    _ => ReportCategory.ads.label(l),
  };
}

/// Une ligne du bilan : libellé, cette semaine, semaine d'avant.
/// null : pas mesuré (affiché « – »).
class _Line {
  const _Line(this.label, this.current, this.previous);

  final String label;
  final int? current;
  final int? previous;
}

const _valueWidth = 84.0;

/// En-têtes des deux colonnes de chiffres.
class _ColumnsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = TextStyle(fontSize: AppText.legende, color: context.colors.discret);
    return ExcludeSemantics(
      child: Row(
        children: [
          const Spacer(),
          SizedBox(
            width: _valueWidth,
            child: Text(
              l.weeklyThisWeek,
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
          SizedBox(
            width: _valueWidth,
            child: Text(
              l.weeklyLastWeek,
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// Titre de section, puis ses lignes séparées par un trait fin.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_Line> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.xs),
          child: Text(
            title,
            style: TextStyle(
              fontSize: AppText.intitule,
              fontWeight: FontWeight.w600,
              color: context.colors.encre,
            ),
          ),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            const AppDivider(),
          _LineRow(rows[i]),
        ],
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow(this.line);

  final _Line line;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String show(int? value) => value == null ? '–' : l.number(value);
    String say(int? value) =>
        value == null ? l.weeklyNotMeasured : l.number(value);
    // TalkBack : une seule phrase par ligne, avec les deux semaines.
    return Semantics(
      label:
          '${line.label}. ${l.weeklyThisWeek} : ${say(line.current)}. '
          '${l.weeklyLastWeek} : ${say(line.previous)}.',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.tap),
        child: Row(
          children: [
            Expanded(
              child: Text(
                line.label,
                style: TextStyle(fontSize: AppText.corps, color: context.colors.encre),
              ),
            ),
            SizedBox(
              width: _valueWidth,
              child: Text(
                show(line.current),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: AppText.corps,
                  fontWeight: FontWeight.w600,
                  color: context.colors.encre,
                ),
              ),
            ),
            SizedBox(
              width: _valueWidth,
              child: Text(
                show(line.previous),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: AppText.corps,
                  color: context.colors.secondaire,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
