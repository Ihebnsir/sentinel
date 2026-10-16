import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/services/vault/password_health.dart';
import 'package:sentinel/services/vault/vault_item.dart';
import 'package:sentinel/utils/french_number.dart';

VaultItem _item(
  String id,
  String password, {
  VaultItemType type = VaultItemType.motDePasse,
}) => VaultItem(
  id: id,
  type: type,
  titre: 'Titre $id',
  motDePasse: password,
  creeLe: DateTime(2026),
  modifieLe: DateTime(2026),
);

const _strong = 'Vq7#mZ2!pL9@xR4&kT';

void main() {
  test('réutilisés : même mot de passe dans plusieurs éléments', () {
    final report = analyzePasswordHealth([
      _item('a', _strong),
      _item('b', _strong),
      _item('c', 'Hy8%nB3^wQ6*sD1(fG'),
    ]);
    expect(report.reused.map((i) => i.id), ['a', 'b']);
    expect(report.reusedWith['a'], ['Titre b']);
    expect(report.reusedWith['b'], ['Titre a']);
    expect(report.reusedWith.containsKey('c'), isFalse);
  });

  test('faibles : password_strength.dart', () {
    final report = analyzePasswordHealth([
      _item('a', 'azerty123'),
      _item('b', _strong),
    ]);
    expect(report.weak.map((i) => i.id), ['a']);
  });

  test('notes et mots de passe vides ignorés', () {
    final report = analyzePasswordHealth([
      _item('a', ''),
      _item('b', ''),
      _item('n', 'azerty', type: VaultItemType.note),
    ]);
    expect(report.reused, isEmpty);
    expect(report.weak, isEmpty);
    expect(report.toFix, 0);
  });

  test('fuites : triées, non vérifié ou 0 = absent', () {
    final counts = {'p1': 12, 'p2': 3861, 'p3': 0};
    final report = analyzePasswordHealth([
      _item('a', 'p1'),
      _item('b', 'p2'),
      _item('c', 'p3'),
      _item('d', 'jamais-vérifié'),
    ], breachCount: (p) => counts[p]);
    expect(report.breached.map((i) => i.id), ['b', 'a']);
    expect(report.breachCounts, {'a': 12, 'b': 3861});
  });

  test('à corriger : chaque élément compté une fois', () {
    // « a » est faible, réutilisé et dans une fuite : compté une fois.
    final report = analyzePasswordHealth([
      _item('a', 'azerty'),
      _item('b', 'azerty'),
      _item('c', _strong),
    ], breachCount: (p) => p == 'azerty' ? 100 : 0);
    expect(report.toFix, 2);
  });

  test('nombres et messages en français', () {
    expect(formatFrenchNumber(7), '7');
    expect(formatFrenchNumber(3861), '3 861');
    expect(formatFrenchNumber(1234567), '1 234 567');
    expect(
      breachMessage(3861),
      'Ce mot de passe a été vu 3 861 fois dans des fuites de données. '
      'Changez-le.',
    );
    expect(
      breachMessage(1),
      'Ce mot de passe a été vu 1 fois dans des fuites de données. '
      'Changez-le.',
    );
    expect(breachShort(12), 'Vu 12 fois dans des fuites');
    expect(breachShort(1), 'Vu 1 fois dans des fuites');
  });
}
