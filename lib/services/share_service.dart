import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/debug_log.dart';
import 'qr/qr_scanner_service.dart';

/// Un texte reçu d'une autre app.
/// Pas de == personnalisé : deux envois du même texte restent deux
/// objets différents, donc le ValueNotifier prévient à chaque fois.
class SharedText {
  const SharedText(this.text);

  final String text;
}

/// Reçoit le texte partagé depuis les autres apps (bouton « Partager »
/// ou menu « Vérifier le lien avec Sentinel »), via MainActivity.kt :
/// l'onglet Liens y cherche le premier lien. Reçoit aussi les demandes
/// d'ouverture du pare-feu (tuile des Paramètres rapides).
class ShareService {
  // Même nom que dans MainActivity.kt, sinon les messages se perdent.
  static const _channel = MethodChannel('com.iheb.sentinel/share');

  /// Dernier texte reçu (null tant que rien n'est arrivé).
  final ValueNotifier<SharedText?> received = ValueNotifier(null);

  /// QR codes lus dans la dernière image partagée (QR reçu sur WhatsApp,
  /// capture d'écran). L'image elle-même reste côté Android, jamais gardée.
  final ValueNotifier<QrImageResult?> receivedImage = ValueNotifier(null);

  /// Nombre de demandes « ouvrir le pare-feu » : +1 à chaque appui sur la
  /// tuile qui ne peut rien faire seule (autorisation VPN, DNS strict).
  final ValueNotifier<int> firewallRequests = ValueNotifier(0);

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Écoute les nouveaux textes et récupère celui du lancement.
  /// Ne fait rien hors Android (Windows, web…).
  Future<void> start() async {
    if (!_isAndroid) return;
    _channel.setMethodCallHandler(_onNativeCall);
    try {
      final text = await _channel.invokeMethod<Object?>('getInitialSharedText');
      if (text is String) _emit(text);
      if (_disposed) return; // écran fermé pendant l'attente
      _emitImage(await _channel.invokeMethod<Object?>('getInitialSharedImage'));
      if (_disposed) return;
      // Object? : une réponse inattendue est ignorée, sans erreur.
      final firewall = await _channel.invokeMethod<Object?>(
        'getInitialOpenFirewall',
      );
      if (firewall == true) _requestFirewall();
    } on MissingPluginException {
      // Aucun code natif n'écoute ce canal.
    } on PlatformException catch (e) {
      debugLog(() => 'Texte partagé illisible : ${e.message}');
    }
  }

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    if (_isAndroid) _channel.setMethodCallHandler(null);
    received.dispose();
    receivedImage.dispose();
    firewallRequests.dispose();
  }

  // Appelé par Kotlin quand un texte arrive, app déjà ouverte.
  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method == 'onSharedText') _emit(call.arguments as String?);
    if (call.method == 'onOpenFirewall') _requestFirewall();
    if (call.method == 'onSharedImage') _emitImage(call.arguments);
  }

  // Seulement une vraie réponse de QrImageReader.kt (une Map) : null ou
  // une valeur inattendue ne changent rien.
  void _emitImage(Object? answer) {
    if (_disposed || answer is! Map) return;
    receivedImage.value = QrImageResult.fromNative(answer);
  }

  void _requestFirewall() {
    if (_disposed) return;
    firewallRequests.value++;
  }

  void _emit(String? text) {
    // _disposed : la réponse peut arriver après la fermeture de l'écran.
    if (_disposed || text == null || text.trim().isEmpty) return;
    received.value = SharedText(text);
  }
}
