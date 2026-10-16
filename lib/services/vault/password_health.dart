import '../../utils/french_number.dart';
import 'password_strength.dart';
import 'vault_item.dart';

/// Bilan des mots de passe du coffre : fuites, réutilisés, faibles.
class PasswordHealthReport {
  const PasswordHealthReport({
    required this.breached,
    required this.reused,
    required this.weak,
    required this.breachCounts,
    required this.reusedWith,
  });

  /// Trouvés dans des fuites, du plus vu au moins vu.
  final List<VaultItem> breached;

  /// Le même mot de passe sert dans plusieurs éléments.
  final List<VaultItem> reused;

  /// Jugés « faibles » par password_strength.dart.
  final List<VaultItem> weak;

  /// Nombre de fois vu dans des fuites, par id d'élément (si > 0).
  final Map<String, int> breachCounts;

  /// Pour chaque élément réutilisé : les titres des autres éléments.
  final Map<String, List<String>> reusedWith;

  /// Nombre d'éléments à corriger (chacun compté une seule fois).
  int get toFix => {
    for (final item in [...breached, ...reused, ...weak]) item.id,
  }.length;
}

/// Analyse locale, sans réseau. [breachCount] renvoie le nombre de fois où
/// un mot de passe a été vu dans des fuites, ou null s'il n'a pas été vérifié.
PasswordHealthReport analyzePasswordHealth(
  List<VaultItem> items, {
  int? Function(String password)? breachCount,
}) {
  final passwords = [
    for (final item in items)
      if (item.type == VaultItemType.motDePasse && item.motDePasse.isNotEmpty)
        item,
  ];

  // Regroupe les éléments par mot de passe (comparaison en mémoire).
  final groups = <String, List<VaultItem>>{};
  for (final item in passwords) {
    groups.putIfAbsent(item.motDePasse, () => []).add(item);
  }
  final reusedWith = <String, List<String>>{};
  for (final group in groups.values) {
    if (group.length < 2) continue;
    for (final item in group) {
      reusedWith[item.id] = [
        for (final other in group)
          if (other.id != item.id) other.titre,
      ];
    }
  }

  final breachCounts = <String, int>{};
  for (final item in passwords) {
    final count = breachCount?.call(item.motDePasse);
    if (count != null && count > 0) breachCounts[item.id] = count;
  }

  return PasswordHealthReport(
    breached: [
      for (final item in passwords)
        if (breachCounts.containsKey(item.id)) item,
    ]..sort((a, b) => breachCounts[b.id]!.compareTo(breachCounts[a.id]!)),
    reused: [
      for (final item in passwords)
        if (reusedWith.containsKey(item.id)) item,
    ],
    weak: [
      for (final item in passwords)
        if (passwordStrength(item.motDePasse) == PasswordStrength.faible) item,
    ],
    breachCounts: breachCounts,
    reusedWith: reusedWith,
  );
}

// Le nombre renvoyé par Have I Been Pwned compte les fois où le mot de
// passe a été vu, pas le nombre de fuites. « fois » est invariable.

/// « Ce mot de passe a été vu 3 861 fois dans des fuites de données.
/// Changez-le. »
String breachMessage(int count) =>
    'Ce mot de passe a été vu ${formatFrenchNumber(count)} fois dans des '
    'fuites de données. Changez-le.';

/// Version courte pour les listes : « Vu 3 861 fois dans des fuites ».
String breachShort(int count) =>
    'Vu ${formatFrenchNumber(count)} fois dans des fuites';
