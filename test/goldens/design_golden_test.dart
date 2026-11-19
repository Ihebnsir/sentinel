import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/l10n/l10n.dart';
import 'package:sentinel/screens/main_shell.dart';
import 'package:sentinel/screens/vault_screen.dart';
import 'package:sentinel/services/apps/stalkerware_ioc.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/theme/app_theme.dart';

import '../support/design_fakes.dart';

// Tests golden : l'accueil, le vérificateur de liens et le coffre, en
// français clair, français sombre et arabe (droite à gauche). Toute
// modification visuelle fait échouer le test : si elle est voulue,
// régénérer les images avec
//   flutter test --update-goldens test/goldens
// puis vérifier les PNG de test/goldens/images/ avant de les commiter.
// Rendu sous Windows (les images peuvent différer d'un système à l'autre).

const _variants = [
  ('fr_clair', Locale('fr'), false),
  ('fr_sombre', Locale('fr'), true),
  ('ar_clair', Locale('ar'), false),
];

typedef _Build = Future<Widget> Function(WidgetTester tester, Directory dir);

Future<void> _golden(
  WidgetTester tester,
  String name,
  _Build build, {
  required Locale locale,
  required bool dark,
  Future<void> Function(WidgetTester, AppLocalizations)? prepare,
}) async {
  final dir = Directory.systemTemp.createTempSync('golden');
  addTearDown(() => dir.deleteSync(recursive: true));
  fakeAndroid(dir);
  // Téléphone de 412 × 914 dp (Pixel 8), densité 1 : images légères.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 914);
  addTearDown(tester.view.reset);
  final home = await build(tester, dir);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.dark : AppTheme.light,
      locale: locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: home,
    ),
  );
  await settleAsync(tester);
  await prepare?.call(tester, lookupAppLocalizations(locale));
  await settleAsync(tester);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('images/$name.png'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadRealFonts();
    await loadKnownBrands();
    await StalkerwareIoc.load();
  });

  for (final (variant, locale, dark) in _variants) {
    testWidgets('accueil ($variant)', (tester) async {
      await _golden(
        tester,
        'accueil_$variant',
        (_, _) async => const MainShell(),
        locale: locale,
        dark: dark,
      );
    });

    testWidgets('vérificateur de liens ($variant)', (tester) async {
      await _golden(
        tester,
        'liens_$variant',
        (_, _) async => const MainShell(initialIndex: 2),
        locale: locale,
        dark: dark,
        prepare: (tester, l) async {
          await tester.enterText(
            find.byType(TextField),
            'Votre colis est bloqué, payez ici : poste-tn-livraison.xyz/p',
          );
          await tester.pump();
          await tester.tap(find.text(l.linksCheck));
          await settleAsync(tester);
          FocusManager.instance.primaryFocus?.unfocus();
        },
      );
    });

    testWidgets('coffre ($variant)', (tester) async {
      await _golden(
        tester,
        'coffre_$variant',
        (tester, dir) async {
          final session = await sampleVault(tester, dir);
          return MainShell(
            initialIndex: 3,
            vaultBuilder: (visible) => VaultScreen(
              visible: visible,
              session: session,
              breaches: sampleBreaches(dir),
            ),
          );
        },
        locale: locale,
        dark: dark,
      );
    });
  }
}
