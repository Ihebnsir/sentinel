import 'package:flutter/foundation.dart';

import '../vault/vault_item.dart';
import 'breach_consent.dart';
import 'pwned_passwords.dart';

/// Vérification des fuites pour le coffre ouvert : accord de l'utilisateur,
/// progression, erreurs et résultats (en mémoire seulement).
class BreachChecker extends ChangeNotifier {
  BreachChecker({
    BreachConsentStore? consentStore,
    PwnedPasswordsClient? client,
  }) : _consentStore = consentStore ?? BreachConsentStore(),
       _client = client ?? PwnedPasswordsClient();

  final BreachConsentStore _consentStore;
  final PwnedPasswordsClient _client;

  bool _consent = false;
  bool get consent => _consent;

  bool _checking = false;
  bool get checking => _checking;

  int _done = 0;
  int _total = 0;

  /// Progression, ex : (3, 12).
  (int done, int total) get progress => (_done, _total);

  BreachCheckException? _error;

  /// Dernier message d'erreur en français (null si tout va bien).
  BreachCheckException? get error => _error;

  // Résultats par empreinte SHA-1 : effacés au verrouillage.
  final _counts = <String, int>{};

  // Change à chaque effacement : une analyse en cours est alors ignorée.
  int _generation = 0;

  Future<void> loadConsent() async {
    _consent = await _consentStore.read();
    notifyListeners();
  }

  /// Accepte ou retire l'accord. Retirer efface aussi les résultats.
  Future<void> setConsent(bool accepted) async {
    _consent = accepted;
    if (!accepted) clear();
    notifyListeners();
    await _consentStore.write(accepted);
  }

  /// Nombre de fois vu dans des fuites (0 : jamais), null si pas vérifié.
  int? countFor(String password) =>
      password.isEmpty ? null : _counts[sha1Hex(password)];

  /// Tout a été vérifié pour ces éléments.
  bool isUpToDate(List<VaultItem> items) =>
      _passwords(items).every((p) => countFor(p) != null);

  /// Vérifie les mots de passe pas encore vérifiés. Ne fait rien sans
  /// l'accord de l'utilisateur.
  Future<void> check(List<VaultItem> items) async {
    if (!_consent || _checking) return;
    final todo = [
      for (final p in _passwords(items))
        if (countFor(p) == null) p,
    ];
    if (todo.isEmpty) return;
    final generation = _generation;
    _checking = true;
    _error = null;
    _done = 0;
    _total = todo.length;
    notifyListeners();
    try {
      for (final password in todo) {
        final count = await _client.breachCount(password);
        if (generation != _generation) return; // verrouillé entre-temps
        _counts[sha1Hex(password)] = count;
        _done++;
        notifyListeners();
      }
    } on BreachCheckException catch (e) {
      if (generation == _generation) _error = e;
    } finally {
      _client.clearCache(); // le cache ne dure que le temps de l'analyse
      _checking = false;
      notifyListeners();
    }
  }

  /// Coffre verrouillé : on oublie tous les résultats.
  void clear() {
    _generation++;
    _counts.clear();
    _error = null;
    _done = 0;
    _total = 0;
    notifyListeners();
  }

  // Mots de passe distincts et non vides.
  static Set<String> _passwords(List<VaultItem> items) => {
    for (final item in items)
      if (item.type == VaultItemType.motDePasse && item.motDePasse.isNotEmpty)
        item.motDePasse,
  };

  @override
  void dispose() {
    _counts.clear();
    _client.close();
    super.dispose();
  }
}
