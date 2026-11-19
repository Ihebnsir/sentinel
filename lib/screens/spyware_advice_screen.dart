import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../models/installed_app.dart';
import '../services/app_risk_calculator.dart';
import '../services/apps_scanner_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';

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
                padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xl),
                children: [
                  Text(
                    l.spywareTitle,
                    style: TextStyle(
                      fontSize: AppText.titreSecondaire,
                      fontWeight: FontWeight.w600,
                      color: context.colors.encre,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Row(
                    children: [
                      AppIcon(app: app, size: AppSize.appIcon),
                      const SizedBox(width: AppSpace.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.label,
                              style: TextStyle(
                                fontSize: AppText.intitule,
                                fontWeight: FontWeight.w500,
                                color: context.colors.encre,
                              ),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              name != null
                                  ? l.detailKnownSpyware(name)
                                  : l.riskSpyProfile,
                              style: TextStyle(
                                fontSize: AppText.detail,
                                color: context.colors.rommen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  const AppDivider(),
                  _Paragraph(l.spywareParagraph1, strong: true),
                  const AppDivider(),
                  _Paragraph(l.spywareParagraph2),
                  const AppDivider(),
                  _Paragraph(l.spywareParagraph3),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.xs),
                    child: Text(
                      l.spywareGetHelp,
                      style: TextStyle(
                        fontSize: AppText.section,
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
                    constraints: const BoxConstraints(minHeight: AppSize.tap),
                    child: SelectableText(
                      stopStalkerwareUrl,
                      style: TextStyle(
                        fontSize: AppText.corps,
                        color: context.colors.bleu,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    l.spywareBrowserNote,
                    style: TextStyle(
                      fontSize: AppText.detail,
                      color: context.colors.secondaire,
                    ),
                  ),
                  // Wrap : à 200 %, le second bouton passe à la ligne.
                  Wrap(
                    spacing: AppSpace.xl,
                    children: [
                      TextButton(
                        style: inlineButtonStyle(context),
                        onPressed: () => AppsScannerService().openWebPage(
                          stopStalkerwareUrl,
                        ),
                        child: Text(l.spywareOpenSite),
                      ),
                      TextButton(
                        style: inlineButtonStyle(context),
                        onPressed: () => _copyLink(context),
                        child: Text(l.spywareCopyAddress),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Text(
                    l.spywareIocCredit,
                    style: TextStyle(
                      fontSize: AppText.legende,
                      color: context.colors.discret,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () =>
                        AppsScannerService().openAppSettings(app.packageName),
                    child: Text(l.detailManagePermissions),
                  ),
                  // Une app système ne peut pas être désinstallée.
                  if (!app.isSystemApp)
                    TextButton(
                      style: dangerButtonStyle(context),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppText.corps,
          height: AppText.interligne,
          fontWeight: strong ? FontWeight.w500 : FontWeight.normal,
          color: context.colors.encre,
        ),
      ),
    );
  }
}
