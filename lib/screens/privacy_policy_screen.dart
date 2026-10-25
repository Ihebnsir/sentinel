import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../widgets/text_page.dart';

/// Politique de confidentialité, écrite d'après ce que fait le code.
/// Toute nouvelle fonction réseau ou donnée stockée doit être ajoutée ici
/// (et dans la présentation, onboarding_screen.dart).
List<TextSection> privacySections(AppLocalizations l) => [
  TextSection(l.privacyBriefTitle, [l.privacyBrief1, l.privacyBrief2]),
  TextSection(l.privacyNetworkTitle, [
    l.privacyNetwork1,
    l.privacyNetwork2,
    l.privacyNetwork3,
    l.privacyNetwork4,
  ]),
  TextSection(l.privacyLocalTitle, [
    l.privacyLocal1,
    l.privacyLocal2,
    l.privacyLocal3,
    l.privacyLocal4,
    l.privacyLocal5,
  ]),
  TextSection(l.privacyNeverTitle, [
    l.privacyNever1,
    l.privacyNever2,
    l.privacyNever3,
  ]),
  TextSection(l.privacyPermissionsTitle, [
    l.privacyPermissions1,
    l.privacyPermissions2,
    l.privacyPermissions3,
    l.privacyPermissions4,
    l.privacyPermissions5,
  ]),
  TextSection(l.privacyEraseTitle, [l.privacyErase1]),
];

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextPage(title: l.settingsPrivacy, sections: privacySections(l));
  }
}
