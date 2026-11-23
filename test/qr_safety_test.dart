import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/links/link_checker.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/qr/qr_content.dart';
import 'package:sentinel/services/qr/qr_safety.dart';

import 'support/l10n.dart';

QrAssessment _assess(String raw, {DomainCheck? lists}) =>
    assessQr(parseQr(raw), lists: lists);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKnownBrands);

  group('liens', () {
    test('lien sain : ouvrable, après confirmation', () {
      final a = _assess('https://www.exemple.tn');
      expect(a.verdict, Verdict.rien);
      expect(a.action, QrAction.ouvrirLien);
      expect(a.actionAllowed, isTrue);
      expect(hostToCheck(parseQr('https://www.exemple.tn')), 'www.exemple.tn');
    });

    test('lien suspect (http) : ouvrable « quand même »', () {
      final a = _assess('http://www.exemple.tn');
      expect(a.verdict, Verdict.suspect);
      expect(a.actionAllowed, isTrue);
    });

    test('lien dangereux : bouton désactivé', () {
      // Adresse IP au lieu d'un nom de site.
      final ip = _assess('http://192.168.4.1/banque/login');
      expect(ip.verdict, Verdict.dangereux);
      expect(ip.action, QrAction.ouvrirLien);
      expect(ip.actionAllowed, isFalse);

      // Faux site d'une marque connue (« quishing » de colis).
      expect(_assess('https://poste-tn.com/suivi').actionAllowed, isFalse);

      // Domaine de la liste Malware du pare-feu.
      const listed = DomainCheck(allowed: false, dangerous: true);
      expect(
        _assess('https://exemple.tn', lists: listed).actionAllowed,
        isFalse,
      );
    });

    test('liste blanche : aucun problème connu', () {
      const allowed = DomainCheck(allowed: true, dangerous: false);
      final a = _assess('https://poste-tn.com/suivi', lists: allowed);
      expect(a.verdict, Verdict.rien);
      expect(a.actionAllowed, isTrue);
    });

    test('javascript:, intent: : dangereux, jamais d\'action', () {
      for (final raw in ['javascript:alert(1)', 'intent://x#Intent;end']) {
        final a = _assess(raw);
        expect(a.verdict, Verdict.dangereux, reason: raw);
        expect(a.warnings, [QrWarning.lienDangereux]);
        expect(a.action, isNull);
        expect(a.actionAllowed, isFalse);
        expect(hostToCheck(parseQr(raw)), isNull);
      }
    });
  });

  group('texte', () {
    test('le lien du texte est vérifié, sans action', () {
      final a = _assess('Colis bloqué : payez sur bit.ly/xyz');
      expect(a.verdict, Verdict.suspect); // raccourcisseur
      expect(a.link!.link.host, 'bit.ly');
      expect(a.action, isNull);
    });

    test('texte sans lien : rien à juger', () {
      final a = _assess('Bonjour, rendez-vous demain');
      expect(a.verdict, isNull);
      expect(a.link, isNull);
    });

    test('QR vide : rien à juger', () {
      final a = _assess('   ');
      expect(a.verdict, isNull);
      expect(a.link, isNull);
    });
  });

  group('Wi-Fi', () {
    test('réseau ouvert : alerte, niveau « danger » de wifi_risk', () {
      final a = _assess('WIFI:T:nopass;S:Gare;;');
      expect(a.warnings, [QrWarning.wifiOuvert]);
      expect(a.verdict, isNull); // pas un lien dangereux, un réseau risqué
      expect(a.action, isNull);
      expect(a.wifiStatus!.connected, isTrue);
      expect(a.link, isNull, reason: 'le nom du réseau n\'est pas vérifié');
    });

    test('WEP : alerte ; WPA2 et WPA3 : aucune', () {
      expect(_assess('WIFI:T:WEP;S:X;P:1;;').warnings, [QrWarning.wifiWep]);
      expect(_assess('WIFI:T:WPA;S:X;P:1;;').warnings, isEmpty);
      expect(_assess('WIFI:T:SAE;S:X;P:1;;').warnings, isEmpty);
    });
  });

  group('téléphone et SMS', () {
    test('numéro normal : appel proposé, sans verdict', () {
      final a = _assess('tel:+21671123456');
      expect(a.action, QrAction.appeler);
      expect(a.actionAllowed, isTrue);
      expect(a.verdict, isNull);
    });

    test('code USSD (* ou #) : dangereux, appel interdit', () {
      for (final raw in ['tel:*#06#', 'tel:*2767*3855%23', 'tel:%2321%23']) {
        final a = _assess(raw);
        expect(a.warnings, [QrWarning.codeUssd], reason: raw);
        expect(a.verdict, Verdict.dangereux);
        expect(a.actionAllowed, isFalse);
      }
    });

    test('SMS vers un numéro court : suspect, envoi possible', () {
      final a = _assess('SMSTO:85000:OUI');
      expect(a.warnings, [QrWarning.numeroCourt]);
      expect(a.verdict, Verdict.suspect);
      expect(a.action, QrAction.envoyerSms);
      expect(a.actionAllowed, isTrue);
    });

    test('SMS dont le texte contient un faux site : envoi interdit', () {
      final a = _assess('SMSTO:+21698000000:Suivez https://poste-tn.com');
      expect(a.verdict, Verdict.dangereux);
      expect(a.actionAllowed, isFalse);
    });

    test('SMS sans texte vers un numéro long : rien à signaler', () {
      final a = _assess('sms:+21698000000');
      expect(a.warnings, isEmpty);
      expect(a.verdict, isNull);
      expect(a.actionAllowed, isTrue);
    });

    test('numéros courts et codes', () {
      expect(isShortNumber('85 000'), isTrue);
      expect(isShortNumber('+216 98 000 000'), isFalse);
      expect(isShortNumber(''), isFalse);
      expect(isUssdCode('#31#0612'), isTrue);
      expect(isUssdCode('+21671123456'), isFalse);
    });
  });

  group('paiements', () {
    test('toujours un avertissement ; app proposée pour les liens', () {
      // Cryptomonnaie : avertissement propre (1.2.0), verdict « Suspect ».
      final btc = _assess('bitcoin:bc1qxyz?amount=1');
      expect(btc.warnings, [QrWarning.crypto]);
      expect(btc.action, QrAction.ouvrirPaiement);
      expect(btc.actionAllowed, isTrue);
    });

    test('virement SEPA ou EMVCo : rien à ouvrir', () {
      final sepa = _assess(
        'BCD\n002\n1\nSCT\n\nX\nFR7630006000011234567890189',
      );
      expect(sepa.warnings, [QrWarning.paiement]);
      expect(sepa.action, isNull);
    });
  });

  test('chaque avertissement a un texte, dans chaque langue', () {
    for (final l in [fr, en, ar]) {
      final texts = {for (final w in QrWarning.values) w.reason(l)};
      // paquetImite et paquetImiteStore partagent le même texte.
      expect(texts, hasLength(QrWarning.values.length - 1));
    }
  });
}
