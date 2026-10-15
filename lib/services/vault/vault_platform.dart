import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Protections propres à Android pour le coffre, via MainActivity.kt.
/// Hors Android, seul le presse-papiers fonctionne (sans protection).
class VaultPlatform {
  // Même nom que dans MainActivity.kt.
  static const _channel = MethodChannel('com.iheb.sentinel/vault');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// FLAG_SECURE : pas de capture d'écran, aperçu masqué dans les apps
  /// récentes.
  static Future<void> setSecure(bool secure) async {
    if (!_isAndroid) return;
    await _invoke('setSecure', {'secure': secure});
  }

  /// Appelé quand l'écran s'éteint (donc se verrouille).
  static void onScreenOff(VoidCallback? callback) {
    if (!_isAndroid) return;
    _channel.setMethodCallHandler(
      callback == null
          ? null
          : (call) async {
              if (call.method == 'onScreenOff') callback();
            },
    );
  }

  /// Copie marquée « sensible » (Android 13+ : pas d'aperçu à l'écran).
  static Future<void> copySensitive(String text) async {
    if (_isAndroid && await _invoke('copySensitive', {'text': text})) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<void> clearClipboard() async {
    if (_isAndroid && await _invoke('clearClipboard')) return;
    await Clipboard.setData(const ClipboardData(text: ''));
  }

  // true si le code natif a répondu.
  static Future<bool> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      // Pas de détails : les arguments peuvent contenir un mot de passe.
      return false;
    }
  }
}

/// Vide le presse-papiers 30 s après une copie, s'il contient toujours
/// ce qu'on a copié (on n'efface pas ce que l'utilisateur a copié après).
class ClipboardGuard {
  static const delay = Duration(seconds: 30);

  Timer? _timer;
  String? _copied; // gardé en mémoire 30 s au plus
  bool _pending = false; // délai passé mais presse-papiers illisible

  Future<void> copy(String text) async {
    await VaultPlatform.copySensitive(text);
    _copied = text;
    _pending = false;
    _timer?.cancel();
    _timer = Timer(delay, _tryClear);
  }

  /// À appeler au retour dans l'app : Android interdit de lire le
  /// presse-papiers quand l'app est en arrière-plan.
  void retryIfPending() {
    if (_pending) _tryClear();
  }

  Future<void> _tryClear() async {
    final copied = _copied;
    if (copied == null) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final inBackground =
        SchedulerBinding.instance.lifecycleState != AppLifecycleState.resumed;
    if (data == null && inBackground) {
      _pending = true; // on réessaiera au retour
      return;
    }
    if (data?.text == copied) await VaultPlatform.clearClipboard();
    _forget();
  }

  void _forget() {
    _copied = null;
    _pending = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => _timer?.cancel();
}
