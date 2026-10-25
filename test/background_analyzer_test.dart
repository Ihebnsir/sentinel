import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/background/background_analyzer.dart';
import 'package:sentinel/l10n/l10n.dart';
import 'package:sentinel/services/phishing/message_analyzer.dart';
import 'package:sentinel/services/phishing/url_analyzer.dart';

import 'support/l10n.dart';

/// Une analyse inventée, pour tester la réponse seule.
MessageAnalysis fakeAnalysis(
  Verdict verdict,
  double probability, {
  List<AnalyzedLink> links = const [],
  List<String> words = const [],
}) => MessageAnalysis(
  verdict: verdict,
  probability: probability,
  links: links,
  scamWords: words,
);

/// Un lien qui imite La Poste Tunisienne.
AnalyzedLink imitation(String host) => AnalyzedLink(
  text: host,
  host: host,
  findings: [
    LinkFinding(
      LinkSignal.usurpationMarque,
      host: host,
      brand: 'La Poste Tunisienne',
    ),
  ],
);

void main() {
  group('Réponse envoyée à Kotlin', () {
    test('arnaque : verdict technique, pourcentage, première raison', () {
      final response = backgroundResponseFor(
        fakeAnalysis(
          Verdict.arnaque,
          0.874,
          links: [imitation('poste-tn.xyz')],
          words: ['colis'],
        ),
        fr,
      );
      expect(response, {
        'verdict': 'arnaque',
        'percent': 87,
        'mainReason':
            "« poste-tn[.]xyz » imite La Poste Tunisienne mais ce n'est pas "
            'son site officiel',
      });
    });

    test('sans raison : phrase de secours', () {
      final response = backgroundResponseFor(
        fakeAnalysis(Verdict.arnaque, 0.95),
        fr,
      );
      expect(response['mainReason'], fr.alertDefaultReason);
    });

    test('suspect et rien gardent leur nom technique', () {
      expect(
        backgroundResponseFor(
          fakeAnalysis(Verdict.suspect, 0.6),
          fr,
        )['verdict'],
        'suspect',
      );
      final rien = backgroundResponseFor(fakeAnalysis(Verdict.rien, 0.04), fr);
      expect(rien['verdict'], 'rien');
      expect(rien['percent'], 4);
    });

    test('ne contient que des types simples (transmissibles au canal)', () {
      final response = backgroundResponseFor(
        fakeAnalysis(Verdict.arnaque, 0.9, words: ['raison']),
        fr,
      );
      expect(response.keys, {'verdict', 'percent', 'mainReason'});
      expect(response['percent'], isA<int>());
    });

    test("la raison de l'alerte a ses domaines neutralisés", () {
      final response = backgroundResponseFor(
        fakeAnalysis(
          Verdict.arnaque,
          0.9,
          links: [imitation('poste-tn-livraison.xyz')],
        ),
        fr,
      );
      expect(
        response['mainReason'],
        startsWith('« poste-tn-livraison[.]xyz »'),
      );
    });

    test("dans la langue de l'app (arabe, anglais)", () {
      final analysis = fakeAnalysis(
        Verdict.arnaque,
        0.9,
        links: [imitation('poste-tn.xyz')],
      );
      expect(
        backgroundResponseFor(analysis, ar)['mainReason'],
        '«poste-tn[.]xyz» ينتحل صفة La Poste Tunisienne لكنه ليس موقعه الرسمي',
      );
      expect(
        backgroundResponseFor(analysis, en)['mainReason'],
        '"poste-tn[.]xyz" imitates La Poste Tunisienne but is not its '
        'official website',
      );
    });

    test('langue inconnue ou absente : français', () {
      expect(l10nFor('de').localeName, 'fr');
      expect(l10nFor(null).localeName, 'fr');
      expect(l10nFor('ar').localeName, 'ar');
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
      final texts = [
        'Votre colis coûte 3.5 dinars.',
        "L'extension « .xyz » est souvent utilisée par les arnaques",
        "Le lien n'est pas sécurisé (http au lieu de https)",
        fr.alertDefaultReason,
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
        alertTitleFor(fr, 'com.google.android.apps.messaging', isSms: true),
        'Arnaque probable dans un SMS',
      );
      expect(
        alertTitleFor(fr, 'com.exemple.sms', isSms: true),
        'Arnaque probable dans un SMS',
      );
    });

    test('messageries connues', () {
      expect(alertTitleFor(fr, 'com.whatsapp'), 'Arnaque probable sur WhatsApp');
      expect(
        alertTitleFor(fr, 'com.whatsapp.w4b'),
        'Arnaque probable sur WhatsApp Business',
      );
      expect(
        alertTitleFor(fr, 'com.facebook.orca'),
        'Arnaque probable sur Messenger',
      );
      expect(
        alertTitleFor(fr, 'org.telegram.messenger'),
        'Arnaque probable sur Telegram',
      );
      expect(alertTitleFor(fr, 'com.viber.voip'), 'Arnaque probable sur Viber');
    });

    test('en arabe et en anglais', () {
      expect(alertTitleFor(ar, 'com.whatsapp'), 'احتيال محتمل على WhatsApp');
      expect(alertTitleFor(en, 'x', isSms: true), 'Likely scam in an SMS');
    });

    test('app inconnue : titre générique', () {
      expect(alertTitleFor(fr, 'com.inconnue'), 'Arnaque probable dans un message');
    });
  });
}
