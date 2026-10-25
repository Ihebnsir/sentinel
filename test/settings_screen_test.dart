import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/app_info.dart';
import 'package:sentinel/main.dart';
import 'package:sentinel/screens/onboarding_screen.dart';
import 'package:sentinel/screens/settings_screen.dart';

void main() {
  late List<String> opened;

  Future<void> pumpSettings(WidgetTester tester) async {
    opened = [];
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(openUrl: opened.add)),
    );
  }

  test('la version affichée suit pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(line.substring(8).trim().split('+').first, appVersion);
  });

  testWidgets('affiche la version et toutes les entrées', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Sentinel $appVersion'), findsOneWidget);
    for (final title in [
      'Revoir la présentation',
      'Politique de confidentialité',
      'Licences',
      "Rapport d'audit de sécurité",
      'Signaler une faille',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
  });

  testWidgets('Politique de confidentialité', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Politique de confidentialité'));
    await tester.pumpAndSettle();

    expect(
      find.text('Les seuls échanges réseau (facultatifs)'),
      findsOneWidget,
    );
  });

  testWidgets('Revoir la présentation puis revenir', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Revoir la présentation'));
    await tester.pumpAndSettle();
    expect(find.text(onboardingPages[0].title), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    expect(find.text('Réglages'), findsOneWidget);
  });

  testWidgets("Rapport d'audit : résumé et lien GitHub", (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text("Rapport d'audit de sécurité"));
    await tester.pumpAndSettle();

    expect(find.text('Les résultats'), findsOneWidget);
    // Le lien est en bas de la page : on fait défiler jusqu'à lui.
    await tester.scrollUntilVisible(
      find.text('Lire le rapport complet sur GitHub'),
      200,
    );
    expect(find.text('Lire le rapport complet sur GitHub'), findsOneWidget);
  });

  testWidgets('Signaler une faille ouvre SECURITY.md', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Signaler une faille'));
    await tester.pump();

    expect(opened, [securityPolicyUrl]);
    expect(securityPolicyUrl, endsWith('/SECURITY.md'));
  });

  testWidgets('Licences ouvre la page des licences', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Licences'));
    // Chargement des licences asynchrone : quelques images suffisent.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LicensePage), findsOneWidget);
  });

  group('licences des données embarquées', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('listes de blocage', () async {
      final entry = await blocklistsLicense().single;
      final text = entry.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('Phishing.Database'));
      expect(text, contains('AdAway'));
    });

    test('logiciels espions (CC BY 4.0)', () async {
      final entry = await stalkerwareLicense().single;
      final text = entry.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('Echap'));
      expect(text, contains('CC BY 4.0'));
    });
  });
}
