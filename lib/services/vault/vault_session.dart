import 'dart:math';

import 'package:flutter/foundation.dart';

import 'vault_crypto.dart';
import 'vault_file.dart';
import 'vault_item.dart';
import 'vault_storage.dart';

/// Où en est le coffre.
enum VaultStatus {
  chargement, // lecture du fichier
  absent, // pas encore de coffre
  verrouille,
  ouvert,
  illisible, // fichier abîmé
}

/// Résultat d'une tentative d'ouverture.
enum UnlockResult { ouvert, incorrect, attendre }

/// L'état du coffre pour toute l'app : verrouillé ou non, les éléments
/// déchiffrés, la DEK en mémoire, les échecs de mot de passe.
class VaultSession extends ChangeNotifier {
  VaultSession({
    VaultStorage? storage,
    this.kdfForNewVault,
    DateTime Function()? clock,
  }) : _storage = storage ?? VaultStorage(),
       _clock = clock ?? DateTime.now;

  final VaultStorage _storage;
  final DateTime Function() _clock;

  /// Paramètres Argon2id imposés (tests) ; sinon ceux par défaut.
  final KdfParams Function()? kdfForNewVault;

  VaultStatus _status = VaultStatus.chargement;
  VaultStatus get status => _status;

  VaultFile? _file;
  Uint8List? _dek; // clé du coffre, seulement quand il est ouvert
  List<VaultItem> _items = const [];

  /// Éléments triés par titre (vide si verrouillé).
  List<VaultItem> get items => _items;

  int _failures = 0;
  DateTime? _retryAt;

  /// Temps restant avant de pouvoir réessayer (zéro si on peut).
  Duration get remainingWait {
    final retryAt = _retryAt;
    if (retryAt == null) return Duration.zero;
    final left = retryAt.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  /// Délai après le n-ième échec : 1 s, 2 s, 4 s… plafonné à 30 s.
  static Duration delayAfterFailures(int failures) {
    if (failures <= 0) return Duration.zero;
    return Duration(seconds: min(1 << min(failures - 1, 5), 30));
  }

  /// Regarde si un coffre existe déjà.
  Future<void> load() async {
    try {
      _file = await _storage.read();
      _setStatus(_file == null ? VaultStatus.absent : VaultStatus.verrouille);
    } on VaultFormatException {
      _setStatus(VaultStatus.illisible);
    }
  }

  /// Crée un coffre vide et l'ouvre.
  Future<void> create(String password) async {
    final opened = await createVault(password, kdf: kdfForNewVault?.call());
    await _storage.write(opened.file);
    _file = opened.file;
    _dek = opened.dek;
    _items = const [];
    _setStatus(VaultStatus.ouvert);
  }

  /// Essaie d'ouvrir le coffre. Après un échec, impose un délai croissant.
  Future<UnlockResult> unlock(String password) async {
    final file = _file;
    if (file == null) return UnlockResult.incorrect;
    if (remainingWait > Duration.zero) return UnlockResult.attendre;
    try {
      final dek = await unwrapKey(password, file);
      final items = await openItems(dek, file);
      _failures = 0;
      _retryAt = null;
      _dek = dek;
      _items = _sorted(items);
      _setStatus(VaultStatus.ouvert);
      return UnlockResult.ouvert;
    } on WrongPasswordException {
      _failures++;
      _retryAt = _clock().add(delayAfterFailures(_failures));
      notifyListeners();
      return UnlockResult.incorrect;
    } on VaultCorruptedException {
      _setStatus(VaultStatus.illisible);
      return UnlockResult.incorrect;
    }
  }

  /// Ferme le coffre : la clé est effacée, la liste oubliée.
  void lock() {
    final dek = _dek;
    if (dek != null) wipe(dek);
    _dek = null;
    _items = const [];
    if (_status == VaultStatus.ouvert) _setStatus(VaultStatus.verrouille);
  }

  /// Ajoute ou remplace un élément puis réécrit le coffre chiffré.
  Future<void> save(VaultItem item) async {
    final updated = [
      for (final existing in _items)
        if (existing.id != item.id) existing,
      item,
    ];
    await _persist(updated);
  }

  Future<void> delete(String id) async {
    await _persist([
      for (final item in _items)
        if (item.id != id) item,
    ]);
  }

  Future<void> _persist(List<VaultItem> items) async {
    final dek = _dek;
    final file = _file;
    if (dek == null || file == null) throw StateError('Coffre verrouillé');
    // Copie : un verrouillage pendant l'écriture efface _dek, et l'on
    // chiffrerait alors avec une clé remplie de zéros.
    final key = Uint8List.fromList(dek);
    try {
      final sealed = await sealItems(key, file, items);
      await _storage.write(sealed);
      _file = sealed;
    } finally {
      wipe(key);
    }
    // Verrouillé entre-temps : on ne remet pas la liste en mémoire.
    if (_dek != null) _items = _sorted(items);
    notifyListeners();
  }

  static List<VaultItem> _sorted(List<VaultItem> items) => [...items]
    ..sort((a, b) => a.titre.toLowerCase().compareTo(b.titre.toLowerCase()));

  void _setStatus(VaultStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    lock();
    super.dispose();
  }
}
