import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../utils/debug_log.dart';
import 'vault_biometrics.dart';
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

/// Résultat d'une tentative d'ouverture par empreinte.
enum BiometricUnlockResult {
  ouvert,
  annule, // l'utilisateur préfère le mot de passe
  motDePasseExige, // dernière ouverture par mot de passe > 7 jours
  empreintesChangees, // clé invalidée : réactiver après le mot de passe
  bloque, // trop d'essais
  indisponible,
  echec,
}

/// L'état du coffre pour toute l'app : verrouillé ou non, les éléments
/// déchiffrés, la DEK en mémoire, les échecs de mot de passe.
class VaultSession extends ChangeNotifier {
  VaultSession({
    VaultStorage? storage,
    VaultBiometrics? biometrics,
    this.kdfForNewVault,
    DateTime Function()? clock,
  }) : _storage = storage ?? VaultStorage(),
       _biometrics = biometrics ?? const AndroidVaultBiometrics(),
       _clock = clock ?? DateTime.now;

  final VaultStorage _storage;
  final VaultBiometrics _biometrics;
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

  bool _biometricsAvailable = false;
  bool _biometricBroken = false; // clé Keystore invalidée ou absente
  String? _pendingRecoveryKey;
  bool _offerRecoveryKey = false;

  /// Un capteur d'empreinte utilisable (jamais sur Windows).
  bool get biometricsAvailable => _biometricsAvailable;

  /// L'empreinte est activée et sa clé est encore valable.
  bool get biometricEnabled =>
      _file?.biometricSlot != null && !_biometricBroken;

  /// Les empreintes du téléphone ont changé depuis l'activation.
  bool get biometricBroken => _biometricBroken;

  /// Empreinte activée, mais mot de passe exigé (plus de 7 jours).
  bool get biometricNeedsPassword =>
      _biometricsAvailable &&
      biometricEnabled &&
      (_file?.needsPassword(_clock()) ?? true);

  /// L'écran de déverrouillage peut proposer l'empreinte.
  bool get canUnlockWithBiometrics =>
      _status == VaultStatus.verrouille &&
      _biometricsAvailable &&
      biometricEnabled &&
      !biometricNeedsPassword;

  /// Le coffre a une clé de récupération (pas forcément les vieux coffres).
  bool get hasRecoveryKey => _file?.recoverySlot != null;

  /// Clé de récupération à montrer UNE fois, puis oubliée.
  String? get pendingRecoveryKey => _pendingRecoveryKey;

