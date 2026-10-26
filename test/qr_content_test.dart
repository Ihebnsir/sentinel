import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/models/wifi_status.dart';
import 'package:sentinel/services/qr/qr_content.dart';

void main() {
  group('liens', () {
    test('http et https : lien seul', () {
      final c = parseQr('  https://www.exemple.tn/promo?id=3  ');
      expect(c, isA<QrLink>());
      expect((c as QrLink).url, 'https://www.exemple.tn/promo?id=3');
      expect(c.raw, '  https://www.exemple.tn/promo?id=3  '); // brut gardé
      expect(parseQr('HTTP://EXEMPLE.COM'), isA<QrLink>());
    });

    test('lien suivi de texte, ou sans site : texte à analyser', () {
      expect(parseQr('https://exemple.com Scannez-moi'), isA<QrText>());
      expect(parseQr('https://'), isA<QrText>());
      expect(parseQr('www.exemple.com'), isA<QrText>());
    });

    test('types dangereux reconnus, quelle que soit la casse', () {
      for (final (raw, scheme) in [
        ('javascript:alert(1)', 'javascript'),
        ('JavaScript:alert(1)', 'javascript'),
        ('intent://scan/#Intent;scheme=x;end', 'intent'),
        ('file:///sdcard/Download/a.apk', 'file'),
        ('data:text/html,<script>', 'data'),
        ('content://com.exemple/fichier', 'content'),
      ]) {
        final c = parseQr(raw);
        expect(c, isA<QrUnsafeLink>(), reason: raw);
        expect((c as QrUnsafeLink).scheme, scheme);
      }
    });
  });

  group('Wi-Fi', () {
    QrWifi wifi(String raw) => parseQr(raw) as QrWifi;

    test('WPA avec mot de passe', () {
      final w = wifi('WIFI:T:WPA;S:Maison;P:secret123;;');
      expect(w.ssid, 'Maison');
      expect(w.security, WifiSecurity.wpa2); // « WPA » = WPA ou WPA2
      expect(w.hasPassword, isTrue);
      expect(w.hidden, isFalse);
    });

    test('ordre libre, minuscules, réseau masqué', () {
      final w = wifi('wifi:S:Bureau;H:true;T:SAE;P:x;;');
      expect(w.ssid, 'Bureau');
      expect(w.security, WifiSecurity.wpa3);
      expect(w.hidden, isTrue);
    });

    test('caractères protégés par \\', () {
      final w = wifi(r'WIFI:S:Café\;Wi\:Fi\\1;T:WPA;P:a\,b;;');
      expect(w.ssid, r'Café;Wi:Fi\1');
      expect(w.hasPassword, isTrue);
    });

    test('réseau ouvert : nopass, ou ni type ni mot de passe', () {
      expect(wifi('WIFI:T:nopass;S:Gare;;').security, WifiSecurity.open);
      expect(wifi('WIFI:S:Gare;;').security, WifiSecurity.open);
      expect(wifi('WIFI:S:Gare;;').hasPassword, isFalse);
    });

    test('WEP, entreprise, type inconnu', () {
      expect(wifi('WIFI:T:WEP;S:Vieux;P:12345;;').security, WifiSecurity.wep);
      expect(
        wifi('WIFI:T:WPA2-EAP;S:Fac;E:PEAP;I:moi;P:x;;').security,
        WifiSecurity.enterprise,
      );
      expect(wifi('WIFI:T:WAPI;S:X;P:y;;').security, WifiSecurity.unknown);
    });

    test('sans nom de réseau : texte', () {
      expect(parseQr('WIFI:T:WPA;P:secret;;'), isA<QrText>());
      expect(parseQr('WIFI:'), isA<QrText>());
    });
  });

  group('téléphone et SMS', () {
    test('tel:', () {
      final c = parseQr('tel:+216%2071%20123%20456') as QrPhone;
      expect(c.number, '+216 71 123 456');
      expect((parseQr('TEL:*#06#') as QrPhone).number, '*#06#');
      expect(parseQr('tel:'), isA<QrText>());
    });

    test('SMSTO:numéro:texte', () {
      final c = parseQr('SMSTO:85000:STOP abonnement') as QrSms;
      expect(c.number, '85000');
      expect(c.body, 'STOP abonnement');
    });

    test('sms:numéro?body=texte (encodé)', () {
      final c = parseQr('sms:+21698000000?body=Code%20:%201234+merci') as QrSms;
      expect(c.number, '+21698000000');
      expect(c.body, 'Code : 1234 merci');
    });

    test('sms sans texte ; sans numéro : texte', () {
      expect((parseQr('sms:12345') as QrSms).body, '');
      expect(parseQr('smsto:'), isA<QrText>());
    });

    test('encodage abîmé : gardé tel quel, sans exception', () {
      expect((parseQr('tel:12%zz') as QrPhone).number, '12%zz');
    });
  });

  group('paiements', () {
    test('bitcoin avec montant', () {
      final p = parseQr(
        'bitcoin:bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh?amount=0.01',
      ) as QrPayment;
      expect(p.kind, PaymentKind.crypto);
      expect(p.recipient, 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh');
      expect(p.amount, '0.01');
      expect(p.currency, 'BTC');
      expect(p.uri, startsWith('bitcoin:'));
    });

    test('UPI : nom et adresse', () {
      final p = parseQr(
        'upi://pay?pa=marchand@banque&pn=Epicerie%20Ali&am=250',
      ) as QrPayment;
      expect(p.kind, PaymentKind.upi);
      expect(p.recipient, 'Epicerie Ali (marchand@banque)');
      expect(p.amount, '250');
      expect(parseQr('upi://pay?am=10'), isA<QrText>()); // sans bénéficiaire
    });

    test('virement SEPA (EPC) : nom, IBAN, montant ; pas de lien', () {
      final p = parseQr(
        'BCD\n002\n1\nSCT\nBNPAFRPP\nAssociation X\n'
        'FR76 3000 6000 0112 3456 7890 189\nEUR12.50\n\n\nDon',
      ) as QrPayment;
      expect(p.kind, PaymentKind.sepa);
      expect(p.recipient, 'Association X (FR7630006000011234567890189)');
      expect(p.amount, '12.50');
      expect(p.currency, 'EUR');
      expect(p.uri, isNull);
    });

    test('QR EMVCo : commerçant, montant, devise', () {
      // 00 format, 53 devise (788 = TND), 54 montant, 59 nom, 63 contrôle.
      const emv =
          '000201010212530378854041.50'
          '5908Boutique6304ABCD';
      final p = parseQr(emv) as QrPayment;
      expect(p.kind, PaymentKind.emv);
      expect(p.recipient, 'Boutique');
      expect(p.amount, '1.50');
      expect(p.currency, 'TND');
    });

    test('EMVCo abîmé ou EPC incomplet : texte', () {
      expect(parseQr('000201015'), isA<QrText>());
      expect(parseQr('BCD\n002\n1\nSCT'), isA<QrText>());
    });
  });

  test('texte libre, e-mail, vide : texte', () {
    expect(parseQr('Votre colis est bloqué, payez 2 DT'), isA<QrText>());
    expect(parseQr('mailto:contact@exemple.tn'), isA<QrText>());
    expect(parseQr(''), isA<QrText>());
    expect(parseQr('   '), isA<QrText>());
  });
}
