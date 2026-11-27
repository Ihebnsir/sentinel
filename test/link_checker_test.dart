import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/firewall_service.dart';
import 'package:sentinel/services/links/link_checker.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/phishing/url_analyzer.dart';

import 'support/l10n.dart';

// Vérificateur de liens : extraction du premier lien, puis verdict
// (règles du lien + listes du pare-feu + liste blanche).

const _unknown = DomainCheck(allowed: false, dangerous: false);
const _listed = DomainCheck(allowed: false, dangerous: true);
const _allowed = DomainCheck(allowed: true, dangerous: false);

String? _first(String text) => extractFirstLink(text)?.text;

LinkCheck _check(String text, [DomainCheck? lists = _unknown]) =>
    checkText(text, lists: lists)!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKnownBrands);

  group('extraction du premier lien', () {
    test('lien seul, avec ou sans « https »', () {
      expect(_first('https://www.biat.com.tn'), 'https://www.biat.com.tn');
      expect(_first('www.poste.tn'), 'www.poste.tn');
      expect(_first('bit.ly/3xYz'), 'bit.ly/3xYz');
    });

    test('dans une phrase, ponctuation autour retirée', () {
      expect(
        _first('Votre colis est bloqué (https://poste-tn.info/suivi).'),
        'https://poste-tn.info/suivi',
      );
      expect(_first('Lien : « www.cnss.tn » !'), 'www.cnss.tn');
    });

    test('plusieurs liens : seulement le premier', () {
      expect(
        _first('Voir bit.ly/a puis https://biat-securite.top/login'),
        'bit.ly/a',
      );
    });

    test('arabe : ponctuation arabe et lien collé au texte', () {
      expect(
        _first('طردك محجوز، ادفع هنا: https://poste-tn.xyz/p،'),
        'https://poste-tn.xyz/p',
      );
      expect(_first('اضغط هناhttps://bit.ly/3abc'), 'https://bit.ly/3abc');
      expect(_first('هل وصلك الرابط؟ www.biat.com.tn؟'), 'www.biat.com.tn');
    });

    test('derja (latin et arabe)', () {
      expect(
        _first('3aslema, ta7t lien hedha: bit.ly/3xYz w ab3athli el code'),
        'bit.ly/3xYz',
      );
      expect(
        _first('كليكي على الرابط هذا d17-tn.top/gift باش تربح'),
        'd17-tn.top/gift',
      );
    });

    test('aucun lien : null', () {
      expect(_first('Rendez-vous demain.Merci'), isNull);
      expect(_first('Appelle-moi au 98 000 000'), isNull);
      expect(_first('Écris-moi à ali@exemple.tn'), isNull); // e-mail
      expect(_first('نشوفك غدوة إن شاء الله'), isNull);
      expect(_first('   '), isNull);
      expect(checkText('Bonjour'), isNull);
    });

    test('lien sans « https » : ouvert en https', () {
      expect(
        extractFirstLink('www.poste.tn')!.openableUrl,
        'https://www.poste.tn',
      );
      expect(
        extractFirstLink('http://exemple.tn')!.openableUrl,
        'http://exemple.tn',
      );
    });
  });

  group('verdicts : arnaques connues', () {
    test('imitation de marque tunisienne : Dangereux', () {
      for (final text in [
        'https://poste-tn-livraison.xyz/p',
        'http://biat-securite.com/login',
        'www.e-dinar-recharge.online',
        'https://d17-tn.top/gift',
      ]) {
        expect(_check(text).verdict, Verdict.dangereux, reason: text);
      }
    });

    test('domaine de la liste Malware : Dangereux, raison en premier', () {
      final c = _check('https://colis-livraison.example', _listed);
      expect(c.verdict, Verdict.dangereux);
      expect(
        c.reasons(fr).first,
        fr.linkReasonListed('colis-livraison.example'),
      );
    });

    test('adresse IP : Dangereux', () {
      expect(_check('http://192.168.4.1/banque').verdict, Verdict.dangereux);
    });

    test('raccourcisseur, http, punycode, extension : Suspect', () {
      expect(_check('bit.ly/3xYz').verdict, Verdict.suspect);
      expect(_check('bit.ly/3xYz').isShortener, isTrue);
      expect(_check('http://www.exemple.tn').verdict, Verdict.suspect);
      expect(_check('https://xn--pple-43d.com').verdict, Verdict.suspect);
      expect(_check('https://cadeau-gratuit.xyz').verdict, Verdict.suspect);
    });

    test(
      '« Ce lien mène en réalité à » : domaine enregistrable neutralisé',
      () {
        final c = _check('https://www.biat.com.tn.secure-login.xyz/connexion');
        expect(c.realDestination, 'secure-login[.]xyz');
        expect(
          _check('http://192.168.4.1/x').realDestination,
          '192[.]168[.]4[.]1',
        );
        expect(
          _check('https://www.biat.com.tn').realDestination,
          'biat[.]com[.]tn',
        );
      },
    );
  });

  group('verdicts : vrais sites tunisiens', () {
    test('Aucun problème connu', () {
      for (final text in [
        'https://www.biat.com.tn',
        'https://www.poste.tn/suivi',
        'https://www.d17.tn',
        'https://www.cnss.tn',
        'https://www.cnam.nat.tn',
        'https://www.ooredoo.tn',
        'https://www.tunisietelecom.tn',
        'https://www.attijaribank.com.tn',
      ]) {
        final c = _check(text);
        expect(c.verdict, Verdict.rien, reason: text);
        // « Absent des listes » : information à part, jamais une raison.
        expect(c.reasons(fr), isEmpty, reason: text);
        expect(c.notListed, isTrue, reason: text);
      }
    });

    test('listes indisponibles (hors Android) : pas de phrase « absent »', () {
      final c = _check('https://www.biat.com.tn', null);
      expect(c.verdict, Verdict.rien);
      expect(c.reasons(fr), isEmpty);
    });
  });

  group('liste blanche', () {
    test('passe avant les règles et les listes', () {
      final c = _check('https://poste-tn-livraison.xyz/p', _allowed);
      expect(c.verdict, Verdict.rien);
      expect(c.reasons(fr), [fr.linkReasonAllowed('poste-tn-livraison.xyz')]);
    });
  });

  test('chaque verdict a un texte et un conseil, dans chaque langue', () {
    for (final l in [fr, en, ar]) {
      expect({for (final v in Verdict.values) v.label(l)}, hasLength(3));
      expect({for (final v in Verdict.values) v.advice(l)}, hasLength(3));
    }
  });

  test('registrableDomain et defang', () {
    expect(registrableDomain('a.b.exemple.com'), 'exemple.com');
    expect(registrableDomain('www.cnam.nat.tn'), 'cnam.nat.tn');
    expect(defang('site.xyz'), 'site[.]xyz');
  });

  group('FirewallService.checkDomain', () {
    const channel = MethodChannel('com.iheb.sentinel/firewall');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('envoie le domaine, lit la réponse de Kotlin', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return {
          'domain': 'biat-securite.top',
          'allowed': false,
          'dangerous': true,
          'listsAvailable': true,
        };
      });
      final check = await FirewallService().checkDomain('biat-securite.top');
      expect(check!.dangerous, isTrue);
      expect(check.allowed, isFalse);
      expect(calls.single.method, 'checkDomain');
      expect(calls.single.arguments, {'domain': 'biat-securite.top'});
    });

    test('pas de code Android, refus ou réponse vide : null', () async {
      expect(await FirewallService().checkDomain('exemple.tn'), isNull);
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'X'),
      );
      expect(await FirewallService().checkDomain('exemple.tn'), isNull);
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(await FirewallService().checkDomain('exemple.tn'), isNull);
    });

    test('valeurs inattendues : rien d\'autorisé, rien de dangereux', () {
      final check = DomainCheck.fromMap({'allowed': 'oui', 'dangerous': 1});
      expect(check.allowed, isFalse);
      expect(check.dangerous, isFalse);
      expect(check.listsAvailable, isTrue);
    });
  });
}
