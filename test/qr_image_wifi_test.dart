import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentinel/screens/links_screen.dart';
import 'package:sentinel/screens/qr_result_screen.dart';
import 'package:sentinel/screens/wifi_share_screen.dart';
import 'package:sentinel/services/links/link_checker.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/qr/qr_scanner_service.dart';
import 'package:sentinel/services/share_service.dart';
import 'package:sentinel/widgets/qr_code_view.dart';
import 'package:sentinel/widgets/ui.dart';

import 'support/l10n.dart';

// Scanner 1.2.0 : nouveaux formats à l'écran (français et arabe), QR depuis
// une image (choisie ou partagée), conseil « quishing », « Partager mon
// Wi-Fi ». Des faux canaux jouent QrScanner.kt et VaultProtection.kt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKnownBrands);

  const qr = MethodChannel('com.iheb.sentinel/qr');
  const vault = MethodChannel('com.iheb.sentinel/vault');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late List<MethodCall> vaultCalls;
  Object? Function(MethodCall call) answer = (_) => null;

  setUp(() {
    calls = [];
    vaultCalls = [];
    answer = (_) => null;
    messenger.setMockMethodCallHandler(qr, (call) async {
      calls.add(call);
      return answer(call);
    });
    messenger.setMockMethodCallHandler(vault, (call) async {
      vaultCalls.add(call);
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(qr, null);
    messenger.setMockMethodCallHandler(vault, null);
  });

  Future<DomainCheck?> lists(String host) async =>
      const DomainCheck(allowed: false, dangerous: false);

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4000);
    addTearDown(tester.view.reset);
  }

  Future<void> showResult(
    WidgetTester tester,
    String raw, {
    Locale locale = const Locale('fr'),
    bool fromCamera = false,
    int? tipIndex,
  }) async {
    tallScreen(tester);
    await tester.pumpWidget(
      testApp(
        locale: locale,
        home: QrResultScreen(
          key: ValueKey(raw),
          raw: raw,
          checkDomain: lists,
          fromCamera: fromCamera,
          tipIndex: tipIndex,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('nouveaux formats à l\'écran', () {
    testWidgets('wa.me : app, numéro, indicatif en évidence, message', (
      tester,
    ) async {
      await showResult(
        tester,
        'https://wa.me/21698123456?text=${Uri.encodeComponent('Envoie-moi le code')}',
      );
      expect(find.text(fr.qrKindMessaging), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text(fr.qrTargetPerson), findsOneWidget);
      expect(find.text('+21698123456'), findsOneWidget);
      expect(
        find.widgetWithText(StatusBadge, '+216 · ${fr.qrZoneHome}'),
        findsOneWidget,
      );
      expect(find.text('Envoie-moi le code'), findsOneWidget);
      expect(find.text(fr.verdictSuspect), findsOneWidget);
      expect(find.textContaining('« envoie moi »'), findsOneWidget);

      // Ouvrir dans WhatsApp : confirmation, puis le lien https seulement.
      await tester.tap(find.text(fr.qrActionOpenAnyway));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.text(fr.commonContinue));
      await tester.pumpAndSettle();
      expect(calls.single.method, 'openLink');
      expect(
        (calls.single.arguments as Map)['url'],
        startsWith('https://wa.me/21698123456'),
      );
    });

    testWidgets('numéro d\'un pays inattendu : badge d\'avertissement', (
      tester,
    ) async {
      await showResult(tester, 'https://wa.me/6281234567890');
      final badge = tester.widget<StatusBadge>(
        find.widgetWithText(StatusBadge, '+62 · ${fr.qrZoneForeign}'),
      );
      expect(badge.level, StatusLevel.warning);
      expect(find.text(fr.qrWarningUnexpectedCountry('+62')), findsOneWidget);
    });

    testWidgets('groupe WhatsApp : invitation expliquée', (tester) async {
      await showResult(tester, 'https://chat.whatsapp.com/AbCdEf123');
      expect(find.text(fr.qrTargetGroup), findsOneWidget);
      expect(find.text(fr.qrWarningGroup), findsOneWidget);
    });

    testWidgets('.apk direct : Dangereux, explication, bouton désactivé', (
      tester,
    ) async {
      await showResult(tester, 'https://exemple.tn/WhatsApp-Gold.apk');
      expect(find.text(fr.qrKindApp), findsOneWidget);
      expect(find.text(fr.qrAppSourceApk), findsOneWidget);
      expect(find.text(fr.verdictDangerous), findsOneWidget);
      expect(find.text(fr.qrWarningApk), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, fr.qrActionOpenAnyway),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('market:// faux paquet : identifiant affiché, aucune action', (
      tester,
    ) async {
      await showResult(tester, 'market://details?id=com.whatsap.messenger');
      expect(find.text('com.whatsap.messenger'), findsOneWidget);
      expect(find.text('Google Play'), findsOneWidget);
      expect(
        find.text(fr.qrWarningPackageImitation('WhatsApp (com.whatsapp)')),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('vCard « Service client BIAT » : nom, numéro, alerte', (
      tester,
    ) async {
      await showResult(
        tester,
        'BEGIN:VCARD\nFN:Service client BIAT\nTEL:+21698000111\nEMAIL:aide@biat-tn.com\nEND:VCARD',
      );
      expect(find.text(fr.qrKindContact), findsOneWidget);
      expect(find.text('Service client BIAT'), findsOneWidget);
      expect(find.text('aide@biat-tn.com'), findsOneWidget);
      expect(find.text(fr.qrWarningContactBrand('BIAT')), findsOneWidget);
      expect(find.text(fr.verdictSuspect), findsOneWidget);
    });

    testWidgets('crypto, e-mail, carte, calendrier', (tester) async {
      await showResult(tester, 'bitcoin:bc1qxyz?amount=0.5');
      expect(find.text(fr.qrKindCrypto), findsOneWidget);
      expect(find.text(fr.qrWarningCrypto), findsOneWidget);

      await showResult(tester, 'mailto:a@exemple.tn?subject=Bonjour');
      expect(find.text(fr.qrKindEmail), findsOneWidget);
      expect(find.text('Bonjour'), findsOneWidget);

      await showResult(tester, 'geo:36.8,10.18?q=Tunis');
      expect(find.text(fr.qrKindGeo), findsOneWidget);
      expect(find.text('36.8, 10.18'), findsOneWidget);

      await showResult(
        tester,
        'BEGIN:VEVENT\nSUMMARY:Atelier\nDTSTART:20261201T180000\nEND:VEVENT',
      );
      expect(find.text(fr.qrKindEvent), findsOneWidget);
      expect(find.text('2026-12-01 18:00'), findsOneWidget);
    });

    testWidgets('contenu énorme : affiché tronqué, sans erreur', (
      tester,
    ) async {
      await showResult(tester, 'x' * 50000);
      expect(tester.takeException(), isNull);
      expect(find.text(fr.qrKindText), findsOneWidget);
    });

    for (final raw in [
      'https://wa.me/21698123456?text=${Uri.encodeComponent('ابعثلي الكود')}',
      'BEGIN:VCARD\nFN:Service client BIAT\nTEL:+21698000111\nEND:VCARD',
      'https://exemple.tn/app.apk',
    ]) {
      testWidgets('arabe, droite à gauche : ${raw.substring(0, 12)}…', (
        tester,
      ) async {
        await showResult(tester, raw, locale: const Locale('ar'));
        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(ListView));
        expect(Directionality.of(context), TextDirection.rtl);
        expect(find.text(ar.qrResultTitle), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data ?? '').contains(RegExp('[\u{0600}-\u{06FF}]')),
          ),
          findsWidgets,
        );
      });
    }

    testWidgets('arabe : indicatif et message pré-rempli lisibles', (
      tester,
    ) async {
      await showResult(
        tester,
        'https://wa.me/21698123456?text=${Uri.encodeComponent('ابعثلي الكود')}',
        locale: const Locale('ar'),
      );
      expect(find.text(ar.qrKindMessaging), findsOneWidget);
      expect(find.text('+216 · ${ar.qrZoneHome}'), findsOneWidget);
      expect(find.text('ابعثلي الكود'), findsOneWidget);
      expect(find.text(ar.verdictSuspect), findsOneWidget);
    });
  });

  group('conseil « quishing »', () {
    testWidgets('après un scan caméra seulement', (tester) async {
      await showResult(
        tester,
        'https://www.exemple.tn',
        fromCamera: true,
        tipIndex: 0,
      );
      expect(find.text(fr.qrTipPoster), findsOneWidget);
      await showResult(tester, 'https://www.exemple.tn');
      for (final tip in quishingTips(fr)) {
        expect(find.text(tip), findsNothing);
      }
    });

    testWidgets('change d\'un scan à l\'autre', (tester) async {
      await showResult(
        tester,
        'https://www.exemple.tn',
        fromCamera: true,
        tipIndex: 1,
      );
      expect(find.text(fr.qrTipSmsCode), findsOneWidget);
      await showResult(
        tester,
        'https://www.exemple.tn',
        fromCamera: true,
        tipIndex: 5,
      );
      expect(find.text(fr.qrTipSmsCode), findsOneWidget); // 5 % 4 = 1
      expect(quishingTips(fr).toSet(), hasLength(4));
      expect(quishingTips(ar).toSet(), hasLength(4));
    });
  });

  group('QR depuis une image', () {
    Future<void> showLinks(
      WidgetTester tester, {
      ValueListenable<QrImageResult?>? shared,
      Locale locale = const Locale('fr'),
    }) async {
      tallScreen(tester);
      await tester.pumpWidget(
        testApp(
          locale: locale,
          home: Scaffold(
            body: LinksScreen(checkDomain: lists, sharedImage: shared),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester, Object? result) async {
      answer = (call) => call.method == 'pickImage' ? result : null;
      await tester.tap(find.text(fr.qrImageButton));
      await tester.pumpAndSettle();
    }

    testWidgets('un seul QR : son résultat, rien d\'ouvert', (tester) async {
      await showLinks(tester);
      await pick(tester, {
        'codes': ['https://wa.me/21698123456'],
      });
      expect(calls.single.method, 'pickImage');
      expect(find.byType(QrResultScreen), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      // Pas de conseil caméra pour une image.
      expect(find.text(fr.qrTipPoster), findsNothing);
    });

    testWidgets('plusieurs QR : liste, puis le choisi', (tester) async {
      await showLinks(tester);
      await pick(tester, {
        'codes': [
          'https://t.me/sentinel_tn',
          'WIFI:T:WPA;S:Maison;P:motdepasse123;;',
        ],
      });
      expect(find.byType(QrChoiceScreen), findsOneWidget);
      expect(find.text(fr.qrImageChooseTitle), findsOneWidget);
      expect(find.text(fr.qrKindMessaging), findsOneWidget);
      expect(find.text(fr.qrKindWifi), findsOneWidget);
      await tester.tap(find.text(fr.qrKindWifi));
      await tester.pumpAndSettle();
      expect(find.byType(QrResultScreen), findsOneWidget);
      expect(find.text('Maison'), findsOneWidget);
    });

    testWidgets('aucun QR : message clair', (tester) async {
      await showLinks(tester);
      await pick(tester, {'codes': <String>[]});
      expect(find.text(fr.qrImageNoQr), findsOneWidget);
      expect(find.byType(QrResultScreen), findsNothing);
    });

    testWidgets('image trop grande ou illisible : message', (tester) async {
      await showLinks(tester);
      await pick(tester, {'error': 'TOO_LARGE'});
      expect(find.text(fr.qrImageTooLarge), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await pick(tester, {'error': 'FAILED'});
      expect(find.text(fr.qrImageFailed), findsOneWidget);
    });

    testWidgets('sélecteur fermé : rien ne se passe', (tester) async {
      await showLinks(tester);
      await pick(tester, null);
      expect(find.byType(QrResultScreen), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('image partagée vers Sentinel : résultat affiché', (
      tester,
    ) async {
      final shared = ValueNotifier<QrImageResult?>(null);
      addTearDown(shared.dispose);
      await showLinks(tester, shared: shared);
      shared.value = QrImageResult.fromNative({
        'codes': ['https://exemple.tn/app.apk'],
      });
      await tester.pumpAndSettle();
      expect(find.byType(QrResultScreen), findsOneWidget);
      expect(find.text(fr.qrWarningApk), findsOneWidget);
    });

    testWidgets('arabe : lignes QR sans débordement', (tester) async {
      await showLinks(tester, locale: const Locale('ar'));
      expect(tester.takeException(), isNull);
      expect(find.text(ar.qrImageButton), findsOneWidget);
      expect(find.text(ar.qrWifiShareButton), findsOneWidget);
    });

    test('réponses inattendues de Kotlin', () {
      expect(QrImageResult.fromNative(null).codes, isNull);
      expect(QrImageResult.fromNative('x').error, QrImageError.failed);
      expect(
        QrImageResult.fromNative({
          'codes': [1, 'a'],
        }).codes,
        ['a'],
      );
      expect(
        QrImageResult.fromNative({'error': 'NOPE'}).error,
        QrImageError.failed,
      );
    });
  });

  group('Partager mon Wi-Fi', () {
    final modules = Uint8List(21 * 21)..[0] = 1;

    Future<void> showWifi(
      WidgetTester tester, {
      Locale locale = const Locale('fr'),
    }) async {
      tallScreen(tester);
      answer = (call) =>
          call.method == 'encodeQr' ? {'size': 21, 'modules': modules} : null;
      await tester.pumpWidget(
        testApp(
          locale: locale,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WifiShareScreen(),
                    ),
                  ),
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
    }

    Finder field(String label) => find.widgetWithText(TextField, label);

    testWidgets('écran protégé, QR créé, tout effacé en quittant', (
      tester,
    ) async {
      await showWifi(tester);
      expect(vaultCalls.single.method, 'setSecure');
      expect(vaultCalls.single.arguments, {'secure': true});

      // Mot de passe trop court : message, rien de créé.
      await tester.enterText(field(fr.qrWifiShareName), 'Maison;Ben Ali');
      await tester.enterText(field(fr.qrWifiSharePassword), 'court');
      await tester.tap(find.text(fr.qrWifiShareCreate));
      await tester.pumpAndSettle();
      expect(find.text(fr.qrWifiShareErrorWpa), findsOneWidget);
      expect(calls, isEmpty);

      await tester.enterText(field(fr.qrWifiSharePassword), 'motdepasse123');
      await tester.tap(find.text(fr.qrWifiShareCreate));
      await tester.pumpAndSettle();
      expect(calls.single.method, 'encodeQr');
      expect(calls.single.arguments, {
        'text': r'WIFI:T:WPA;S:Maison\;Ben Ali;P:motdepasse123;;',
      });
      expect(find.byType(QrCodeView), findsOneWidget);
      expect(find.text(fr.qrWifiShareShow), findsOneWidget);
      expect(find.text('motdepasse123'), findsNothing); // jamais affiché

      // Retour : protection levée ; rouvrir donne un écran vide.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(vaultCalls.last.arguments, {'secure': false});
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Maison;Ben Ali'), findsNothing);
      expect(find.byType(QrCodeView), findsNothing);
    });

    testWidgets('sans mot de passe : champ masqué, QR nopass', (tester) async {
      await showWifi(tester);
      await tester.tap(find.text(fr.qrWifiShareSecurityNone));
      await tester.pumpAndSettle();
      expect(field(fr.qrWifiSharePassword), findsNothing);
      await tester.enterText(field(fr.qrWifiShareName), 'Café');
      await tester.tap(find.text(fr.qrWifiShareHidden));
      await tester.tap(find.text(fr.qrWifiShareCreate));
      await tester.pumpAndSettle();
      expect(calls.single.arguments, {'text': 'WIFI:T:nopass;S:Café;H:true;;'});
    });

    testWidgets('nom manquant, échec de création', (tester) async {
      await showWifi(tester);
      await tester.tap(find.text(fr.qrWifiShareCreate));
      await tester.pumpAndSettle();
      expect(find.text(fr.qrWifiShareErrorName), findsOneWidget);

      answer = (_) => null; // Kotlin ne renvoie rien
      await tester.enterText(field(fr.qrWifiShareName), 'Maison');
      await tester.enterText(field(fr.qrWifiSharePassword), 'motdepasse123');
      await tester.tap(find.text(fr.qrWifiShareCreate));
      await tester.pumpAndSettle();
      expect(find.text(fr.qrWifiShareFailed), findsOneWidget);
    });

    testWidgets('arabe, droite à gauche, sans débordement', (tester) async {
      await showWifi(tester, locale: const Locale('ar'));
      expect(tester.takeException(), isNull);
      expect(find.text(ar.qrWifiShareCreate), findsOneWidget);
      await tester.enterText(field(ar.qrWifiShareName), 'بيت');
      await tester.enterText(field(ar.qrWifiSharePassword), 'motdepasse123');
      await tester.tap(find.text(ar.qrWifiShareCreate));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(QrCodeView), findsOneWidget);
    });
  });

  group('image partagée (ShareService)', () {
    const share = MethodChannel('com.iheb.sentinel/share');
    tearDown(() => messenger.setMockMethodCallHandler(share, null));

    test('au lancement puis app ouverte', () async {
      messenger.setMockMethodCallHandler(share, (call) async {
        if (call.method == 'getInitialSharedImage') {
          return {
            'codes': ['https://t.me/a'],
          };
        }
        return null;
      });
      final service = ShareService();
      await service.start();
      expect(service.receivedImage.value?.codes, ['https://t.me/a']);

      await messenger.handlePlatformMessage(
        share.name,
        share.codec.encodeMethodCall(
          const MethodCall('onSharedImage', {'error': 'FAILED'}),
        ),
        (_) {},
      );
      expect(service.receivedImage.value?.error, QrImageError.failed);
      // Réponse inattendue (pas une Map) : ignorée.
      await messenger.handlePlatformMessage(
        share.name,
        share.codec.encodeMethodCall(const MethodCall('onSharedImage', 'x')),
        (_) {},
      );
      expect(service.receivedImage.value?.error, QrImageError.failed);
      service.dispose();
    });
  });

  test('manifeste : aucune permission sensible ajoutée par le scanner', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    final permissions = {
      for (final m in RegExp(
        r'<uses-permission[^>]*android:name="([^"]+)"',
      ).allMatches(manifest))
        m[1]!.replaceFirst('android.permission.', ''),
    };
    expect(permissions, {
      'USE_BIOMETRIC',
      'QUERY_ALL_PACKAGES',
      'PACKAGE_USAGE_STATS',
      'REQUEST_DELETE_PACKAGES',
      'POST_NOTIFICATIONS',
      'ACCESS_NETWORK_STATE',
      'INTERNET',
      'FOREGROUND_SERVICE',
      'FOREGROUND_SERVICE_SYSTEM_EXEMPTED',
      'SCHEDULE_EXACT_ALARM',
      'RECEIVE_BOOT_COMPLETED',
      'CAMERA',
    });
    // Image partagée ou choisie : jamais de permission de stockage.
    expect(manifest, isNot(contains('READ_MEDIA')));
    expect(manifest, isNot(contains('EXTERNAL_STORAGE')));
    expect(manifest, contains('android:mimeType="image/*"'));
  });
}
