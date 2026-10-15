/// Les deux sortes d'éléments rangés dans le coffre.
enum VaultItemType {
  motDePasse('Mot de passe'),
  note('Note secrète');

  const VaultItemType(this.label);

  /// Nom affiché à l'utilisateur.
  final String label;
}

/// Un élément du coffre, tel qu'il est une fois déchiffré.
/// Ces objets ne quittent jamais la mémoire en clair : sur le disque,
/// seule la liste chiffrée est écrite.
class VaultItem {
  const VaultItem({
    required this.id,
    required this.type,
    required this.titre,
    this.identifiant = '',
    this.motDePasse = '',
    this.siteWeb = '',
    this.note = '',
    required this.creeLe,
    required this.modifieLe,
  });

  final String id;
  final VaultItemType type;
  final String titre;
  final String identifiant;
  final String motDePasse;
  final String siteWeb;
  final String note;
  final DateTime creeLe;
  final DateTime modifieLe;

  VaultItem copyWith({
    String? titre,
    String? identifiant,
    String? motDePasse,
    String? siteWeb,
    String? note,
    DateTime? modifieLe,
  }) {
    return VaultItem(
      id: id,
      type: type,
      titre: titre ?? this.titre,
      identifiant: identifiant ?? this.identifiant,
      motDePasse: motDePasse ?? this.motDePasse,
      siteWeb: siteWeb ?? this.siteWeb,
      note: note ?? this.note,
      creeLe: creeLe,
      modifieLe: modifieLe ?? this.modifieLe,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'titre': titre,
    'identifiant': identifiant,
    'motDePasse': motDePasse,
    'siteWeb': siteWeb,
    'note': note,
    'creeLe': creeLe.toUtc().toIso8601String(),
    'modifieLe': modifieLe.toUtc().toIso8601String(),
  };

  factory VaultItem.fromJson(Map<String, Object?> json) {
    return VaultItem(
      id: json['id'] as String,
      type: VaultItemType.values.byName(json['type'] as String),
      titre: json['titre'] as String,
      identifiant: json['identifiant'] as String? ?? '',
      motDePasse: json['motDePasse'] as String? ?? '',
      siteWeb: json['siteWeb'] as String? ?? '',
      note: json['note'] as String? ?? '',
      creeLe: DateTime.parse(json['creeLe'] as String),
      modifieLe: DateTime.parse(json['modifieLe'] as String),
    );
  }

  // Volontairement sans le contenu : un print accidentel ne révèle rien.
  @override
  String toString() => 'VaultItem($id, ${type.name})';
}
