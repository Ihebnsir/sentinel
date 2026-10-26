import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../models/installed_app.dart';
import '../services/app_risk_calculator.dart';
import '../services/apps_scanner_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon.dart';

/// Site de la Coalition Against Stalkerware (conseils aux victimes).
const stopStalkerwareUrl = 'https://stopstalkerware.org';

/// Conseils affichés AVANT toute action sur un logiciel espion possible :
/// le supprimer peut prévenir la personne qui l'a installé.
/// Volontairement aucune notification : quelqu'un d'autre pourrait la voir.
class SpywareAdviceScreen extends StatelessWidget {
  const SpywareAdviceScreen({
    super.key,
    required this.app,
    required this.report,
  });

  final InstalledApp app;
  final AppRiskReport report;

  void _uninstall(BuildContext context) {
    // Retour à la liste : elle se recharge au retour dans l'app.
    Navigator.of(context).popUntil((route) => route.isFirst);
    AppsScannerService().uninstallApp(app.packageName);
  }

  void _copyLink(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: stopStalkerwareUrl));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.spywareAddressCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = report.stalkerwareName;
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
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                children: [
                  Text(
                    l.spywareTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: context.colors.encre,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      AppIcon(app: app, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: context.colors.encre,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              name != null
                                  ? l.detailKnownSpyware(name)
                                  : l.riskSpyProfile,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.rommen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(height: 1, thickness: 1, color: context.colors.ligne),
                  _Paragraph(l.spywareParagraph1, strong: true),
                  Divider(height: 1, thickness: 1, color: context.colors.ligne),
                  _Paragraph(l.spywareParagraph2),
                  Divider(height: 1, thickness: 1, color: context.colors.ligne),
                  _Paragraph(l.spywareParagraph3),
                  Padding(
                    padding: const EdgeInsets.only(top: 28, bottom: 4),
                    child: Text(
                      l.spywareGetHelp,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.colors.encre,
                      ),
                    ),
                  ),
                  // TODO(à vérifier) : ajouter des contacts d'aide tunisiens
                  // (associations, numéros officiels) après vérification
                  // auprès des organismes eux-mêmes. Ne jamais recopier un
                  // numéro sans source officielle.
                  _Paragraph(l.spywareCoalition),
                  // 48 dp de haut : zone tactile minimale (appui long).
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: SelectableText(
                      stopStalkerwareUrl,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.colors.bleu,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.spywareBrowserNote,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.secondaire,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: context.colors.bleu,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => AppsScannerService().openWebPage(
                          stopStalkerwareUrl,
                        ),
                        child: Text(l.spywareOpenSite),
                      ),
                      const SizedBox(width: 24),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: context.colors.bleu,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => _copyLink(context),
                        child: Text(l.spywareCopyAddress),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l.spywareIocCredit,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.discret,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.bleu,
                    ),
                    onPressed: () =>
                        AppsScannerService().openAppSettings(app.packageName),
                    child: Text(l.detailManagePermissions),
                  ),
                  // Une app système ne peut pas être désinstallée.
                  if (!app.isSystemApp)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.rommen,
                      ),
                      onPressed: () => _uninstall(context),
                      child: Text(l.detailUninstall),
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

/// Paragraphe de conseil ; [strong] : le conseil principal, plus visible.
class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          height: 1.4,
          fontWeight: strong ? FontWeight.w500 : FontWeight.normal,
          color: context.colors.encre,
        ),
      ),
    );
  }
}
