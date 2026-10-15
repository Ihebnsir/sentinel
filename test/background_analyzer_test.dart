import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/background/background_analyzer.dart';
import 'package:sentinel/services/phishing/message_analyzer.dart';

/// Une analyse inventée, pour tester la réponse seule.
MessageAnalysis fakeAnalysis(
  Verdict verdict,
  double probability, [
  List<String> reasons = const [],
]) => MessageAnalysis(
  verdict: verdict,
  probability: probability,
  reasons: reasons,
  advice: adviceFor(verdict),
  links: const [],
);

void main() {
  group('Réponse envoyée à Kotlin', () {
    test('arnaque : verdict technique, pourcentage, première raison', () {
      final response = backgroundResponseFor(
        fakeAnalysis(Verdict.arnaque, 0.874, [
          'Le lien imite La Poste',
          'Mots typiques des arnaques : « colis »',
        ]),
      );
      expect(response, {
        'verdict': 'arnaque',
        'percent': 87,
        'mainReason': 'Le lien imite La Poste',
      });
    });

    test('sans raison : phrase de secours', () {
      final response = backgroundResponseFor(
        fakeAnalysis(Verdict.arnaque, 0.95),
      );
      expect(response['mainReason'], defaultAlertReason);
    });

    test('suspect et rien gardent leur nom technique', () {
      expect(
        backgroundResponseFor(fakeAnalysis(Verdict.suspect, 0.6))['verdict'],
        'suspect',
      );
      final rien = backgroundResponseFor(fakeAnalysis(Verdict.rien, 0.04));
      expect(rien['verdict'], 'rien');
      expect(rien['percent'], 4);
    });

    test('ne contient que des types simples (transmissibles au canal)', () {
      final response = backgroundResponseFor(
        fakeAnalysis(Verdict.arnaque, 0.9, ['raison']),
      );
      expect(response.keys, {'verdict', 'percent', 'mainReason'});
      expect(response['percent'], isA<int>());
    });

    test("la raison de l'alerte a ses domaines neutralisés", () {
      final response = backgroundResponseFor(
        fakeAnalysis(Verdict.arnaque, 0.9, [
          "« poste-tn-livraison.xyz » imite La Poste Tunisienne mais ce n'est "
              'pas son site officiel',
        ]),
      );
      expect(
        response['mainReason'],
        startsWith('« poste-tn-livraison[.]xyz »'),
      );
    });
  });

  group('Neutralisation des domaines', () {
    test('domaine simple, comme les analystes sécurité', () {
      expect(
        defangDomains('poste-tn-livraison.xyz'),
        'poste-tn-livraison[.]xyz',
      );
    });

    test('tous les points du domaine, dans une phrase', () {
      expect(
        defangDomains('Lien raccourci (bit.ly) vers www.faux.com.tn'),
        'Lien raccourci (bit[.]ly) vers www[.]faux[.]com[.]tn',
      );
    });

    test('adresse IP', () {
      expect(
        defangDomains("Le lien utilise une adresse IP (192.168.1.10) au lieu"),
        "Le lien utilise une adresse IP (192[.]168[.]1[.]10) au lieu",
      );
    });

    test('majuscules', () {
      expect(defangDomains('PAYPAL-Secure.Click'), 'PAYPAL-Secure[.]Click');
    });

    test('nombres, extension seule et phrase sans domaine : inchangés', () {
      const texts = [
        'Votre colis coûte 3.5 dinars.',
        "L'extension « .xyz » est souvent utilisée par les arnaques",
        "Le lien n'est pas sécurisé (http au lieu de https)",
        defaultAlertReason,
      ];
      for (final text in texts) {
        expect(defangDomains(text), text);
      }
    });

    test('déjà neutralisé : pas de double crochet', () {
      expect(defangDomains('site[.]xyz'), 'site[.]xyz');
    });
  });

  group("Titre de l'alerte", () {
    test('SMS, quelle que soit l\'app', () {
      expect(
        alertTitleFor('com.google.android.apps.messaging', isSms: true),
        'Arnaque probable dans un SMS',
      );
      expect(
        alertTitleFor('com.exemple.sms', isSms: true),
        'Arnaque probable dans un SMS',
      );
    });

    test('messageries connues', () {
      expect(alertTitleFor('com.whatsapp'), 'Arnaque probable sur WhatsApp');
      expect(
        alertTitleFor('com.whatsapp.w4b'),
        'Arnaque probable sur WhatsApp Business',
      );
      expect(
        alertTitleFor('com.facebook.orca'),
        'Arnaque probable sur Messenger',
      );
      expect(
        alertTitleFor('org.telegram.messenger'),
        'Arnaque probable sur Telegram',
      );
      expect(alertTitleFor('com.viber.voip'), 'Arnaque probable sur Viber');
    });

    test('app inconnue : titre générique', () {
      expect(alertTitleFor('com.inconnue'), 'Arnaque probable dans un message');
    });
  });
}
