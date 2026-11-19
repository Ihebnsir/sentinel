import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/screens/links_screen.dart';
import 'package:sentinel/services/links/link_checker.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/share_service.dart';

import 'support/l10n.dart';

// Onglet Liens : collage, partage, verdict, ouverture jamais automatique,
// état du pare-feu. Des faux canaux jouent Android (QrScanner.kt,
// FirewallChannel.kt).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKnownBrands);

  const qr = MethodChannel('com.iheb.sentinel/qr');
  const firewall = MethodChannel('com.iheb.sentinel/firewall');
  const notifications = MethodChannel('com.iheb.sentinel/notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(qr, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() {
    for (final c in [qr, firewall, notifications]) {
      messenger.setMockMethodCallHandler(c, null);
    }
  });

  // Fausses listes : seul « colis-tn.example » est dans la liste Malware.
  final asked = <String>[];
  Future<DomainCheck?> lists(String host) async {
    asked.add(host);
    return DomainCheck(allowed: false, dangerous: host == 'colis-tn.example');
  }

  Future<void> show(
    WidgetTester tester, {
    Locale locale = const Locale('fr'),
    ValueListenable<SharedText?>? shared,
  }) async {
    tester.view.physicalSize = const Size(1080, 4000);
    addTearDown(tester.view.reset);
    asked.clear();
    await tester.pumpWidget(
      testApp(
        locale: locale,
        home: Scaffold(
          body: LinksScreen(checkDomain: lists, sharedText: shared),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> check(WidgetTester tester, String text, {String? button}) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.text(button ?? fr.linksCheck));
    await tester.pumpAndSettle();
  }

  OutlinedButton openButton(WidgetTester tester, String label) =>
      tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label));

  testWidgets(
    'vrai site : Aucun problème connu, ouverture après confirmation',
    (tester) async {
      await show(tester);
      await check(tester, 'Mon relevé : https://www.biat.com.tn/espace');
      expect(asked, ['www.biat.com.tn']);
      expect(find.text(fr.verdictNothingKnown), findsOneWidget);
      expect(
        find.text(fr.linksRealDestination('biat[.]com[.]tn')),
        findsOneWidget,
      );
      expect(find.text(fr.linkReasonNotListed), findsOneWidget);
      // Rien ne s'ouvre tout seul.
      expect(calls, isEmpty);

      await tester.tap(find.text(fr.qrActionOpenLink));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.commonCancel));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);

      await tester.tap(find.text(fr.qrActionOpenLink));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.commonContinue));
      await tester.pumpAndSettle();
      expect(calls.single.method, 'openLink');
      expect(calls.single.arguments, {'url': 'https://www.biat.com.tn/espace'});
    },
  );

  testWidgets('liste Malware : Dangereux, « Ouvrir quand même » désactivé', (
    tester,
  ) async {
    await show(tester);
    await check(tester, 'https://colis-tn.example/payer');
    expect(find.text(fr.verdictDangerous), findsOneWidget);
    expect(find.text(fr.linkReasonListed('colis-tn.example')), findsOneWidget);
    expect(find.text(fr.adviceDangerous), findsOneWidget);
    expect(openButton(tester, fr.qrActionOpenAnyway).onPressed, isNull);
    expect(find.text(fr.linksOpenBlocked), findsOneWidget);
    await tester.tap(find.text(fr.qrActionOpenAnyway));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(calls, isEmpty);
  });

  testWidgets('raccourcisseur : Suspect, expliqué sans connexion', (
    tester,
  ) async {
    await show(tester);
    await check(tester, 'Colis en attente : bit.ly/3xYz');
    expect(find.text(fr.verdictSuspect), findsOneWidget);
    expect(find.text(fr.reasonLinkShortener('bit.ly')), findsOneWidget);
    expect(find.text(fr.linksShortenerHelp), findsOneWidget);
    expect(openButton(tester, fr.qrActionOpenAnyway).onPressed, isNotNull);
    expect(calls, isEmpty); // aucune requête pour suivre le lien
  });

  testWidgets('texte sans lien : « Aucun lien trouvé »', (tester) async {
    await show(tester);
    await check(tester, 'Rendez-vous demain à 9h');
    expect(find.text(fr.linksNoLink), findsOneWidget);
    expect(asked, isEmpty);
  });

  testWidgets('lien partagé depuis une autre app : vérifié tout seul', (
    tester,
  ) async {
    final shared = ValueNotifier<SharedText?>(null);
    addTearDown(shared.dispose);
    await show(tester, shared: shared);
    shared.value = const SharedText(
      'Votre colis est bloqué : https://poste-tn-livraison.xyz/p',
    );
    await tester.pumpAndSettle();
    expect(find.text(fr.verdictDangerous), findsOneWidget);
    expect(
      find.text(fr.linksRealDestination('poste-tn-livraison[.]xyz')),
      findsOneWidget,
    );

    shared.value = const SharedText('Merci pour hier !');
    await tester.pumpAndSettle();
    expect(find.text(fr.linksNoLink), findsOneWidget);
    expect(find.text(fr.verdictDangerous), findsNothing);
  });

  testWidgets('Coller : texte du presse-papiers dans le champ', (tester) async {
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return {'text': 'www.cnss.tn'};
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await show(tester);
    await tester.tap(find.text(fr.linksPaste));
    await tester.pumpAndSettle();
    expect(find.text('www.cnss.tn'), findsOneWidget);
    await tester.tap(find.text(fr.linksCheck));
    await tester.pumpAndSettle();
    expect(find.text(fr.verdictNothingKnown), findsOneWidget);
  });

  testWidgets('arabe : de droite à gauche, lien de gauche à droite', (
    tester,
  ) async {
    await show(tester, locale: const Locale('ar'));
    expect(find.text(ar.navLinks), findsOneWidget);
    await check(
      tester,
      'طردك محجوز، ادفع هنا: https://poste-tn.xyz/p',
      button: ar.linksCheck,
    );
    expect(
      Directionality.of(tester.element(find.byType(TextField))),
      TextDirection.rtl,
    );
    expect(find.text(ar.verdictDangerous), findsOneWidget);
    expect(
      find.text(ar.linksRealDestination('poste-tn[.]xyz')),
      findsOneWidget,
    );
    expect(find.text(ar.adviceDangerous), findsOneWidget);
    // L'adresse affichée garde son sens de lecture.
    final url = tester.widget<Text>(find.text('https://poste-tn.xyz/p'));
    expect(url.textDirection, TextDirection.ltr);
    expect(find.text(fr.verdictDangerous), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('protection automatique (pare-feu)', () {
    void firewallAndroid(bool active) {
      messenger.setMockMethodCallHandler(firewall, (call) async {
        calls.add(call);
        return switch (call.method) {
          'status' => {'active': active},
          'prepare' => true,
          _ => null,
        };
      });
      messenger.setMockMethodCallHandler(notifications, (call) async {
        calls.add(call);
        return true;
      });
    }

    testWidgets('arrêté : « Activer » démarre le pare-feu en un appui', (
      tester,
    ) async {
      firewallAndroid(false);
      await show(tester);
      expect(find.text(fr.linksAutoTitle), findsOneWidget);
      expect(find.text(fr.linksAutoOff), findsOneWidget);
      await tester.tap(find.text(fr.linksAutoEnable));
      await tester.pumpAndSettle();
      expect([
        for (final c in calls) c.method,
      ], containsAllInOrder(['prepare', 'requestPermission', 'start']));
    });

    testWidgets('actif : état affiché, pas de bouton', (tester) async {
      firewallAndroid(true);
      await show(tester);
      expect(find.text(fr.linksAutoOn), findsOneWidget);
      expect(find.text(fr.linksAutoEnable), findsNothing);
    });

    testWidgets('hors Android : ligne masquée', (tester) async {
      await show(tester);
      expect(find.text(fr.linksAutoTitle), findsNothing);
    });
  });
}
