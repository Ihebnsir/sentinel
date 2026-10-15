import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/phishing/message_analyzer.dart';
import 'package:sentinel/services/phishing/phishing_model.dart';
import 'package:sentinel/services/phishing/url_analyzer.dart';

/// Les signaux trouvés dans le premier lien d'un texte.
Set<LinkSignal> signalsOf(String text) {
  final links = analyzeLinks(text);
  expect(links, isNotEmpty, reason: 'aucun lien trouvé dans « $text »');
  return {for (final f in links.first.findings) f.signal};
}

/// Une prédiction de l'IA inventée, pour tester la combinaison seule.
PhishingPrediction fakePrediction(double p, [List<String> words = const []]) =>
    PhishingPrediction(
      probability: p,
      suspiciousNgrams: const [],
      suspiciousWords: words,
    );

void main() {
  group('Extraction des liens', () {
    test('avec et sans http', () {
      final links = analyzeLinks(
        'Payez ici : poste-tn.xyz/colis ou https://www.biat.com.tn/fr.',
      );
      expect(links.map((l) => l.host), ['poste-tn.xyz', 'www.biat.com.tn']);
      expect(links.first.text, 'poste-tn.xyz/colis');
    });

    test('pas de faux lien dans une phrase normale', () {
      expect(
        analyzeLinks('Rendez-vous demain à 9h.Merci ! 1,900 DT, 3.5 kg'),
        isEmpty,
      );
    });

    test('une adresse e-mail n\'est pas un lien', () {
      expect(analyzeLinks('Écrivez à contact@poste.tn'), isEmpty);
    });

    test('ponctuation autour du lien retirée', () {
      expect(analyzeLinks('(voir bit.ly/abc).').single.host, 'bit.ly');
    });
  });

  group('Règles sur les liens', () {
    test('usurpation de marque', () {
      expect(signalsOf('poste-tn.xyz/colis'),
          contains(LinkSignal.usurpationMarque));
      expect(signalsOf('https://biat-securite.com'),
          {LinkSignal.usurpationMarque});
      expect(signalsOf('https://www.la-poste-tunisie.com'),
          {LinkSignal.usurpationMarque});
    });

    test('domaines officiels et leurs sous-domaines : rien à signaler', () {
      expect(signalsOf('https://www.poste.tn'), isEmpty);
      expect(signalsOf('https://ebanking.biat.com.tn/login'), isEmpty);
      expect(signalsOf('https://www.ooredoo.tn'), isEmpty);
    });

    test('mot-clé court seulement s\'il est isolé', () {
      expect(impersonatedBrand('stb-paiement.com')?.name, 'STB');
      expect(impersonatedBrand('bestbuy.com'), isNull);
    });

    test('raccourcisseurs', () {
      for (final s in ['bit.ly/x', 'tinyurl.com/x', 't.co/x', 'rb.gy/x']) {
        expect(signalsOf(s), {LinkSignal.raccourcisseur}, reason: s);
      }
    });

    test('adresse IP', () {
      expect(signalsOf('http://192.168.1.20/login'),
          {LinkSignal.adresseIp, LinkSignal.sansHttps});
      expect(signalsOf('41.230.1.1/banque'), {LinkSignal.adresseIp});
    });

    test('punycode', () {
      expect(signalsOf('https://xn--pste-8qa.tn'), {LinkSignal.punycode});
    });

    test('extension suspecte', () {
      expect(signalsOf('https://cadeau-gratuit.top'),
          {LinkSignal.extensionSuspecte});
    });

    test('http sans https', () {
      expect(signalsOf('http://exemple.com'), {LinkSignal.sansHttps});
    });

    test('« @ » dans le lien', () {
      final link = analyzeLinks('https://www.google.com@arnaque.com/x').single;
      expect(link.host, 'arnaque.com');
      expect(link.has(LinkSignal.arobase), isTrue);
    });

    test('plus de 3 sous-domaines', () {
      expect(subdomainCount('a.b.c.exemple.com'), 3);
      expect(subdomainCount('a.biat.com.tn'), 1);
      expect(signalsOf('https://a.b.c.d.exemple.com'),
          {LinkSignal.tropDeSousDomaines});
      expect(signalsOf('https://a.b.c.exemple.com'), isEmpty);
    });

    test('chaque signal a une raison en français', () {
      final link = analyzeLinks('http://poste.tn.colis.xyz').single;
      expect(link.findings.first.reason, contains('La Poste Tunisienne'));
    });
  });

  group('Combinaison IA + liens', () {
    test('IA très sûre → Arnaque probable', () {
      final a = analyzeMessage('Bonjour', fakePrediction(0.8));
      expect(a.verdict, Verdict.arnaque);
    });

    test('usurpation de marque → Arnaque probable, même si l\'IA doute', () {
      final a = analyzeMessage('Voir poste-tn.com', fakePrediction(0.1));
      expect(a.verdict, Verdict.arnaque);
    });

    test('adresse IP → Arnaque probable', () {
      final a = analyzeMessage('http://10.0.0.1/a', fakePrediction(0.1));
      expect(a.verdict, Verdict.arnaque);
    });

    test('IA entre 0,5 et 0,8 → Suspect', () {
      expect(analyzeMessage('Bonjour', fakePrediction(0.5)).verdict,
          Verdict.suspect);
      expect(analyzeMessage('Bonjour', fakePrediction(0.79)).verdict,
          Verdict.suspect);
    });

    test('autre signal de lien → Suspect', () {
      final a = analyzeMessage('Regarde bit.ly/abc', fakePrediction(0.1));
      expect(a.verdict, Verdict.suspect);
    });

    test('rien → Rien de suspect, sans raison', () {
      final a = analyzeMessage(
        'On mange à 20h ? https://www.poste.tn',
        fakePrediction(0.2, ['mange']),
      );
      expect(a.verdict, Verdict.rien);
      expect(a.reasons, isEmpty);
      expect(a.advice, isNotEmpty);
    });

    test('raisons : liens d\'abord, puis les mots', () {
      final a = analyzeMessage(
        'Colis bloqué, payez ici : poste-tn.xyz/p',
        fakePrediction(0.9, ['colis', 'payez']),
      );
      expect(a.reasons.first, contains('poste-tn.xyz'));
      expect(a.reasons.last, 'Mots typiques des arnaques : « colis », « payez »');
      expect(a.percent, 90);
      expect(a.advice, contains('ne communiquez aucun code'));
    });

    test('la même raison n\'apparaît qu\'une fois', () {
      final a = analyzeMessage('bit.ly/a bit.ly/b', fakePrediction(0.1));
      expect(a.reasons, hasLength(1));
    });
  });
}
