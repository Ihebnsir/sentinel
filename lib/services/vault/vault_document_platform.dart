import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import 'vault_documents.dart';

/// Pourquoi un document n'a pas pu être pris ou choisi.
enum DocumentPickError {
  tropGros,
  typeRefuse,
  pasDeCamera,
  cameraRefusee,
  cameraBloquee, // « Ne plus demander » : seulement dans les réglages
  echec;

  String message(AppLocalizations l) => switch (this) {
    tropGros => l.vaultDocTooLarge,
    typeRefuse => l.vaultDocUnsupported,
    pasDeCamera => l.qrErrorNoCamera,
    cameraRefusee => l.vaultDocCameraDenied,
    cameraBloquee => l.qrErrorPermissionBlocked,
    echec => l.vaultDocPickFailed,
  };
}

class DocumentPickException implements Exception {
  const DocumentPickException(this.error);

  final DocumentPickError error;
}

/// Un document pris ou choisi, en mémoire seulement.
class PickedDocument {
  const PickedDocument(this.bytes, this.name);

  final Uint8List bytes;
  final String? name; // nom du fichier choisi (null pour une photo)
}

/// Photo, sélecteur, aperçu des PDF et partage (VaultMedia.kt), sur le
/// canal du coffre. Android seulement.
class VaultDocumentPlatform {
  // Même nom que dans VaultProtection.kt.
  static const _channel = MethodChannel('com.iheb.sentinel/vault');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Photo avec l'appareil photo d'Android ; null si annulé.
  static Future<PickedDocument?> capturePhoto() => _pick('capturePhoto');

  /// Image ou PDF choisi avec le sélecteur ; null si annulé.
  static Future<PickedDocument?> pickFile() => _pick('pickVaultDocument');

  static Future<PickedDocument?> _pick(String method) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(method, {
        'maxBytes': maxDocumentBytes,
      });
      final data = result?['data'];
      if (data is! Uint8List) return null;
      return PickedDocument(data, result?['name'] as String?);
    } on PlatformException catch (e) {
      throw DocumentPickException(switch (e.code) {
        'TROP_GROS' => DocumentPickError.tropGros,
        'TYPE' => DocumentPickError.typeRefuse,
        'NO_CAMERA' => DocumentPickError.pasDeCamera,
        'PERMISSION_DENIED' => DocumentPickError.cameraRefusee,
        'PERMISSION_BLOCKED' => DocumentPickError.cameraBloquee,
        _ => DocumentPickError.echec,
      });
    } on MissingPluginException {
      throw const DocumentPickException(DocumentPickError.echec);
    }
  }

  /// Ouvre un PDF en mémoire pour l'aperçu ; nombre de pages, ou null si
  /// l'aperçu est impossible (Android 10 et avant, PDF protégé…).
  static Future<int?> openPdf(Uint8List data) async {
    try {
      return await _channel.invokeMethod<int>('pdfOpen', {'data': data});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Une page du PDF ouvert, en PNG ; null en cas d'échec.
  static Future<Uint8List?> renderPdfPage(int index, int width) async {
    try {
      return await _channel.invokeMethod<Uint8List>('pdfPage', {
        'index': index,
        'width': width,
      });
    } on PlatformException {
      return null;
    }
  }

  static Future<void> closePdf() => _quiet('pdfClose');

  /// Ouvre le menu de partage d'Android. false si aucune app ne convient.
  static Future<bool> share(Uint8List data, String mime) async {
    try {
      return await _channel.invokeMethod<bool>('shareDocument', {
            'data': data,
            'mime': mime,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Oublie le document partagé (au verrouillage du coffre).
  static Future<void> clearShared() => _quiet('clearSharedDocument');

  static Future<void> _quiet(String method) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException {
      // rien à faire
    } on MissingPluginException {
      // rien à faire
    }
  }
}
