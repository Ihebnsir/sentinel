/// L'état de sécurité du téléphone, tel que renvoyé par Android.
/// Immuable : tous les champs sont « final », on ne les modifie jamais.
class DeviceSecurityStatus {
  const DeviceSecurityStatus({
    required this.screenLock,
    required this.biometricEnrolled,
    required this.rooted,
    required this.developerOptions,
    required this.usbDebugging,
    required this.encrypted,
    required this.androidVersion,
    required this.sdkInt,
    required this.securityPatch,
  });

  /// Construit l'objet à partir de la Map reçue du MethodChannel.
  /// Une valeur absente ou d'un mauvais type est traitée comme « non sécurisé ».
  factory DeviceSecurityStatus.fromMap(Map<Object?, Object?> map) {
    return DeviceSecurityStatus(
      screenLock: map['screenLock'] == true,
      biometricEnrolled: map['biometricEnrolled'] == true,
      rooted: map['rooted'] == true,
      developerOptions: map['developerOptions'] == true,
      usbDebugging: map['usbDebugging'] == true,
      encrypted: map['encrypted'] == true,
      androidVersion: map['androidVersion'] as String? ?? '',
      sdkInt: map['sdkInt'] as int? ?? 0,
      // Android envoie la date au format « 2026-08-05 ».
      securityPatch: DateTime.tryParse(map['securityPatch'] as String? ?? ''),
    );
  }

  final bool screenLock; // code, schéma ou mot de passe
  final bool biometricEnrolled; // empreinte ou visage enregistré
  final bool rooted; // root probable
  final bool developerOptions; // options pour les développeurs activées
  final bool usbDebugging; // débogage USB activé
  final bool encrypted; // stockage chiffré
  final String androidVersion; // ex : « 15 »
  final int sdkInt; // ex : 35
  final DateTime? securityPatch; // null si la date est inconnue
}
