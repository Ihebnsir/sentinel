import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/models/wifi_status.dart';
import 'package:sentinel/services/wifi_risk.dart';
import 'support/l10n.dart';

// Wi-Fi connecté, DNS privé actif, Android 15 : seul le type change.
WifiReport _assess(
  WifiSecurity security, {
  bool portal = false,
  bool? dns = true,
  int sdk = 35,
}) => assessWifi(fr, 
  WifiStatus(
    connected: true,
    security: security,
    captivePortal: portal,
    privateDnsActive: dns,
    sdkInt: sdk,
  ),
);

void main() {
  group('type de sécurité', () {
    test('ouvert : danger, banque et données mobiles', () {
      final r = _assess(WifiSecurity.open);
      expect(r.level, WifiLevel.danger);
      expect(r.explanation, contains("n'est pas protégé"));
      expect(
        r.advice,
        contains('Évitez la banque et les achats sur ce réseau'),
      );
      expect(r.advice, contains('Utilisez plutôt les données mobiles'));
    });

    test('WEP : danger', () {
      expect(_assess(WifiSecurity.wep).level, WifiLevel.danger);
    });

    test('WPA : faible', () {
      expect(_assess(WifiSecurity.wpa).level, WifiLevel.faible);
    });

    test('OWE : faible (chiffré mais public)', () {
      expect(_assess(WifiSecurity.owe).level, WifiLevel.faible);
    });

    test('WPA2 : correct, sans conseil', () {
      final r = _assess(WifiSecurity.wpa2);
      expect(r.level, WifiLevel.correct);
      expect(r.advice, isEmpty);
    });

    test('WPA3 : excellent', () {
      expect(_assess(WifiSecurity.wpa3).level, WifiLevel.excellent);
    });

    test('Entreprise : excellent', () {
      expect(_assess(WifiSecurity.enterprise).level, WifiLevel.excellent);
    });

    test('inconnu : explication selon la version d\'Android', () {
      final ancien = _assess(WifiSecurity.unknown, sdk: 30);
      expect(ancien.level, WifiLevel.inconnu);
      expect(ancien.explanation, contains('localisation'));
      final recent = _assess(WifiSecurity.unknown, sdk: 34);
      expect(recent.explanation, isNot(contains('localisation')));
    });
  });

  group('portail captif', () {
    test('WPA3 + page de connexion : faible, Wi-Fi public', () {
      final r = _assess(WifiSecurity.wpa3, portal: true);
      expect(r.level, WifiLevel.faible);
      expect(r.title, 'Wi-Fi public');
      expect(
        r.advice,
        contains('Évitez la banque et les achats sur ce réseau'),
      );
    });

    test('ouvert + page de connexion : reste danger, conseil non doublé', () {
      final r = _assess(WifiSecurity.open, portal: true);
      expect(r.level, WifiLevel.danger);
      expect(r.title, 'Wi-Fi ouvert');
      final banque = r.advice.where((a) => a.contains('banque')).length;
      expect(banque, 1);
    });
  });

  group('DNS privé', () {
    test('désactivé : conseil + bouton, excellent devient correct', () {
      final r = _assess(WifiSecurity.wpa3, dns: false);
      expect(r.level, WifiLevel.correct);
      expect(r.suggestPrivateDns, isTrue);
      expect(r.advice.last, contains('DNS privé'));
    });

    test('désactivé sur un WPA2 : reste correct', () {
      final r = _assess(WifiSecurity.wpa2, dns: false);
      expect(r.level, WifiLevel.correct);
      expect(r.suggestPrivateDns, isTrue);
    });

    test('inconnu (Android 8) : pas de bouton', () {
      final r = _assess(WifiSecurity.wpa3, dns: null);
      expect(r.level, WifiLevel.excellent);
      expect(r.suggestPrivateDns, isFalse);
    });
  });

  test('pas de Wi-Fi : aucun conseil, pas de bouton', () {
    final r = assessWifi(fr, const WifiStatus(connected: false));
    expect(r.level, WifiLevel.pasDeWifi);
    expect(r.advice, isEmpty);
    expect(r.suggestPrivateDns, isFalse);
  });

  group('lecture de la Map Android', () {
    test('tous les champs', () {
      final s = WifiStatus.fromMap({
        'connected': true,
        'security': 'wpa3',
        'captivePortal': true,
        'privateDnsActive': false,
        'sdkInt': 35,
      });
      expect(s.connected, isTrue);
      expect(s.security, WifiSecurity.wpa3);
      expect(s.captivePortal, isTrue);
      expect(s.privateDnsActive, isFalse);
      expect(s.sdkInt, 35);
    });

    test('chaque nom envoyé par Kotlin est reconnu', () {
      const names = {
        'open': WifiSecurity.open,
        'owe': WifiSecurity.owe,
        'wep': WifiSecurity.wep,
        'wpa': WifiSecurity.wpa,
        'wpa2': WifiSecurity.wpa2,
        'wpa3': WifiSecurity.wpa3,
        'enterprise': WifiSecurity.enterprise,
        'unknown': WifiSecurity.unknown,
      };
      names.forEach((name, expected) {
        expect(WifiSecurity.fromName(name), expected);
      });
    });

    test('pas de Wi-Fi, DNS absent, type inconnu', () {
      final s = WifiStatus.fromMap({'connected': false, 'sdkInt': 27});
      expect(s.connected, isFalse);
      expect(s.security, WifiSecurity.unknown);
      expect(s.captivePortal, isFalse);
      expect(s.privateDnsActive, isNull);
      expect(WifiSecurity.fromName('wapi').name, 'unknown');
    });
  });
}
