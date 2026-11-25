import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/screens/vault_screen.dart';
import 'package:sentinel/services/breach/breach_checker.dart';
import 'package:sentinel/services/breach/breach_consent.dart';
import 'package:sentinel/services/vault/vault_session.dart';
import 'package:sentinel/services/vault/vault_storage.dart';
import 'package:sentinel/theme/app_colors.dart';
import 'package:sentinel/theme/app_theme.dart';
import 'package:sentinel/widgets/arch_icon.dart';
import 'package:sentinel/widgets/score_arch.dart';
import 'package:sentinel/widgets/ui.dart';

import 'package:sentinel/screens/main_shell.dart';
import 'package:sentinel/services/apps/stalkerware_ioc.dart';
import 'package:sentinel/services/phishing/known_brands.dart';

import 'support/design_fakes.dart';
import 'support/fake_biometrics.dart';
import 'support/l10n.dart';

// Garde-fous du système de design (docs/DESIGN.md) : pas de valeur
// magique dans les écrans, animations coupées sur demande, statuts jamais
// réduits à une couleur, protections du coffre intactes.

/// Fichiers Dart des écrans et widgets (hors jetons et composants).
Iterable<File> _uiSources() => [
  for (final dir in ['lib/screens', 'lib/widgets'])
    ...Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              !f.path.replaceAll(r'\', '/').contains('/widgets/ui/'),
        ),
];

void main() {
  group('aucune valeur magique dans les écrans', () {
    final rules = {
      'taille de texte': RegExp(r'fontSize: \d'),
      'espacement SizedBox': RegExp(r'SizedBox\((height|width): [1-9]'),
      'marge EdgeInsets': RegExp(r'EdgeInsets[A-Za-z]*\.\w+\([^)]*\b[1-9]'),
      'couleur codée en dur': RegExp(r'Color\(0x'),
      'durée d\'animation': RegExp(r'duration: const Duration\('),
      'rayon': RegExp(r'BorderRadius\.circular\(\d'),
    };
    for (final MapEntry(key: name, value: rule) in rules.entries) {
      test(name, () {
        final found = <String>[];
        for (final file in _uiSources()) {
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            if (rule.hasMatch(lines[i])) found.add('${file.path}:${i + 1}');
          }
        }
        expect(found, isEmpty, reason: 'utiliser lib/theme/tokens.dart');
      });
    }

    test('Colors.* seulement transparent (et le visualiseur photo)', () {
      final found = <String>[];
      for (final file in _uiSources()) {
        if (file.path.endsWith('vault_document_screen.dart')) continue;
        final text = file.readAsStringSync();
        for (final m in RegExp(r'Colors\.(\w+)').allMatches(text)) {
          if (m.group(1) != 'transparent') found.add('${file.path} ${m[0]}');
        }
      }
      expect(found, isEmpty);
    });
  });

  group('animations', () {
    testWidgets('arche : remplissage progressif par défaut', (tester) async {
      await tester.pumpWidget(
        testApp(home: const Scaffold(body: ScoreArch(score: 80))),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('80'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('80'), findsOneWidget);
    });

    testWidgets('« Supprimer les animations » : score affiché d\'un coup', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: ScoreArch(score: 80)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('80'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    test('durées coupées par AppMotion.of', () {
      expect(AppMotion.lent, greaterThan(Duration.zero));
      expect(AppMotion.score, lessThanOrEqualTo(const Duration(seconds: 2)));
    });
  });

  group('statuts : couleur + icône + texte', () {
    for (final level in StatusLevel.values) {
      testWidgets('badge ${level.name}', (tester) async {
        await tester.pumpWidget(
          testApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Center(
                child: StatusBadge(level: level, label: 'Libellé'),
              ),
            ),
          ),
        );
        expect(find.text('Libellé'), findsOneWidget);
        expect(find.byIcon(level.icon), findsOneWidget);
      });
    }

    test('chaque niveau a une icône différente', () {
      final icons = {for (final l in StatusLevel.values) l.icon};
      expect(icons, hasLength(StatusLevel.values.length));
    });
  });

  group('état vide illustré', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      testWidgets('arche (${theme.brightness.name})', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          testApp(
            theme: theme,
            home: Scaffold(
              body: EmptyState(
                title: 'Titre',
                message: 'Message',
                buttonLabel: 'Action',
                onPressed: () {},
              ),
            ),
          ),
        );
        // Grande arche pleine, en bleu du thème.
        final arch = tester.widget<ArchIcon>(find.byType(ArchIcon));
        expect(arch.filled, isTrue);
        expect(arch.size, AppSize.illustration);
        expect(arch.color, theme.extension<AppColors>()?.bleu);
        // Dessin décoratif : rien d'annoncé par TalkBack.
        expect(
          find.ancestor(
            of: find.byType(ArchIcon),
            matching: find.byType(ExcludeSemantics),
          ),
          findsWidgets,
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });

  group('arabe, droite à gauche, police à 200 %', () {
    setUpAll(() async {
      await loadRealFonts();
      await loadKnownBrands();
      await StalkerwareIoc.load();
    });
    for (final (index, name) in [
      (0, 'accueil'),
      (1, 'applications'),
      (2, 'liens'),
      (3, 'coffre'),
    ]) {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        testWidgets('$name (${theme.brightness.name})', (tester) async {
          final dir = Directory.systemTemp.createTempSync('rtl');
          addTearDown(() => dir.deleteSync(recursive: true));
          fakeAndroid(dir);
          tester.view.devicePixelRatio = 3;
          tester.view.physicalSize = const Size(360 * 3, 800 * 3);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(
            testApp(
              locale: const Locale('ar'),
              theme: theme,
              home: MainShell(initialIndex: index),
            ),
          );
          await settleAsync(tester);
          // Un débordement (bandes jaunes et noires) lève une erreur ici.
          expect(tester.takeException(), isNull);
          final context = tester.element(find.byType(NavigationBar));
          expect(Directionality.of(context), TextDirection.rtl);
        });
      }
    }
  });

  testWidgets('coffre : FLAG_SECURE suit l\'onglet visible', (tester) async {
    final calls = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.iheb.sentinel/vault'),
      (call) async {
        if (call.method == 'setSecure') {
          calls.add((call.arguments as Map)['secure'] as bool);
        }
        return null;
      },
    );
    final dir = Directory.systemTemp.createTempSync('secure');
    addTearDown(() => dir.deleteSync(recursive: true));
    final session = VaultSession(
      storage: VaultStorage(directory: () async => dir),
      biometrics: FakeBiometrics(),
    );
    final breaches = BreachChecker(
      consentStore: BreachConsentStore(directory: () async => dir),
    );
    Widget vault(bool visible) => testApp(
      home: Scaffold(
        body: VaultScreen(
          visible: visible,
          session: session,
          breaches: breaches,
        ),
      ),
    );
    await tester.pumpWidget(vault(true));
    await tester.pumpWidget(vault(false));
    await tester.pumpWidget(vault(true));
    expect(calls, [true, false, true]);
    await tester.pumpWidget(const SizedBox());
    expect(calls.last, isFalse, reason: 'protection retirée à la fermeture');
  });
}