  /// Coffre migré sans clé de récupération : on la propose une fois.
  bool get offerRecoveryKey => _offerRecoveryKey;

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
    _biometricsAvailable = await _biometrics.isAvailable();
    try {
      _file = await _storage.read();
      _setStatus(_file == null ? VaultStatus.absent : VaultStatus.verrouille);
    } on VaultFormatException {
      _setStatus(VaultStatus.illisible);
    }
  }

  /// Crée un coffre vide, l'ouvre, et prépare la clé de récupération.
  Future<void> create(String password) async {
    final created = await createVault(
      password,
      kdf: kdfForNewVault?.call(),
      now: _clock(),
    );
    await _storage.write(created.file);
    _file = created.file;
    _dek = created.dek;
    _items = const [];
    _biometricBroken = false;
    _pendingRecoveryKey = created.recoveryKey;
    _setStatus(VaultStatus.ouvert);
  }

  /// Restaure une sauvegarde lue par [readBackup] : coffre neuf (nouvelle
  /// DEK, nouveau mot de passe maître, nouvelle clé de récupération).
  Future<void> restore(List<VaultItem> items, String newPassword) async {
    if (_status != VaultStatus.absent) throw StateError('Coffre existant');
    final created = await createVault(
      newPassword,
      items: items,
      kdf: kdfForNewVault?.call(),
      now: _clock(),
    );
    await _storage.write(created.file);
    _file = created.file;
    _biometricBroken = false;
    _pendingRecoveryKey = created.recoveryKey;
    _opened(created.dek, items);
  }

  /// Déchiffre une sauvegarde (Argon2, dans un isolate). Lève
  /// [BackupFormatException] ou [WrongPasswordException].
  Future<List<VaultItem>> readBackup(Uint8List bytes, String password) =>
      importBackup(bytes, password);

  /// Le contenu du coffre ouvert, chiffré par [password] (fichier .sentinel).
  Future<Uint8List> createBackup(String password) async {
    if (_status != VaultStatus.ouvert) throw StateError('Coffre verrouillé');
    return exportBackup(_items, password, kdf: kdfForNewVault?.call());
  }

  /// Essaie d'ouvrir le coffre. Après un échec, impose un délai croissant.
  /// Note la date (règle des 7 jours) et migre un coffre v1 en v2.
  Future<UnlockResult> unlock(String password) async {
    final file = _file;
    if (file == null) return UnlockResult.incorrect;
    if (remainingWait > Duration.zero) return UnlockResult.attendre;
    try {
      final opening = await openWithPassword(
        password,
        file,
        now: _clock(),
        dropBiometric: _biometricBroken,
      );
      // Écriture atomique : en cas d'échec, l'ancien fichier reste
      // lisible, et le prochain enregistrement réessaiera.
      await _tryWrite(opening.file);
      _file = opening.file;
      if (_biometricBroken) {
        _biometricBroken = false;
        await _biometrics.deleteKey(); // déjà invalidée : on fait le ménage
      }
      if (opening.migrated && opening.file.recoverySlot == null) {
        _offerRecoveryKey = true;
      }
      _opened(opening.dek, opening.items);
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

  /// Ouvre avec l'empreinte (Android). Si la clé est invalidée, l'empreinte
  /// est désactivée : l'emplacement sera retiré à la prochaine ouverture
  /// par mot de passe (il faut la DEK pour resceller l'en-tête).
  Future<BiometricUnlockResult> unlockWithBiometrics() async {
    final file = _file;
    final slot = file?.biometricSlot;
    if (file == null || slot == null || !_biometricsAvailable) {
      return BiometricUnlockResult.indisponible;
    }
    if (_biometricBroken) return BiometricUnlockResult.empreintesChangees;
    if (file.needsPassword(_clock())) {
      return BiometricUnlockResult.motDePasseExige;
    }
    final Uint8List dek;
    try {
      dek = await _biometrics.decrypt(slot.wrappedKey, file.aadOf(slot));
    } on BiometricException catch (e) {
      if (e.error == BiometricError.invalidee) {
        _biometricBroken = true;
        notifyListeners();
      }
      return switch (e.error) {
        BiometricError.invalidee => BiometricUnlockResult.empreintesChangees,
        BiometricError.annulee => BiometricUnlockResult.annule,
        BiometricError.bloquee => BiometricUnlockResult.bloque,
        BiometricError.indisponible => BiometricUnlockResult.indisponible,
        BiometricError.echec => BiometricUnlockResult.echec,
      };
    }
    // Verrouillé ou remplacé pendant la fenêtre d'empreinte.
    if (_file != file || _status != VaultStatus.verrouille) {
      wipe(dek);
      return BiometricUnlockResult.annule;
    }
    try {
      _opened(dek, await openItems(dek, file));
      return BiometricUnlockResult.ouvert;
    } on VaultCorruptedException {
      wipe(dek);
      _setStatus(VaultStatus.illisible);
      return BiometricUnlockResult.echec;
    }
  }

  /// La clé de récupération saisie est-elle la bonne ? (HKDF : instantané)
  Future<bool> recoveryKeyMatches(String input) async {
    final file = _file;
    if (file == null) return false;
    try {
      wipe(await unwrapWithRecoveryKey(input, file));
      return true;
    } on WrongRecoveryKeyException {
      return false;
    }
  }

  /// « Mot de passe oublié » : ouvre avec la clé de récupération, remplace
  /// le mot de passe et génère une NOUVELLE clé (l'ancienne ne marche plus).
  Future<bool> recover(String recoveryInput, String newPassword) async {
    final file = _file;
    if (file == null) return false;
    try {
      final reset = await resetWithRecoveryKey(
        recoveryInput,
        newPassword,
        file,
        kdf: kdfForNewVault?.call(),
        now: _clock(),
      );
      await _storage.write(reset.file);
      _file = reset.file;
      _pendingRecoveryKey = reset.recoveryKey;
      _offerRecoveryKey = false;
      _opened(reset.dek, reset.items);
      return true;
    } on WrongRecoveryKeyException {
      return false;
    } on VaultCorruptedException {
      _setStatus(VaultStatus.illisible);
      return false;
    }
  }

  /// Change le mot de passe maître. false si l'ancien est faux.
  Future<bool> changeMasterPassword(
    String oldPassword,
    String newPassword,
  ) async {
    try {
      await _update(
        (dek, file) => changePassword(
          oldPassword,
          newPassword,
          file,
          dek,
          kdf: kdfForNewVault?.call(),
          now: _clock(),
        ),
      );
      return true;
    } on WrongPasswordException {
      return false;
    }
  }

  /// Génère une nouvelle clé de récupération (à montrer une fois).
  Future<void> createRecoveryKey() async {
    String? key;
    await _update((dek, file) async {
      final (next, newKey) = await replaceRecoveryKey(dek, file);
      key = newKey;
      return next;
    });
    _pendingRecoveryKey = key;
    _offerRecoveryKey = false;
    notifyListeners();
  }

  /// L'utilisateur a noté la clé : on l'oublie.
  void recoveryKeyNoted() {
    _pendingRecoveryKey = null;
    notifyListeners();
  }

  /// « Plus tard » : la proposition ne revient pas.
  void declineRecoveryKeyOffer() {
    _offerRecoveryKey = false;
    notifyListeners();
  }

  /// Active (empreinte demandée) ou désactive l'ouverture par empreinte.
  /// Lève [BiometricException] si l'empreinte n'a pas abouti.
  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      await _update((dek, file) async {
        final aad = KeySlot.aadFor(BiometricSlot.staticParams);
        final blob = await _biometrics.encrypt(dek, aad);
        return reseal(
          dek,
          file,
          file.withSlot(BiometricSlot(wrappedKey: blob)),
        );
      });
      _biometricBroken = false;
    } else {
      await _update(
        (dek, file) => reseal(dek, file, file.withoutBiometricSlot()),
      );
      _biometricBroken = false;
      await _biometrics.deleteKey();
    }
    notifyListeners();
  }

  /// Supprime le coffre et la clé Keystore. Irréversible.
  Future<void> deleteVault() async {
    lock();
    await _storage.delete();
    await _biometrics.deleteKey();
    _file = null;
    _biometricBroken = false;
    _offerRecoveryKey = false;
    _failures = 0;
    _retryAt = null;
    _setStatus(VaultStatus.absent);
  }

  /// Ferme le coffre : la clé est effacée, la liste oubliée.
  void lock() {
    final dek = _dek;
    if (dek != null) wipe(dek);
    _dek = null;
    _items = const [];
    _pendingRecoveryKey = null; // secret : jamais gardé après verrouillage
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
    await _update((dek, file) => sealItems(dek, file, items));
    // Verrouillé entre-temps : on ne remet pas la liste en mémoire.
    if (_dek != null) _items = _sorted(items);
    notifyListeners();
  }

  // Calcule un nouveau fichier avec la DEK, l'écrit, puis le garde.
  Future<void> _update(
    Future<VaultFile> Function(Uint8List dek, VaultFile file) change,
  ) async {
    final dek = _dek;
    final file = _file;
    if (dek == null || file == null) throw StateError('Coffre verrouillé');
    // Copie : un verrouillage pendant l'écriture efface _dek, et l'on
    // chiffrerait alors avec une clé remplie de zéros.
    final key = Uint8List.fromList(dek);
    try {
      final next = await change(key, file);
      await _storage.write(next);
      _file = next;
    } finally {
      wipe(key);
    }
  }

  void _opened(Uint8List dek, List<VaultItem> items) {
    _failures = 0;
    _retryAt = null;
    _dek = dek;
    _items = _sorted(items);
    _setStatus(VaultStatus.ouvert);
  }

  Future<void> _tryWrite(VaultFile file) async {
    try {
      await _storage.write(file);
    } on FileSystemException {
      // Jamais le contenu ni le chemin dans les journaux.
      debugLog(() => 'Coffre : écriture reportée');
    }
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
