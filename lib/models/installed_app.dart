import 'package:flutter/foundation.dart';

/// Une application installée, telle que décrite par Android.
/// Immuable : tous les champs sont « final », on ne les modifie jamais.
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    required this.icon,
    required this.isSystemApp,
    required this.installerPackage,
    required this.versionName,
    required this.firstInstallTime,
    required this.lastUpdateTime,
    required this.targetSdk,
    required this.grantedPermissions,
    required this.requestsOverlay,
    required this.accessibilityServiceEnabled,
    required this.notificationListenerEnabled,
    required this.isDeviceAdmin,
  });

  /// Le package du Play Store.
  static const playStorePackage = 'com.android.vending';

  /// Boutiques officielles reconnues : package de l'installateur → nom affiché.
  static const officialStores = {
    playStorePackage: 'Play Store',
    'com.huawei.appmarket': 'AppGallery',
    'com.sec.android.app.samsungapps': 'Galaxy Store',
    'com.xiaomi.market': 'GetApps (Xiaomi)',
    'com.xiaomi.mipicks': 'GetApps (Xiaomi)',
  };

  /// Construit l'objet à partir d'une Map reçue du MethodChannel.
  /// Une valeur absente prend une valeur neutre (false, null, liste vide).
  factory InstalledApp.fromMap(Map<Object?, Object?> map) {
    final icon = map['icon'];
    final permissions = map['grantedPermissions'];
    final packageName = map['packageName'] as String? ?? '';
    return InstalledApp(
      packageName: packageName,
      // Sans nom lisible, on affiche le nom technique.
      label: map['label'] as String? ?? packageName,
      // Android envoie un ByteArray, reçu en Dart comme Uint8List.
      icon: icon is Uint8List ? icon : null,
      isSystemApp: map['isSystemApp'] == true,
      installerPackage: map['installerPackage'] as String?,
      versionName: map['versionName'] as String?,
      firstInstallTime: _dateFrom(map['firstInstallTime']),
      lastUpdateTime: _dateFrom(map['lastUpdateTime']),
      targetSdk: map['targetSdk'] as int? ?? 0,
      grantedPermissions: List.unmodifiable(
        permissions is List ? permissions.whereType<String>() : const [],
      ),
      requestsOverlay: map['requestsOverlay'] == true,
      accessibilityServiceEnabled: map['accessibilityServiceEnabled'] == true,
      notificationListenerEnabled: map['notificationListenerEnabled'] == true,
      isDeviceAdmin: map['isDeviceAdmin'] == true,
    );
  }

  final String packageName; // ex : « com.whatsapp »
  final String label; // nom affiché, ex : « WhatsApp »
  final Uint8List? icon; // image PNG 96x96, null si indisponible
  final bool isSystemApp; // préinstallée sur le téléphone
  final String? installerPackage; // qui l'a installée, null si inconnu
  final String? versionName; // ex : « 2.24.1 »
  final DateTime? firstInstallTime;
  final DateTime? lastUpdateTime;
  final int targetSdk; // version d'Android visée, 0 si inconnue
  final List<String> grantedPermissions; // ex : android.permission.CAMERA
  final bool requestsOverlay; // demande à s'afficher par-dessus les autres apps
  final bool accessibilityServiceEnabled; // service d'accessibilité activé
  final bool notificationListenerEnabled; // lit les notifications
  final bool isDeviceAdmin; // administrateur de l'appareil

  /// Installée depuis le Play Store.
  bool get isFromPlayStore => installerPackage == playStorePackage;

  /// Nom de la boutique officielle qui l'a installée, null sinon.
  String? get storeName => officialStores[installerPackage];

  /// Installée depuis une boutique officielle (Play Store compris).
  bool get isFromOfficialStore => storeName != null;

  /// Vrai si la permission (nom complet) a été accordée.
  bool hasPermission(String permission) =>
      grantedPermissions.contains(permission);
}

/// Android envoie les dates en millisecondes depuis 1970 ; 0 = inconnue.
DateTime? _dateFrom(Object? value) {
  if (value is! int || value <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(value);
}
