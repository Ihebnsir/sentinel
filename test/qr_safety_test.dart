import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/phishing/message_analyzer.dart';
import 'package:sentinel/services/phishing/phishing_model.dart';
import 'package:sentinel/services/qr/qr_content.dart';
import 'package:sentinel/services/qr/qr_safety.dart';

import 'support/l10n.dart';

// Faux modèle : même probabilité pour tout texte, et note ce qu'il lit.
final _analyzed = <String>[];

PhishingPrediction Function(String) _ai(double p) => (text) {
  _analyzed.add(text);
  return PhishingPrediction(
    probability: p,
    suspiciousNgrams: const [],
    suspiciousWords: const [],
  );
};

QrAssessment _assess(String raw, {double p = 0.05}) =>
    assessQr(parseQr(raw), _ai(p));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKnownBrands);
  setUp(_analyzed.clear);

  group('liens', () {
    test('lien sain : ouvrable, après confirmation', () {
      final a = _assess('https://www.exemple.tn');
      expect(a.verdict, Verdict.rien);
      expect(a.action, QrAction.ouvrirLien);
      expect(a.actionAllowed, isTrue);
      expect(_analyzed, ['https://www.exemple.tn']);
    });

    test('lien suspect (http) : ouvrable « quand même »', () {
      final a = _assess('http://www.exemple.tn');
      expect(a.verdict, Verdict.suspect);
      expect(a.actionAllowed, isTrue);
    });

    test('arnaque probable : bouton désactivé', () {
      // Adresse IP au lieu d'un nom de site : arnaque pour l'analyseur.
      final ip = _assess('http://192.168.4.1/banque/login');
      expect(ip.verdict, Verdict.arnaque);
      expect(ip.action, QrAction.ouvrirLien);
      expect(ip.actionAllowed, isFalse);

      // Faux site d'une marque connue (« quishing » de colis).
      expect(_assess('https://poste-tn.com/suivi').actionAllowed, isFalse);

      // L'IA seule suffit aussi.
      expect(_assess('https://exemple.tn', p: 0.95).actionAllowed, isFalse);
    });

    test('javascript:, intent: : arnaque, jamais d\'action', () {
      for (final raw in ['javascript:alert(1)', 'intent://x#Intent;end']) {
        final a = _assess(raw);
        expect(a.verdict, Verdict.arnaque, reason: raw);
        expect(a.warnings, [QrWarning.lienDangereux]);
        expect(a.action, isNull);
        expect(a.actionAllowed, isFalse);
      }
      expect(_analyzed, isEmpty);
    });
  });

  group('texte', () {
    test('analysé comme un message, sans action', () {
      final a = _assess('Colis bloqué : payez sur bit.ly/xyz', p: 0.9);
      expect(a.verdict, Verdict.arnaque);
      expect(a.analysis, isNotNull);
      expect(a.action, isNull);
    });

    test('QR vide : rien à juger', () {
      final a = _assess('   ');
      expect(a.verdict, isNull);
      expect(a.analysis, isNull);
      expect(_analyzed, isEmpty);
    });
  });

  group('Wi-Fi', () {
    test('réseau ouvert : alerte, niveau « danger » de wifi_risk', () {
      final a = _assess('WIFI:T:nopass;S:Gare;;');
      expect(a.warnings, [QrWarning.wifiOuvert]);
      expect(a.verdict, isNull); // pas une arnaque, un réseau risqué
      expect(a.action, isNull);
      expect(a.wifiStatus!.connected, isTrue);
      expect(_analyzed, isEmpty, reason: 'le nom du réseau n\'est pas analysé');
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

    test('code USSD (* ou #) : arnaque, appel interdit', () {
      for (final raw in ['tel:*#06#', 'tel:*2767*3855%23', 'tel:%2321%23']) {
        final a = _assess(raw);
        expect(a.warnings, [QrWarning.codeUssd], reason: raw);
        expect(a.verdict, Verdict.arnaque);
        expect(a.actionAllowed, isFalse);
      }
    });

    test('SMS vers un numéro court : suspect, envoi possible', () {
      final a = _assess('SMSTO:85000:OUI');
      expect(a.warnings, [QrWarning.numeroCourt]);
      expect(a.verdict, Verdict.suspect);
      expect(a.action, QrAction.envoyerSms);
      expect(a.actionAllowed, isTrue);
      expect(_analyzed, ['OUI'], reason: 'le texte du SMS est analysé');
    });

    test('SMS dont le texte est une arnaque : envoi interdit', () {
      final a = _assess('SMSTO:+21698000000:Gagnez un iPhone', p: 0.9);
      expect(a.verdict, Verdict.arnaque);
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
      final btc = _assess('bitcoin:bc1qxyz?amount=1');
      expect(btc.warnings, [QrWarning.paiement]);
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
      expect(texts, hasLength(QrWarning.values.length));
    }
  });
}
