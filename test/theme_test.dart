import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/l10n/l10n.dart';
import 'package:sentinel/screens/settings_screen.dart';
import 'package:sentinel/services/theme_store.dart';
import 'package:sentinel/theme/app_colors.dart';
import 'package:sentinel/theme/app_theme.dart';
import 'package:sentinel/widgets/score_arch.dart';

import 'support/l10n.dart';

// Seuils WCAG 2.x niveau AA.
const _texte = 4.5; // texte courant
const _grand = 3.0; // grand texte, icônes, traits utiles

/// Contraste d'une couleur (éventuellement transparente) posée sur [fond].
double _sur(Color couleur, Color fond) =>
    contrastRatio(Color.alphaBlend(couleur, fond), fond);

/// Choix en mémoire : pas de vrai fichier dans les tests widget.
class _MemoryStore extends ThemeStore {
  ThemeMode saved = ThemeMode.system;

  @override
  Future<ThemeMode> load() async => saved;

  @override
  Future<void> save(ThemeMode mode) async => saved = mode;
}

void main() {
  group('calcul du contraste (WCAG)', () {
    test('valeurs de référence', () {
      const noir = Color(0xFF000000);
      const blanc = Color(0xFFFFFFFF);
      expect(contrastRatio(noir, blanc), closeTo(21, 0.01));
      expect(contrastRatio(blanc, blanc), closeTo(1, 0.001));
      // Gris #777777 sur blanc : 4,48 (exemple classique, juste sous AA).
      expect(
        contrastRatio(const Color(0xFF777777), blanc),
        closeTo(4.48, 0.01),
      );
      // L'ordre ne compte pas.
      expect(contrastRatio(blanc, noir), contrastRatio(noir, blanc));
    });
  });

  group('thème sombre : paires principales au niveau AA', () {
    const c = AppColors.dark;
    final paires = {
      'texte': c.encre,
      'texte secondaire': c.secondaire,
      'texte discret': c.discret,
      'bleu (liens, boutons texte)': c.bleu,
      'vert (rien de suspect)': c.zitouna,
      'ocre (suspect, modéré)': c.ocre,
      'rouge (arnaque, danger)': c.rommen,
    };
    for (final MapEntry(key: nom, value: couleur) in paires.entries) {
      test('$nom sur le fond nuit', () {
        expect(_sur(couleur, c.chaux), greaterThanOrEqualTo(_texte));
      });
    }

    test('texte sur bouton bleu et sur couleurs pleines', () {
      for (final fond in [c.bleu, c.rommen, c.ocre, c.zitouna]) {
        expect(
          contrastRatio(c.textOn(fond), fond),
          greaterThanOrEqualTo(_texte),
          reason: '$fond',
        );
      }
      expect(c.textOn(c.bleu), c.surCouleur); // bleu nuit sur bleu clair
    });

    test('onglet inactif (texte secondaire) lisible, dans les deux thèmes', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final label = theme.navigationBarTheme.labelTextStyle!.resolve({})!;
        final fond = theme.extension<AppColors>()!.chaux;
        expect(_sur(label.color!, fond), greaterThanOrEqualTo(_texte));
      }
    });

    test('lignes fines visibles, sans être criardes', () {
      final ratio = contrastRatio(c.ligne, c.chaux);
      expect(ratio, greaterThan(1.3));
      expect(ratio, lessThan(_grand));
    });
  });

  group('thème clair : paires principales', () {
    const c = AppColors.light;
    test(
      'texte, secondaire, discret, ocre, bleu, vert, rouge au niveau AA',
      () {
        for (final couleur in [
          c.encre,
          c.secondaire,
          c.discret,
          c.ocre,
          c.bleu,
          c.zitouna,
          c.rommen,
        ]) {
          expect(
            _sur(couleur, c.chaux),
            greaterThanOrEqualTo(_texte),
            reason: '$couleur',
          );
        }
      },
    );

    test('texte sur couleurs pleines : le plus lisible est choisi', () {
      expect(c.textOn(c.bleu), c.surCouleur); // blanc sur bleu
      expect(c.textOn(c.rommen), c.surCouleur);
      // Ambre foncé : le blanc y est lisible (5,5:1).
      expect(c.textOn(c.ocre), c.surCouleur);
      for (final fond in [c.bleu, c.rommen, c.ocre]) {
        expect(
          contrastRatio(c.textOn(fond), fond),
          greaterThanOrEqualTo(_texte),
        );
      }
    });
  });

  group('AppTheme', () {
    test('sombre : fond nuit, palette nuit, texte clair', () {
      final theme = AppTheme.dark;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0E1A33));
      expect(theme.extension<AppColors>(), AppColors.dark);
      expect(theme.colorScheme.primary, AppColors.dark.bleu);
      expect(theme.colorScheme.onPrimary, AppColors.dark.surCouleur);
    });

    test('clair : palette d\'origine', () {
      final theme = AppTheme.light;
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F7F8));
      expect(theme.extension<AppColors>(), AppColors.light);
    });

    test('passage progressif d\'un thème à l\'autre', () {
      final milieu = AppColors.light.lerp(AppColors.dark, 0.5);
      expect(
        milieu.chaux,
        Color.lerp(AppColors.light.chaux, AppColors.dark.chaux, 0.5),
      );
      expect(AppColors.light.lerp(null, 0.5), AppColors.light);
      expect(
        AppColors.light.copyWith(bleu: AppColors.dark.bleu).bleu,
        AppColors.dark.bleu,
      );
    });

    testWidgets('sans extension (tests), palette selon la luminosité', (
      tester,
    ) async {
      late AppColors lu;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (context) {
              lu = context.colors;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(lu, AppColors.dark);
    });
  });

  group('arche du score : chiffre lisible sur la partie remplie', () {
    Future<Color?> chiffre(
      WidgetTester tester,
      ThemeData theme,
      int score,
    ) async {
      await tester.pumpWidget(
        testApp(
          theme: theme,
          home: Scaffold(body: ScoreArch(score: score)),
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget<Text>(find.text('$score')).style?.color;
    }

    testWidgets('sombre : bleu nuit sur bleu et ocre', (tester) async {
      expect(
        await chiffre(tester, AppTheme.dark, 80),
        AppColors.dark.surCouleur,
      );
      expect(
        await chiffre(tester, AppTheme.dark, 60),
        AppColors.dark.surCouleur,
      );
    });

    testWidgets('clair : blanc sur bleu et sur ocre', (tester) async {
      expect(
        await chiffre(tester, AppTheme.light, 80),
        AppColors.light.surCouleur,
      );
      expect(
        await chiffre(tester, AppTheme.light, 60),
        AppColors.light.surCouleur,
      );
    });

    testWidgets('score bas : chiffre sur le fond, couleur du texte', (
      tester,
    ) async {
      expect(await chiffre(tester, AppTheme.dark, 20), AppColors.dark.encre);
    });
  });

  group('choix du thème', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('theme'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('fichier : système au départ, puis le choix enregistré', () async {
      final store = ThemeStore(directory: () async => dir);
      expect(await store.load(), ThemeMode.system);
      await store.save(ThemeMode.dark);
      expect(
        await ThemeStore(directory: () async => dir).load(),
        ThemeMode.dark,
      );
    });

    test('fichier abîmé ou valeur inconnue : thème du téléphone', () async {
      final file = File('${dir.path}/${ThemeStore.fileName}');
      file.writeAsStringSync('{');
      expect(
        await ThemeStore(directory: () async => dir).load(),
        ThemeMode.system,
      );
      file.writeAsStringSync('{"theme": "violet"}');
      expect(
        await ThemeStore(directory: () async => dir).load(),
        ThemeMode.system,
      );
    });

    testWidgets('Réglages : choisir Sombre, puis Comme le téléphone', (
      tester,
    ) async {
      final store = _MemoryStore();
      final controller = ThemeController(store: store);
      await tester.pumpWidget(
        ThemeScope(
          controller: controller,
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: controller,
            builder: (context, mode, _) => MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              locale: const Locale('fr'),
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationsDelegates,
              home: const SettingsScreen(),
            ),
          ),
        ),
      );
      Brightness brightness() =>
          Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

      expect(find.text(fr.settingsTheme), findsOneWidget);
      expect(find.text(fr.settingsThemeSystem), findsOneWidget);

      await tester.tap(find.text(fr.settingsTheme));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.settingsThemeDark));
      await tester.pumpAndSettle();
      expect(controller.value, ThemeMode.dark);
      expect(store.saved, ThemeMode.dark);
      expect(brightness(), Brightness.dark); // appliqué tout de suite
      expect(find.text(fr.settingsThemeDark), findsOneWidget); // sous-titre

      await tester.tap(find.text(fr.settingsTheme));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.settingsThemeSystem).last);
      await tester.pumpAndSettle();
      expect(store.saved, ThemeMode.system);
      // Téléphone en clair dans les tests : retour au thème clair.
      expect(brightness(), Brightness.light);
    });
  });
}
