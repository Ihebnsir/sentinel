import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/vault/password_generator.dart';
import 'package:sentinel/services/vault/password_strength.dart';

bool hasAny(String text, String chars) => text.split('').any(chars.contains);

void main() {
  group('Générateur', () {
    test('longueur respectée de 12 à 64', () {
      for (final length in [12, 13, 20, 40, 64]) {
        final password = generatePassword(GeneratorOptions(length: length));
        expect(password.length, length);
      }
    });

    test('longueur hors limites ramenée entre 12 et 64', () {
      expect(generatePassword(const GeneratorOptions(length: 4)).length, 12);
      expect(generatePassword(const GeneratorOptions(length: 500)).length, 64);
    });

    test('chaque type coché est présent', () {
      for (var i = 0; i < 200; i++) {
        final password = generatePassword(const GeneratorOptions(length: 12));
        expect(hasAny(password, lowercaseChars), isTrue);
        expect(hasAny(password, uppercaseChars), isTrue);
        expect(hasAny(password, digitChars), isTrue);
        expect(hasAny(password, symbolChars), isTrue);
      }
    });

    test('un type décoché est absent', () {
      for (var i = 0; i < 200; i++) {
        final password = generatePassword(
          const GeneratorOptions(
            length: 30,
            uppercase: false,
            digits: true,
            symbols: false,
          ),
        );
        expect(hasAny(password, uppercaseChars), isFalse);
        expect(hasAny(password, symbolChars), isFalse);
        expect(hasAny(password, digitChars), isTrue);
        expect(
          password
              .split('')
              .every((c) => (lowercaseChars + digitChars).contains(c)),
          isTrue,
        );
      }
    });

    test('deux mots de passe générés sont différents', () {
      final generated = {
        for (var i = 0; i < 100; i++)
          generatePassword(const GeneratorOptions()),
      };
      expect(generated.length, 100);
    });
  });

  group('Force du mot de passe', () {
    test('mots de passe faibles', () {
      for (final password in [
        '',
        'abc',
        'aaaaaaaaaaaaaaaa',
        'abababababababab',
        'motdepasse12',
        'azerty123456',
      ]) {
        expect(
          passwordStrength(password),
          PasswordStrength.faible,
          reason: password,
        );
      }
    });

    test('moyen et fort', () {
      expect(passwordStrength('jardinbleuvelo'), PasswordStrength.moyen);
      expect(passwordStrength('Jardin-Bleu-Velo-42'), PasswordStrength.fort);
      expect(
        passwordStrength(generatePassword(const GeneratorOptions())),
        PasswordStrength.fort,
      );
    });

    test('mot de passe maître : 12 caractères et au moins « moyen »', () {
      expect(isMasterPasswordAcceptable('Ab3!Ab3!Ab3'), isFalse); // 11
      expect(isMasterPasswordAcceptable('aaaaaaaaaaaaaa'), isFalse);
      expect(isMasterPasswordAcceptable('jardinbleuvelo'), isTrue);
    });
  });
}
