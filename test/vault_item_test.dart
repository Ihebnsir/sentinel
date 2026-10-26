import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/vault/password_generator.dart';
import 'package:sentinel/services/vault/password_strength.dart';
import 'package:sentinel/services/vault/vault_item.dart';

import 'support/l10n.dart';

void main() {
  final cree = DateTime.utc(2026, 3, 1, 10);
  final item = VaultItem(
    id: 'a1',
    type: VaultItemType.motDePasse,
    titre: 'Banque',
    identifiant: 'moi@exemple.com',
    motDePasse: 'secret-très-long',
    siteWeb: 'https://banque.exemple',
    note: 'code client 123',
    creeLe: cree,
    modifieLe: cree,
  );

  group('VaultItem', () {
    test('JSON aller-retour sans perte', () {
      final copie = VaultItem.fromJson(item.toJson());
      expect(copie.toJson(), item.toJson());
      expect(copie.type, VaultItemType.motDePasse);
      expect(copie.creeLe, cree);
    });

    test('dates enregistrées en UTC', () {
      final local = VaultItem(
        id: 'b',
        type: VaultItemType.note,
        titre: 'Note',
        creeLe: DateTime(2026, 3, 1, 10),
        modifieLe: DateTime(2026, 3, 1, 10),
      );
      expect(local.toJson()['creeLe'], endsWith('Z'));
      final relu = VaultItem.fromJson(local.toJson()).creeLe;
      expect(relu.isUtc, isTrue);
      expect(relu.isAtSameMomentAs(DateTime(2026, 3, 1, 10)), isTrue);
    });

    test('champs facultatifs absents : textes vides', () {
      final note = VaultItem.fromJson({
        'id': 'n1',
        'type': 'note',
        'titre': 'Wi-Fi maison',
        'creeLe': '2026-03-01T10:00:00.000Z',
        'modifieLe': '2026-03-02T10:00:00.000Z',
      });
      expect(note.type, VaultItemType.note);
      expect(note.identifiant, '');
      expect(note.motDePasse, '');
      expect(note.siteWeb, '');
      expect(note.note, '');
    });

    test('JSON abîmé : erreur, pas un élément à moitié rempli', () {
      final json = item.toJson();
      expect(
        () => VaultItem.fromJson({...json, 'type': 'carte'}),
        throwsArgumentError,
      );
      expect(
        () => VaultItem.fromJson({...json, 'creeLe': 'hier'}),
        throwsFormatException,
      );
      expect(
        () => VaultItem.fromJson({...json}..remove('titre')),
        throwsA(isA<TypeError>()),
      );
    });

    test('copyWith garde id, type et date de création', () {
      final modifie = DateTime.utc(2026, 4, 1);
      final copie = item.copyWith(motDePasse: 'nouveau', modifieLe: modifie);
      expect(copie.id, item.id);
      expect(copie.type, item.type);
      expect(copie.creeLe, cree);
      expect(copie.modifieLe, modifie);
      expect(copie.motDePasse, 'nouveau');
      expect(copie.titre, item.titre);
      expect(copie.note, item.note);

      final vide = item.copyWith(note: '');
      expect(vide.note, '', reason: 'un texte vide efface la note');
    });

    test('toString ne révèle aucun secret', () {
      final texte = item.toString();
      expect(texte, 'VaultItem(a1, motDePasse)');
      for (final secret in ['Banque', 'moi@', 'secret', 'banque', '123']) {
        expect(texte, isNot(contains(secret)));
      }
    });

    test('noms des types traduits et distincts', () {
      for (final l in [fr, en, ar]) {
        expect(
          VaultItemType.motDePasse.label(l),
          isNot(VaultItemType.note.label(l)),
        );
      }
    });
  });

  group('GeneratorOptions.copyWith', () {
    test('ne change que ce qui est donné', () {
      const base = GeneratorOptions();
      final options = base.copyWith(length: 30, symbols: false);
      expect(options.length, 30);
      expect(options.symbols, isFalse);
      expect(options.uppercase, base.uppercase);
      expect(options.digits, base.digits);
    });

    test('tout décoché : minuscules seulement, longueur respectée', () {
      final options = const GeneratorOptions().copyWith(
        uppercase: false,
        digits: false,
        symbols: false,
      );
      final mdp = generatePassword(options);
      expect(mdp, hasLength(20));
      expect(mdp, matches(RegExp(r'^[a-z]+$')));
    });
  });

  test('niveaux de force : textes distincts dans chaque langue', () {
    for (final l in [fr, en, ar]) {
      final textes = {for (final s in PasswordStrength.values) s.label(l)};
      expect(textes, hasLength(PasswordStrength.values.length));
    }
  });
}
