import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/links/link_checker.dart';
import 'package:sentinel/services/phishing/known_brands.dart';
import 'package:sentinel/services/qr/qr_apps.dart';
import 'package:sentinel/services/qr/qr_cards.dart';
import 'package:sentinel/services/qr/qr_content.dart';
import 'package:sentinel/services/qr/qr_safety.dart';
import 'package:sentinel/services/qr/scam_words.dart';

import 'support/l10n.dart';

// Formats ajoutés en 1.2.0 : messageries, installations d'apps, contacts,
// e-mails, cartes, cryptomonnaies, calendrier. Cas réels et pièges.

QrAssessment _assess(String raw) => assessQr(parseQr(raw));

T _parse<T extends QrContent>(String raw) {
  final content = parseQr(raw);
  expect(content, isA<T>(), reason: raw);
  return content as T;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKnownBrands);

  group('numéros et indicatifs', () {
    test('Tunisie, avec ou sans +, 00, espaces', () {
      for (final raw in [
        '+216 98 123 456',
        '0021698123456',
        '+216-98.123.456',
      ]) {
        final p = parsePhone(raw)!;
        expect(p.countryCode, '216', reason: raw);
        expect(p.national, '98123456');
        expect(p.zone, PhoneZone.home);
        expect(p.isForeign, isFalse);
      }
    });

    test('international sans + (wa.me) : indicatif reconnu', () {
      expect(
        parsePhone('21698123456', international: true)!.countryCode,
        '216',
      );
      expect(
        parsePhone('33612345678', international: true)!.zone,
        PhoneZone.usual,
      );
      expect(parsePhone('12025550123', international: true)!.countryCode, '1');
      expect(
        parsePhone('6281234567890', international: true)!.zone,
        PhoneZone.unusual,
      );
      expect(
        parsePhone('2348012345678', international: true)!.countryCode,
        '234',
      );
      expect(
        parsePhone('88213012345', international: true)!.zone,
        PhoneZone.special,
      );
    });

    test('numéro local, ou pas un numéro', () {
      expect(parsePhone('71 123 456')!.zone, PhoneZone.unknown);
      expect(parsePhone('71 123 456')!.countryCode, isNull);
      expect(parsePhone('abc'), isNull);
      expect(parsePhone('12'), isNull);
      expect(parsePhone('+1234567890123456789'), isNull);
    });
  });

  group('mots d\'arnaque', () {
    test('français', () {
      expect(
        findScamWords('Envoie-moi le code reçu par SMS'),
        containsAll(['envoie moi', 'code']),
      );
      expect(
        findScamWords('Votre mot de passe et le code de vérification'),
        containsAll(['mot de passe', 'code de verification']),
      );
      expect(
        findScamWords('Merci de PAYER les frais de livraison'),
        containsAll(['payer', 'frais de livraison']),
      );
    });

    test('anglais', () {
      expect(
        findScamWords('Please send me the verification code'),
        containsAll(['send me', 'verification code']),
      );
      expect(findScamWords('Buy a gift card'), contains('gift card'));
    });

    test('arabe, avec voyelles et lettres variantes', () {
      expect(
        findScamWords('أرسل لي الكود من فضلك'),
        containsAll(['ارسل', 'كود']),
      );
      expect(findScamWords('ما هي كلمةُ السرّ؟'), contains('كلمه السر'));
      expect(findScamWords('رمز التحقق الذي وصلك'), contains('رمز التحقق'));
      expect(findScamWords('وادفع 10 دينار'), contains('ادفع'));
    });

    test('derja (lettres arabes et latines)', () {
      expect(
        findScamWords('ابعثلي الكود اللي جاك'),
        containsAll(['ابعثلي', 'كود']),
      );
      expect(
        findScamWords('ab3athli el code taw'),
        containsAll(['ab3athli', 'code']),
      );
      expect(
        findScamWords('7awelli 50 dt flous'),
        containsAll(['7awelli', 'flous']),
      );
    });

    test('textes sans danger', () {
      expect(findScamWords('Bonjour, je veux commander une pizza'), isEmpty);
      expect(findScamWords("J'ai scanné votre QR code"), isEmpty);
      expect(findScamWords('Mon code postal est 2000'), isEmpty);
      expect(findScamWords('مرحبا، أريد حجز طاولة'), isEmpty);
      expect(findScamWords('Ahla, chnouwa a7wélek?'), isEmpty);
      expect(findScamWords(''), isEmpty);
    });

    test('texte énorme : rapide, sans erreur', () {
      final huge = 'bonjour ' * 200000;
      final watch = Stopwatch()..start();
      expect(findScamWords(huge), isEmpty);
      expect(watch.elapsedMilliseconds, lessThan(2000));
    });

    test('normalisation', () {
      expect(normalizeForScan('  Évitez-LES !! '), 'evitez les');
      expect(normalizeForScan('إِرْسَال'), 'ارسال');
    });
  });

  group('WhatsApp', () {
    test('wa.me sans texte, numéro tunisien : rien de suspect', () {
      final m = _parse<QrMessaging>('https://wa.me/21698123456');
      expect(m.app, MessagingApp.whatsapp);
      expect(m.target, MessagingTarget.person);
      expect(m.phone!.countryCode, '216');
      expect(m.text, isEmpty);
      final a = assessQr(m);
      expect(a.verdict, Verdict.rien);
      expect(a.findings, isEmpty);
      expect(a.action, QrAction.ouvrirLien);
      expect(a.openableUrl, 'https://wa.me/21698123456');
      expect(a.actionAllowed, isTrue);
    });

    test('wa.me avec texte banal', () {
      final m = _parse<QrMessaging>(
        'https://wa.me/21698123456?text=Bonjour%20je%20veux%20r%C3%A9server',
      );
      expect(m.text, 'Bonjour je veux réserver');
      expect(assessQr(m).verdict, Verdict.rien);
    });

    test('wa.me avec demande de code : suspect, mots cités', () {
      final a = _assess(
        'https://wa.me/21698123456?text=Envoie+moi+le+code+re%C3%A7u',
      );
      expect(a.verdict, Verdict.suspect);
      expect(a.warnings, [QrWarning.messageArnaque]);
      expect(a.findings.single.reason(fr), contains('« envoie moi »'));
    });

    test('texte arabe et derja pré-remplis', () {
      expect(
        _assess(
          'https://wa.me/21698123456?text=${Uri.encodeComponent('ابعثلي الكود')}',
        ).warnings,
        [QrWarning.messageArnaque],
      );
      expect(
        _assess(
          'https://api.whatsapp.com/send?phone=21698123456&text=${Uri.encodeComponent('أرسل رمز التحقق')}',
        ).warnings,
        [QrWarning.messageArnaque],
      );
    });

    test('numéro français : étranger courant (information)', () {
      final a = _assess('https://wa.me/33612345678');
      expect(a.warnings, [QrWarning.numeroEtranger]);
      expect(a.verdict, Verdict.rien);
      expect(a.findings.single.reason(fr), contains('+33'));
    });

    test('numéro indonésien : pays inattendu, suspect', () {
      final a = _assess('https://api.whatsapp.com/send?phone=6281234567890');
      expect(a.warnings, [QrWarning.numeroInattendu]);
      expect(a.verdict, Verdict.suspect);
      expect(a.findings.single.reason(fr), contains('+62'));
    });

    test('numéro satellite : spécial, suspect', () {
      expect(_assess('https://wa.me/88213012345').warnings, [
        QrWarning.numeroSpecial,
      ]);
    });

    test('groupe chat.whatsapp.com : invitation signalée', () {
      final m = _parse<QrMessaging>('https://chat.whatsapp.com/HkL8xXabcDEF12');
      expect(m.target, MessagingTarget.group);
      expect(m.handle, 'HkL8xXabcDEF12');
      final a = assessQr(m);
      expect(a.warnings, [QrWarning.groupe]);
      expect(a.verdict, Verdict.rien);
    });

    test('chaîne, lien d\'entreprise, partage sans destinataire', () {
      expect(
        _parse<QrMessaging>('https://whatsapp.com/channel/0029Va').target,
        MessagingTarget.channel,
      );
      expect(
        _parse<QrMessaging>('https://wa.me/message/ABCDEF').target,
        MessagingTarget.person,
      );
      final share = _parse<QrMessaging>('https://wa.me/?text=Salut');
      expect(share.target, MessagingTarget.share);
      expect(share.text, 'Salut');
    });

    test('whatsapp:// : expliqué, jamais ouvert', () {
      final m = _parse<QrMessaging>(
        'whatsapp://send?phone=21698123456&text=Paiement%20urgent',
      );
      expect(m.phone!.countryCode, '216');
      final a = assessQr(m);
      expect(a.verdict, Verdict.suspect);
      expect(a.action, isNull);
    });

    test('texte pré-rempli avec faux site : dangereux', () {
      final a = _assess(
        'https://wa.me/21698123456?text=${Uri.encodeComponent('Suivez https://poste-tn.com/colis')}',
      );
      expect(a.verdict, Verdict.dangereux);
      expect(a.actionAllowed, isFalse);
    });

    test('faux domaine wa.me : reste un lien web', () {
      expect(parseQr('https://wa.me.secure-login.xyz/216'), isA<QrLink>());
      expect(parseQr('https://wa.me'), isA<QrLink>());
    });
  });

  group('Telegram, Messenger, Viber', () {
    test('t.me/nom : compte ; bot ; chaîne', () {
      final m = _parse<QrMessaging>('https://t.me/sentinel_tn');
      expect(m.app, MessagingApp.telegram);
      expect(m.handle, '@sentinel_tn');
      expect(m.target, MessagingTarget.person);
      expect(
        _parse<QrMessaging>('https://t.me/AideColisBot').target,
        MessagingTarget.bot,
      );
      expect(
        _parse<QrMessaging>('https://t.me/s/actualites').target,
        MessagingTarget.channel,
      );
      expect(
        _parse<QrMessaging>('https://telegram.me/sentinel_tn').handle,
        '@sentinel_tn',
      );
    });

    test('t.me/+code et joinchat : groupe ; t.me/+216… : numéro', () {
      expect(
        _parse<QrMessaging>('https://t.me/+AbCdEf123').target,
        MessagingTarget.group,
      );
      expect(
        _parse<QrMessaging>('https://t.me/joinchat/AbCdEf').target,
        MessagingTarget.group,
      );
      final phone = _parse<QrMessaging>('https://t.me/+21698123456');
      expect(phone.target, MessagingTarget.person);
      expect(phone.phone!.countryCode, '216');
    });

    test('t.me/share : texte analysé', () {
      final a = _assess(
        'https://t.me/share/url?url=https%3A%2F%2Fexemple.tn&text=Envoyez%20le%20code',
      );
      expect(a.warnings, contains(QrWarning.messageArnaque));
    });

    test('tg:// : résolu sans être ouvert', () {
      final m = _parse<QrMessaging>('tg://resolve?domain=promo_bot');
      expect(m.target, MessagingTarget.bot);
      expect(assessQr(m).action, isNull);
      expect(
        _parse<QrMessaging>('tg://join?invite=XYZ').target,
        MessagingTarget.group,
      );
      expect(parseQr('tg://resolve'), isA<QrText>());
    });

    test('m.me : page ; m.me/j : groupe', () {
      final m = _parse<QrMessaging>('https://m.me/MaBoutique?text=Bonjour');
      expect(m.app, MessagingApp.messenger);
      expect(m.handle, 'MaBoutique');
      expect(m.text, 'Bonjour');
      expect(
        _parse<QrMessaging>('https://m.me/j/AbC').target,
        MessagingTarget.group,
      );
    });

    test('viber:// : numéro, chaîne, partage', () {
      final m = _parse<QrMessaging>('viber://chat?number=%2B21698123456');
      expect(m.app, MessagingApp.viber);
      expect(m.phone!.countryCode, '216');
      expect(
        _parse<QrMessaging>('viber://pa?chatURI=promos').target,
        MessagingTarget.channel,
      );
      expect(
        _parse<QrMessaging>('viber://forward?text=Code').target,
        MessagingTarget.share,
      );
      expect(
        _parse<QrMessaging>('https://invite.viber.com/?g2=AQ').target,
        MessagingTarget.group,
      );
    });
  });

  group('installation d\'applications', () {
    test('Play Store, paquet officiel : rien de connu, ouvrable', () {
      final app = _parse<QrAppInstall>(
        'https://play.google.com/store/apps/details?id=com.whatsapp&hl=fr',
      );
      expect(app.source, AppSource.playStore);
      expect(app.packageId, 'com.whatsapp');
      final a = assessQr(app);
      expect(a.warnings, [QrWarning.paquetOfficiel]);
      expect(a.findings.single.reason(fr), contains('WhatsApp'));
      expect(a.verdict, Verdict.rien);
      expect(a.actionAllowed, isTrue);
    });

    test('market:// faux paquet WhatsApp : suspect, jamais ouvert', () {
      final app = _parse<QrAppInstall>(
        'market://details?id=com.whatsapp.update.pro',
      );
      final a = assessQr(app);
      expect(app.packageId, 'com.whatsapp.update.pro');
      // Préfixe de l'éditeur officiel : pas d'accusation.
      expect(a.warnings, [QrWarning.paquetInconnu]);
      expect(a.action, isNull);

      final fake = assessQr(
        parseQr('market://details?id=com.whatsap.messenger'),
      );
      expect(fake.warnings, [QrWarning.paquetImiteStore]);
      expect(fake.verdict, Verdict.suspect);
      expect(fake.findings.single.reason(fr), contains('com.whatsapp'));
    });

    test('imitations : lettres en plus, en moins, sosies', () {
      for (final id in [
        'com.whatsapp2.chat',
        'com.watsapp.free',
        'org.whatsappupdate.app',
        'com.vvhatsapp',
        'com.instagrarn.lite',
        'com.telegram.premium.free',
      ]) {
        expect(checkPackage(id).verdict, PackageVerdict.imitation, reason: id);
      }
    });

    test('vrais paquets et éditeurs officiels : jamais accusés', () {
      for (final id in [
        'com.whatsapp',
        'com.whatsapp.w4b',
        'com.facebook.lite',
        'com.google.android.apps.youtube.music',
        'org.telegram.messenger',
        'com.zhiliaoapp.musically',
        'com.ss.android.ugc.trill',
      ]) {
        expect(
          checkPackage(id).verdict,
          isNot(PackageVerdict.imitation),
          reason: id,
        );
      }
      expect(
        checkPackage('com.exemple.messenger').verdict,
        PackageVerdict.unknown,
      );
      expect(checkPackage('com.biat.mobile').verdict, PackageVerdict.unknown);
    });

    test('version modifiée connue et paquet invalide', () {
      expect(checkPackage('com.gbwhatsapp').verdict, PackageVerdict.knownMod);
      final mod = _assess(
        'https://play.google.com/store/apps/details?id=com.gbwhatsapp',
      );
      expect(mod.verdict, Verdict.dangereux);
      expect(checkPackage('1com.bad').verdict, PackageVerdict.invalid);
      expect(checkPackage('whatsapp').verdict, PackageVerdict.invalid);
      expect(_assess('market://details?id=..x').warnings, [
        QrWarning.paquetInvalide,
      ]);
    });

    test('.apk direct : dangereux par défaut, explication', () {
      for (final raw in [
        'https://exemple.tn/WhatsApp-Gold.apk',
        'https://cdn.exemple.com/app.APK?v=2',
        'https://exemple.com/download?response-content-type=application%2Fvnd.android.package-archive',
        'https://dl.apkpure.com/b/XAPK/x.xapk',
      ]) {
        final a = _assess(raw);
        expect(a.kind, QrKind.app, reason: raw);
        expect(a.warnings, contains(QrWarning.apkDirect), reason: raw);
        expect(a.verdict, Verdict.dangereux, reason: raw);
        expect(a.actionAllowed, isFalse);
      }
      expect(QrWarning.apkDirect.reason(fr), contains('Applications'));
    });

    test('intent:// avec paquet : app visée, dangereux', () {
      final app = _parse<QrAppInstall>(
        'intent://scan/#Intent;scheme=zxing;package=com.whatsapp.fake;end',
      );
      expect(app.source, AppSource.intent);
      expect(app.packageId, 'com.whatsapp.fake');
      expect(assessQr(app).verdict, Verdict.dangereux);
      expect(
        parseQr('intent://scan/#Intent;scheme=x;end'),
        isA<QrUnsafeLink>(),
      );
    });

    test('boutiques alternatives', () {
      final third = _assess('https://apkpure.com/fr/whatsapp/com.whatsapp');
      expect(third.warnings, [QrWarning.boutiqueTierce]);
      expect(third.verdict, Verdict.suspect);
      expect(third.findings.single.reason(fr), contains('APKPure'));
      expect(_assess('https://whatsapp.fr.uptodown.com/android').warnings, [
        QrWarning.boutiqueTierce,
      ]);

      final samsung = _parse<QrAppInstall>(
        'https://galaxystore.samsung.com/detail/com.whatsapp',
      );
      expect(samsung.source, AppSource.vendorStore);
      expect(samsung.packageId, 'com.whatsapp');
      expect(assessQr(samsung).verdict, Verdict.rien);
      expect(
        _parse<QrAppInstall>('samsungapps://ProductDetail/com.whatsapp')
            .packageId,
        'com.whatsapp',
      );
      expect(
        _parse<QrAppInstall>('amzn://apps/android?p=com.exemple.app').store,
        'Amazon Appstore',
      );
      expect(
        _parse<QrAppInstall>('appmarket://details?id=com.huawei.x').source,
        AppSource.vendorStore,
      );
    });

    test('Play Store sans paquet (recherche) : rien à comparer', () {
      final app = _parse<QrAppInstall>(
        'https://play.google.com/store/apps/dev?id=123',
      );
      expect(app.packageId, isNull);
      expect(assessQr(app).findings, isEmpty);
    });
  });

  group('contacts', () {
    test('vCard « Service client BIAT » : imite une banque', () {
      const raw =
          'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Service client BIAT\r\n'
          'TEL;TYPE=CELL:+216 98 000 111\r\nEMAIL:support@biat-tn.com\r\nEND:VCARD';
      final c = _parse<QrContact>(raw);
      expect(c.name, 'Service client BIAT');
      expect(c.phones, ['+216 98 000 111']);
      expect(c.emails, ['support@biat-tn.com']);
      final a = assessQr(c);
      expect(a.warnings, [QrWarning.contactMarque]);
      expect(a.verdict, Verdict.suspect);
      expect(a.findings.first.reason(fr), contains('BIAT'));
    });

    test('vCard opérateur, app connue, service générique', () {
      expect(
        _assess('BEGIN:VCARD\nFN:Ooredoo Recharge\nTEL:+21622000000\nEND:VCARD')
            .warnings,
        [QrWarning.contactMarque],
      );
      expect(
        _assess('BEGIN:VCARD\nFN:WhatsApp Support\nEND:VCARD')
            .findings
            .single
            .detail,
        'WhatsApp',
      );
      expect(
        _assess('BEGIN:VCARD\nFN:Service Client\nTEL:+21622000000\nEND:VCARD')
            .warnings,
        [QrWarning.contactService],
      );
      expect(_assess('BEGIN:VCARD\nFN:خدمة العملاء\nEND:VCARD').warnings, [
        QrWarning.contactService,
      ]);
    });

    test('vCard ordinaire : nom, organisation, numéro étranger', () {
      final c = _parse<QrContact>(
        'BEGIN:VCARD\nVERSION:2.1\nN:Ben Salah;Amira;;;\nORG:Cabinet Médical\nTEL:+33612345678\nEND:VCARD',
      );
      expect(c.name, 'Amira Ben Salah');
      expect(c.organization, 'Cabinet Médical');
      final a = assessQr(c);
      expect(a.warnings, [QrWarning.numeroEtranger]);
      expect(a.verdict, Verdict.rien);
    });

    test('vCard 2.1 quoted-printable, lignes repliées, arabe', () {
      final c = _parse<QrContact>(
        'BEGIN:VCARD\nVERSION:2.1\nFN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:=C3=89lodie\nNOTE:longue\n  suite\nEND:VCARD',
      );
      expect(c.name, 'Élodie');
      expect(_parse<QrContact>('BEGIN:VCARD\nFN:أحمد\nEND:VCARD').name, 'أحمد');
    });

    test('MECARD', () {
      final c = _parse<QrContact>(
        r'MECARD:N:Trabelsi,Sami;TEL:+21698123456;EMAIL:sami@exemple.tn;ORG:Poste\; Agence;;',
      );
      expect(c.name, 'Sami Trabelsi');
      expect(c.phones, ['+21698123456']);
      expect(c.organization, 'Poste; Agence');
      expect(
        assessQr(parseQr('MECARD:N:La Poste Tunisienne;TEL:+21671000000;;'))
            .warnings,
        [QrWarning.contactMarque],
      );
    });

    test('fiches vides ou abîmées : texte', () {
      expect(parseQr('BEGIN:VCARD\nEND:VCARD'), isA<QrText>());
      expect(parseQr('MECARD:;;'), isA<QrText>());
      expect(parseQr('BEGIN:'), isA<QrText>());
    });

    test('fiche énorme : limitée, sans erreur', () {
      final lines = List.generate(
        5000,
        (i) => 'TEL:+2169800${i.toString().padLeft(4, '0')}',
      );
      final c = _parse<QrContact>(
        'BEGIN:VCARD\nFN:X\n${lines.join('\n')}\nEND:VCARD',
      );
      expect(c.phones.length, lessThanOrEqualTo(10));
    });
  });

  group('e-mail, carte, calendrier, crypto', () {
    test('mailto: avec objet et texte', () {
      final e = _parse<QrEmail>(
        'mailto:contact@exemple.tn?subject=Commande&body=Bonjour%20!',
      );
      expect(e.address, 'contact@exemple.tn');
      expect(e.subject, 'Commande');
      expect(e.body, 'Bonjour !');
      expect(assessQr(e).verdict, Verdict.rien);
      expect(assessQr(e).action, isNull);
    });

    test('mailto: qui demande un mot de passe : suspect', () {
      expect(
        _assess('mailto:x@exemple.tn?body=Votre%20mot%20de%20passe%20SVP')
            .verdict,
        Verdict.suspect,
      );
      expect(
        _parse<QrEmail>('MATMSG:TO:a@b.tn;SUB:Hi;BODY:Yo;;').address,
        'a@b.tn',
      );
      expect(parseQr('mailto:'), isA<QrText>());
    });

    test('geo: coordonnées et lieu', () {
      final g = _parse<QrGeo>('geo:36.8065,10.1815?q=Tunis');
      expect(g.latitude, closeTo(36.8065, 1e-9));
      expect(g.longitude, closeTo(10.1815, 1e-9));
      expect(g.label, 'Tunis');
      expect(assessQr(g).verdict, isNull);
      expect(parseQr('geo:999,10'), isA<QrText>());
      expect(parseQr('geo:abc'), isA<QrText>());
    });

    test('crypto : avertissement, suspect', () {
      final a = _assess(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.5',
      );
      expect(a.kind, QrKind.crypto);
      expect(a.warnings, [QrWarning.crypto]);
      expect(a.verdict, Verdict.suspect);
      expect(QrWarning.crypto.reason(fr), contains("N'envoyez jamais"));
      expect(
        _assess('ethereum:0x89205A3A3b2A69De6Dbf7f01ED13B2108B2c43e7').kind,
        QrKind.crypto,
      );
    });

    test('calendrier VEVENT, dans VCALENDAR, lien vérifié', () {
      const raw =
          'BEGIN:VCALENDAR\nBEGIN:VEVENT\nSUMMARY:Rendez-vous banque\n'
          'DTSTART:20261201T180000Z\nDTEND:20261201\nLOCATION:Tunis\n'
          'DESCRIPTION:Confirmez sur https://biat-secure.xyz/rdv\nEND:VEVENT\nEND:VCALENDAR';
      final e = _parse<QrEvent>(raw);
      expect(e.summary, 'Rendez-vous banque');
      expect(e.start, '2026-12-01 18:00 UTC');
      expect(e.end, '2026-12-01');
      expect(assessQr(e).verdict, Verdict.dangereux);
      expect(formatIcsDate('n importe quoi'), 'n importe quoi');
      expect(parseQr('BEGIN:VEVENT\nEND:VEVENT'), isA<QrText>());
    });
  });

  group('contenus mal formés ou énormes', () {
    test('jamais d\'exception', () {
      for (final raw in [
        '',
        ' ',
        'https://',
        'https://wa.me/',
        'https://t.me/',
        'https://play.google.com/store/apps/details?id=',
        'market://',
        'viber://',
        'whatsapp://',
        'mailto:%E0%A4%A',
        'geo:',
        'BEGIN:VCARD',
        'MECARD:N:',
        'intent:#Intent;package=;end',
        'https://wa.me/%ZZ?text=%E0%A4%A',
        'x' * 100000,
        'https://exemple.tn/${'a' * 50000}.apk',
        'BEGIN:VCARD\n${'FN:${'a' * 1000}\n' * 1000}END:VCARD',
      ]) {
        final content = parseQr(raw);
        final a = assessQr(content);
        expect(
          a.content,
          same(content),
          reason: raw.length > 60 ? raw.substring(0, 60) : raw,
        );
        for (final f in a.findings) {
          expect(f.reason(fr), isNotEmpty);
        }
      }
    });
  });

  test(
    'chaque type a un libellé et chaque avertissement un texte, 3 langues',
    () {
      for (final l in [fr, en, ar]) {
        final texts = {
          for (final w in QrWarning.values) QrFinding(w, 'X').reason(l),
        };
        // paquetImite et paquetImiteStore partagent le même texte.
        expect(texts, hasLength(QrWarning.values.length - 1));
      }
    },
  );
}
