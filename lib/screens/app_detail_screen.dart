import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../models/installed_app.dart';
import '../services/app_risk_calculator.dart';
import '../services/apps/known_apps.dart';
import '../services/apps_scanner_service.dart';
import '../theme/app_colors.dart';
import '../utils/permission_labels.dart';
import '../widgets/app_icon.dart';
import '../widgets/risk_level_text.dart';
import 'spyware_advice_screen.dart';

/// Détail d'une app : origine, raisons du niveau de risque et autorisations.
class AppDetailScreen extends StatelessWidget {
  const AppDetailScreen({super.key, required this.app, required this.report});

  final InstalledApp app;
  final AppRiskReport report;

  /// D'où vient l'app.
  String _installSource(AppLocalizations l) {
    if (app.isSystemApp) return l.detailPreinstalled;
    // Nom de la boutique officielle (« AppGallery »…), sinon source inconnue.
    return app.storeName ?? l.detailUnknownSource;
  }

  static String _date(AppLocalizations l, DateTime? date) =>
      date == null ? l.commonUnknownFeminine : l.date(date);

  /// Conclusion sur la signature : texte et couleur, null si rien à dire.
  (String, Color)? _signatureVerdict(AppLocalizations l, AppColors c) {
    final brand = report.identity.brand ?? '';
    final stalkerware = report.stalkerwareName;
    if (stalkerware != null) {
      return (l.detailKnownSpyware(stalkerware), c.rommen);
    }
    switch (report.identity.verdict) {
      case IdentityVerdict.verified:
        return (l.detailSignatureVerified(brand), c.zitouna);
      case IdentityVerdict.modifiedCopy:
        return (l.detailSignatureDifferent(brand), c.rommen);
      case IdentityVerdict.impersonation:
        return (l.detailNotOfficial(brand), c.rommen);
      case IdentityVerdict.knownMod:
        return (l.detailKnownMod(brand), c.rommen);
      case IdentityVerdict.officialUnchecked:
        return (l.detailUnchecked(brand), c.secondaire);
      case IdentityVerdict.unknown:
        break;
    }
    if (app.debugCert) {
      return (l.riskDebugCert, c.ocre);
    }
    return null;
  }

  /// Les lignes de la section « Signature ».
  List<Widget> _signatureRows(AppLocalizations l, AppColors c) {
    final cert = app.mainCert;
    final verdict = _signatureVerdict(l, c);
    final others = app.signingCerts.length - 1;
    return _withSeparators([
      if (cert == null)
        _TextRow(l.detailSignatureUnreadable, muted: true)
      else ...[
        _StackedRow(label: l.detailSha256, value: cert.shortSha256),
        _StackedRow(
          label: l.detailCertificate,
          value: cert.subject ?? l.detailPublisherMissing,
        ),
        if (others > 0)
          _TextRow(
            l.detailOtherCertificates(others, l.number(others)),
            muted: true,
          ),
      ],
      if (verdict != null) _TextRow(verdict.$1, color: verdict.$2),
    ]);
  }

