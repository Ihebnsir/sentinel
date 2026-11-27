import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/l10n/l10n.dart';
import 'package:sentinel/screens/qr_result_screen.dart';
import 'package:sentinel/services/links/link_checker.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/qr/qr_content.dart';
import 'package:sentinel/services/qr/qr_safety.dart';
import 'package:sentinel/theme/app_colors.dart';
import 'package:sentinel/widgets/ui.dart';

import 'support/l10n.dart';

// 1.2.1 : « Absent des listes » n'est jamais une raison de danger, et le
// conseil final suit le type de menace.

const _unknown = DomainCheck(allowed: false, dangerous: false);

QrAssessment _assess(String raw) => assessQr(parseQr(raw), lists: _unknown);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKnownBrands);

  group('« Absent des listes » (notListed)', () {
    test('lien sain : information, pas une raison', () {
      final c = checkText('https://www.exemple.tn', lists: _unknown)!;
      expect(c.verdict, Verdict.rien);
      expect(c.notListed, isTrue);
      expect(c.reasons(fr), isEmpty);
    });

    test('suspect, dangereux, liste blanche ou listes absentes : rien', () {
      final cases = {
        'http://www.exemple.tn': _unknown, // suspect (http)
        'https://colis.example/p': const DomainCheck(
          allowed: false,
          dangerous: true,
        ),
        'https://perso.example': const DomainCheck(
          allowed: true,
          dangerous: false,
        ),
        'https://www.biat.com.tn': const DomainCheck(
          allowed: false,
          dangerous: false,
          listsAvailable: false,
        ),
      };
      cases.forEach((text, lists) {
        expect(checkText(text, lists: lists)!.notListed, isFalse, reason: text);
      });
      expect(checkText('https://www.exemple.tn')!.notListed, isFalse);
    });

    test('textes en français, arabe et anglais', () {
      expect(
        fr.linkNoteNotListed,
        "Ce domaine n'est pas dans les listes de sites dangereux connus "
        "(cela ne garantit pas qu'il est sûr).",
      );
      expect(ar.linkNoteNotListed, isNot(contains('Sentinel')));
      expect(en.linkNoteNotListed, contains("doesn't guarantee"));
    });
  });

  group('conseil final selon la menace (qrAdvice)', () {
    final cases = <String, String Function(AppLocalizations)>{
      // Installation d'appli : .apk direct, boutique alternative.
      'https://exemple.tn/WhatsApp-Gold.apk': (l) => l.adviceApp,
      'https://apkpure.com/whatsapp/com.whatsapp': (l) => l.adviceApp,
      // Lien de messagerie qui demande un code.
      'https://wa.me/21620123456?text=Envoie%20moi%20le%20code%20re%C3%A7u': (
        l,
      ) => l.adviceMessaging,
      // Contact qui se fait passer pour un service client.
      'BEGIN:VCARD\nVERSION:3.0\nFN:Service client BIAT\nTEL:+21670000000\nEND:VCARD':
          (l) => l.adviceContact,
      // Cryptomonnaie.
      'bitcoin:bc1qxyz?amount=1': (l) => l.adviceCrypto,
      // Lien web d'hameçonnage : le conseil « aucun code ni mot de passe ».
      'http://192.168.4.1/login': (l) => l.adviceDangerous,
      'http://www.exemple.tn': (l) => l.adviceSuspect,
      // Rien de connu.
      'https://www.exemple.tn': (l) => l.adviceNothingKnown,
    };

    for (final MapEntry(key: raw, value: expected) in cases.entries) {
      test(raw.split('\n').first, () {
        final a = _assess(raw);
        for (final l in [fr, ar, en]) {
          expect(qrAdvice(l, a), expected(l), reason: '${l.localeName} $raw');
        }
      });
    }

    test('textes demandés, en trois langues', () {
      expect(
        fr.adviceApp,
        "N'installez pas cette application. Téléchargez vos applis "
        'uniquement depuis le Play Store.',
      );
      expect(
        fr.adviceContact,
        "Vérifiez ce numéro sur le site officiel avant de l'appeler.",
      );
      expect(fr.adviceMessaging, contains('code'));
      expect(fr.adviceCrypto, contains('crypto'));
      for (final l in [ar, en]) {
        for (final text in [
          l.adviceApp,
          l.adviceMessaging,
          l.adviceContact,
          l.adviceCrypto,
        ]) {
          expect(text, isNotEmpty);
          expect(text, isNot(contains("N'installez")));
        }
      }
    });
  });

  group('écran de résultat', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel('com.iheb.sentinel/qr'),
        (call) async => null,
      ),
    );

    Future<DomainCheck?> lists(String host) async => _unknown;

    Future<void> show(WidgetTester tester, String raw, Locale locale) async {
      tester.view.physicalSize = const Size(1080, 4000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(
          locale: locale,
          home: QrResultScreen(raw: raw, checkDomain: lists),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final (locale, l) in [
      (const Locale('fr'), fr),
      (const Locale('ar'), ar),
    ]) {
      testWidgets('.apk : pas de « absent des listes », conseil appli '
          '(${locale.languageCode})', (tester) async {
        await show(tester, 'https://exemple.tn/WhatsApp-Gold.apk', locale);
        expect(find.text(l.verdictDangerous), findsOneWidget);
        expect(find.text(l.linkNoteNotListed), findsNothing);
        expect(find.text(l.adviceApp), findsOneWidget);
        expect(find.text(l.adviceDangerous), findsNothing);
      });

      testWidgets('lien sain : information neutre, icône info grise '
          '(${locale.languageCode})', (tester) async {
        await show(tester, 'https://www.exemple.tn', locale);
        expect(find.text(l.verdictNothingKnown), findsOneWidget);
        final note = find.text(l.linkNoteNotListed);
        expect(note, findsOneWidget);
        final c = tester.element(note).colors;
        expect(tester.widget<Text>(note).style?.color, c.secondaire);
        final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
        expect(icon.color, c.secondaire);
        // Jamais avec l'icône rouge de danger.
        expect(find.byIcon(StatusLevel.danger.icon), findsNothing);
      });

      testWidgets('crypto : conseil crypto (${locale.languageCode})', (
        tester,
      ) async {
        await show(tester, 'bitcoin:bc1qxyz?amount=1', locale);
        expect(find.text(l.adviceCrypto), findsOneWidget);
        expect(find.text(l.adviceSuspect), findsNothing);
      });
    }
  });
}
