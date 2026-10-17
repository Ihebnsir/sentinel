import 'package:material_ui/material_ui.dart';

import '../models/installed_app.dart';
import '../services/app_risk_calculator.dart';
import '../services/apps/known_apps.dart';
import '../services/apps_scanner_service.dart';
import '../theme/app_colors.dart';
import '../utils/french_date.dart';
import '../utils/permission_labels.dart';
import '../widgets/app_icon.dart';
import '../widgets/risk_level_text.dart';
import 'spyware_advice_screen.dart';

/// Détail d'une app : origine, raisons du niveau de risque et autorisations.
class AppDetailScreen extends StatelessWidget {
  const AppDetailScreen({super.key, required this.app, required this.report});

  final InstalledApp app;
  final AppRiskReport report;

  /// D'où vient l'app, en français.
  String _installSource() {
    if (app.isSystemApp) return 'Préinstallée';
    // Nom de la boutique officielle (« AppGallery »…), sinon source inconnue.
    return app.storeName ?? 'Source inconnue';
  }

  static String _date(DateTime? date) =>
      date == null ? 'Inconnue' : formatFrenchDate(date);

  /// Conclusion sur la signature : texte et couleur, null si rien à dire.
  (String, Color)? _signatureVerdict() {
    final brand = report.identity.brand;
    final stalkerware = report.stalkerwareName;
    if (stalkerware != null) {
      return ('Logiciel espion connu : $stalkerware', AppColors.rommen);
    }
    switch (report.identity.verdict) {
      case IdentityVerdict.verified:
        return ('Signature vérifiée pour $brand', AppColors.zitouna);
      case IdentityVerdict.modifiedCopy:
        return (
          "Signature différente de l'éditeur officiel de $brand",
          AppColors.rommen,
        );
      case IdentityVerdict.impersonation:
        return (
          "Ce n'est pas l'application officielle de $brand",
          AppColors.rommen,
        );
      case IdentityVerdict.knownMod:
        return ('Version modifiée non officielle de $brand', AppColors.rommen);
      case IdentityVerdict.officialUnchecked:
        return (
          'Empreinte officielle de $brand pas encore enregistrée dans Sentinel',
          AppColors.encre.withValues(alpha: 0.6),
        );
      case IdentityVerdict.unknown:
        break;
    }
    if (app.debugCert) {
      return ('Signée avec un certificat de test', AppColors.ocre);
    }
    return null;
  }

  /// Les lignes de la section « Signature ».
  List<Widget> _signatureRows() {
    final cert = app.mainCert;
    final verdict = _signatureVerdict();
    final others = app.signingCerts.length - 1;
    return _withSeparators([
      if (cert == null)
        const _TextRow('Signature illisible', muted: true)
      else ...[
        _StackedRow(label: 'Empreinte SHA-256', value: cert.shortSha256),
        _StackedRow(
          label: 'Certificat',
          value: cert.subject ?? 'Éditeur non renseigné',
        ),
        if (others > 0)
          _TextRow(
            others > 1
                ? 'Et $others autres certificats (anciens ou multiples)'
                : 'Et 1 autre certificat (ancien ou multiple)',
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
    if (report.spywareSuspected) {
      return [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rommen),
          onPressed: () => _openAdvice(context),
          child: const Text('Que faire ?'),
        ),
      ];
    }
    return [
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.bleu),
        onPressed: () => AppsScannerService().openAppSettings(app.packageName),
        child: const Text('Gérer les autorisations'),
      ),
      // Une app système ne peut pas être désinstallée.
      if (!app.isSystemApp)
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.rommen),
          onPressed: () => _uninstall(context),
          child: const Text('Désinstaller'),
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
    final labels = <String>[];
    var technicalCount = 0; // permissions sans libellé français
    for (final permission in app.grantedPermissions) {
      final label = permissionLabel(permission);
      if (label == null) {
        technicalCount++;
      } else {
        labels.add(label);
      }
    }

    return Scaffold(
      // Barre du haut discrète : juste la flèche retour, sans ombre.
      appBar: AppBar(
        backgroundColor: AppColors.chaux,
        foregroundColor: AppColors.encre,
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
                  AppIcon(app: app, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    app.label,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.encre,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.packageName,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.encre.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _InfoRow(
                    label: 'Niveau de risque',
                    trailing: RiskLevelText(level: report.level, fontSize: 15),
                  ),
                  const _Separator(),
                  _InfoRow(label: 'Source', value: _installSource()),
                  const _Separator(),
                  _InfoRow(
                    label: 'Installée le',
                    value: _date(app.firstInstallTime),
                  ),
                  const _Separator(),
                  _InfoRow(
                    label: 'Mise à jour le',
                    value: _date(app.lastUpdateTime),
                  ),
                  const _SectionTitle('Pourquoi ce niveau'),
                  if (report.level == RiskLevel.systeme)
                    const _TextRow(
                      "Cette application fait partie d'Android ou de votre "
                      'fabricant. Ses autorisations étendues sont normales '
                      'pour son fonctionnement.',
                    )
                  else if (report.reasons.isEmpty)
                    const _TextRow('Aucun signal inquiétant')
                  else
                    ..._withSeparators(report.reasons.map(_TextRow.new)),
                  const _SectionTitle('Signature'),
                  ..._signatureRows(),
                  const _SectionTitle('Autorisations accordées'),
                  if (labels.isEmpty && technicalCount == 0)
                    const _TextRow('Aucune autorisation accordée'),
                  ..._withSeparators([
                    ...labels.map(_TextRow.new),
                    if (technicalCount > 0)
                      _TextRow(
                        technicalCount > 1
                            ? 'Et $technicalCount autres autorisations techniques'
                            : 'Et 1 autre autorisation technique',
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
    return const Divider(height: 1, thickness: 1, color: AppColors.ligne);
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
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.encre,
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
              style: TextStyle(
                fontSize: 15,
                color: AppColors.encre.withValues(alpha: 0.6),
              ),
            ),
          ),
          trailing ??
              Text(
                value ?? '',
                style: const TextStyle(fontSize: 15, color: AppColors.encre),
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
            style: TextStyle(
              fontSize: 13,
              color: AppColors.encre.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 15, color: AppColors.encre),
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
              (muted
                  ? AppColors.encre.withValues(alpha: 0.6)
                  : AppColors.encre),
        ),
      ),
    );
  }
}