  // Logiciel espion possible : on passe d'abord par les conseils.
  void _openAdvice(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SpywareAdviceScreen(app: app, report: report),
      ),
    );
  }

  /// Boutons du bas. Logiciel espion possible : un seul bouton, vers les
  /// conseils, pour ne pas désinstaller sans réfléchir.
  List<Widget> _actions(BuildContext context) {
    final l = context.l10n;
    if (report.spywareSuspected) {
      return [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: context.colors.rommen),
          onPressed: () => _openAdvice(context),
          child: Text(l.detailWhatToDo),
        ),
      ];
    }
    return [
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: context.colors.bleu),
        onPressed: () => AppsScannerService().openAppSettings(app.packageName),
        child: Text(l.detailManagePermissions),
      ),
      // Une app système ne peut pas être désinstallée.
      if (!app.isSystemApp)
        TextButton(
          style: TextButton.styleFrom(foregroundColor: context.colors.rommen),
          onPressed: () => _uninstall(context),
          child: Text(l.detailUninstall),
        ),
    ];
  }

  void _uninstall(BuildContext context) {
    // On revient à la liste : elle se recharge au retour dans l'app.
    Navigator.of(context).pop();
    AppsScannerService().uninstallApp(app.packageName);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = <String>[];
    var technicalCount = 0; // permissions sans libellé simple
    for (final permission in app.grantedPermissions) {
      final label = permissionLabel(l, permission);
      if (label == null) {
        technicalCount++;
      } else {
        labels.add(label);
      }
    }

    return Scaffold(
      // Barre du haut discrète : juste la flèche retour, sans ombre.
      appBar: AppBar(
        backgroundColor: context.colors.chaux,
        foregroundColor: context.colors.encre,
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
                  // Align : sinon la ListView étire l'icône sur toute la
                  // largeur, et l'image agrandie devient floue.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppIcon(app: app, size: 64),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    app.label,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: context.colors.encre,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.packageName,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.secondaire,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _InfoRow(
                    label: l.detailRiskLevel,
                    trailing: RiskLevelText(level: report.level, fontSize: 15),
                  ),
                  const _Separator(),
                  _InfoRow(
                    label: l.detailSource,
                    value: _installSource(l),
                  ),
                  const _Separator(),
                  _InfoRow(
                    label: l.detailInstalledOn,
                    value: _date(l, app.firstInstallTime),
                  ),
                  const _Separator(),
                  _InfoRow(
                    label: l.detailUpdatedOn,
                    value: _date(l, app.lastUpdateTime),
                  ),
                  _SectionTitle(l.detailWhyLevel),
                  if (report.level == RiskLevel.systeme)
                    _TextRow(l.detailSystemExplanation)
                  else if (report.rules.isEmpty)
                    _TextRow(l.appsNoWorry)
                  else
                    ..._withSeparators(report.reasons(l).map(_TextRow.new)),
                  _SectionTitle(l.detailSignature),
                  ..._signatureRows(l, context.colors),
                  _SectionTitle(l.detailGrantedPermissions),
                  if (labels.isEmpty && technicalCount == 0)
                    _TextRow(l.detailNoPermissions),
                  ..._withSeparators([
                    ...labels.map(_TextRow.new),
                    if (technicalCount > 0)
                      _TextRow(
                        l.detailOtherPermissions(
                          technicalCount,
                          l.number(technicalCount),
                        ),
                        muted: true,
                      ),
                  ]),
                ],
              ),
            ),
            // Les actions, toujours visibles en bas de l'écran.
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _actions(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Intercale un séparateur fin entre les lignes (pas avant la première).
List<Widget> _withSeparators(Iterable<Widget> rows) {
  final result = <Widget>[];
  for (final row in rows) {
    if (result.isNotEmpty) result.add(const _Separator());
    result.add(row);
  }
  return result;
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: context.colors.ligne);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.colors.encre,
        ),
      ),
    );
  }
}

/// Ligne « libellé … valeur », ex : « Source … Play Store ».
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.trailing});

  final String label;
  final String? value;
  final Widget? trailing; // remplace value si fourni

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
          trailing ??
              Text(
                value ?? '',
                style: TextStyle(fontSize: 15, color: context.colors.encre),
              ),
        ],
      ),
    );
  }
}

/// Libellé discret au-dessus de sa valeur, pour les textes longs.
class _StackedRow extends StatelessWidget {
  const _StackedRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: context.colors.secondaire),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: TextStyle(fontSize: 15, color: context.colors.encre),
          ),
        ],
      ),
    );
  }
}

/// Ligne de texte simple (une raison, une autorisation).
class _TextRow extends StatelessWidget {
  const _TextRow(this.text, {this.muted = false, this.color});

  final String text;
  final bool muted; // texte plus discret
  final Color? color; // couleur imposée (verdict de signature)

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color:
              color ??
              (muted ? context.colors.secondaire : context.colors.encre),
        ),
      ),
    );
  }
}
