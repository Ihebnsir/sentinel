import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import 'qr_content.dart';
import 'qr_safety.dart';

/// Pourquoi le scan n'a pas abouti.
enum QrScanError {
  androidOnly,
  noCamera,
  permissionDenied, // refusée cette fois
  permissionBlocked, // « Ne plus demander » : à changer dans les réglages
  failed;

  String message(AppLocalizations l) => switch (this) {
    androidOnly => l.commonAndroidOnly,
    noCamera => l.qrErrorNoCamera,
    permissionDenied => l.qrErrorPermissionDenied,
    permissionBlocked => l.qrErrorPermissionBlocked,
    failed => l.qrErrorFailed,
  };
}

/// Réponse d'un scan : le texte lu, ou une erreur. Les deux à null : annulé.
class QrScanResult {
  const QrScanResult.text(String this.text) : error = null;
  const QrScanResult.error(QrScanError this.error) : text = null;
  const QrScanResult.cancelled() : text = null, error = null;

  final String? text;
  final QrScanError? error;
}

/// Fait le lien avec QrScanner.kt (ZXing, tout sur le téléphone).
class QrScannerService {
  // Même nom que dans QrScanner.kt.
  static const _channel = MethodChannel('com.iheb.sentinel/qr');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// La caméra est-elle déjà autorisée ? (sinon : expliquer avant le scan)
  Future<bool> hasCameraPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasCameraPermission') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Demande la caméra si besoin, puis ouvre l'écran de scan.
  /// [prompt] : phrase affichée sous le viseur.
  Future<QrScanResult> scan(String prompt) async {
    if (!isSupported) return const QrScanResult.error(QrScanError.androidOnly);
    try {
      final text = await _channel.invokeMethod<String>('scan', {
        'prompt': prompt,
      });
      return text == null
          ? const QrScanResult.cancelled()
          : QrScanResult.text(text);
    } on MissingPluginException {
      return const QrScanResult.error(QrScanError.androidOnly);
    } on PlatformException catch (e) {
      return QrScanResult.error(switch (e.code) {
        'NO_CAMERA' => QrScanError.noCamera,
        'PERMISSION_DENIED' => QrScanError.permissionDenied,
        'PERMISSION_BLOCKED' => QrScanError.permissionBlocked,
        _ => QrScanError.failed,
      });
    }
  }

  /// Lance l'action, déjà confirmée par l'utilisateur. Kotlin vérifie
  /// encore le contenu. false si refusé ou si aucune app ne sait l'ouvrir.
  Future<bool> perform(QrAssessment assessment) async {
    if (!isSupported || !assessment.actionAllowed) return false;
    final (method, arguments) = switch (assessment.content) {
      QrLink(:final url) => ('openLink', {'url': url}),
      QrPhone(:final number) => ('dial', {'number': number}),
      QrSms(:final number, :final body) => (
        'composeSms',
        {'number': number, 'body': body},
      ),
      QrPayment(:final uri?) => ('openPayment', {'uri': uri}),
      _ => (null, null),
    };
    if (method == null) return false;
    try {
      await _channel.invokeMethod<void>(method, arguments);
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
