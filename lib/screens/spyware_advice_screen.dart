import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/installed_app.dart';
import '../services/app_risk_calculator.dart';
import '../services/apps/stalkerware_ioc.dart';
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Adresse copiée')));
  }

  @override
  Widget build(BuildContext context) {
    final name = report.stalkerwareName;
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
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                children: [
                  const Text(
                    'Avant de toucher à cette application',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.encre,
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.encre,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              name != null
                                  ? 'Logiciel espion connu : $name'
                                  : "Icône cachée et accès typiques d'un "
                                        'logiciel espion',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.rommen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.ligne,
                  ),
                  const _Paragraph(
                    "Si vous pensez que quelqu'un de votre entourage a "
                    'installé cette application, sa suppression peut le '
                    "prévenir. Si vous êtes en danger, contactez d'abord une "
                    "association d'aide ou la police.",
                    strong: true,
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.ligne,
                  ),
                  const _Paragraph(
                    "Avant d'agir, vous pouvez noter le nom de l'application "
                    "et faire une capture d'écran : cela peut servir de preuve.",
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.ligne,
                  ),
                  const _Paragraph(
                    "Sentinel ne prévient personne et n'envoie aucune "
                    'notification à ce sujet.',
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 28, bottom: 4),
                    child: Text(
                      'Se faire aider',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.encre,
                      ),
                    ),
                  ),
                  // TODO(à vérifier) : ajouter des contacts d'aide tunisiens
                  // (associations, numéros officiels) après vérification
                  // auprès des organismes eux-mêmes. Ne jamais recopier un
                  // numéro sans source officielle.
                  const _Paragraph(
                    'Coalition Against Stalkerware : des conseils pour les '
                    "personnes surveillées et des contacts d'associations.",
                  ),
                  const SelectableText(
                    stopStalkerwareUrl,
                    style: TextStyle(fontSize: 15, color: AppColors.bleu),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Le site s'ouvre dans votre navigateur et restera dans "
                    "son historique. Vous pouvez aussi copier l'adresse et "
                    "l'ouvrir en navigation privée, ou depuis un autre "
                    'appareil.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.encre.withValues(alpha: 0.6),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.bleu,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => AppsScannerService().openWebPage(
                          stopStalkerwareUrl,
                        ),
                        child: const Text('Ouvrir le site'),
                      ),
                      const SizedBox(width: 24),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.bleu,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => _copyLink(context),
                        child: const Text("Copier l'adresse"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    iocCredit,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.encre.withValues(alpha: 0.5),
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
                      backgroundColor: AppColors.bleu,
                    ),
                    onPressed: () =>
                        AppsScannerService().openAppSettings(app.packageName),
                    child: const Text('Gérer les autorisations'),
                  ),
                  // Une app système ne peut pas être désinstallée.
                  if (!app.isSystemApp)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.rommen,
                      ),
                      onPressed: () => _uninstall(context),
                      child: const Text('Désinstaller'),
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
          color: AppColors.encre,
        ),
      ),
    );
  }
}
