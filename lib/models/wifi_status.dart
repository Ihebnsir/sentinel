/// Le type de protection d'un réseau Wi-Fi.
/// Le nom (ex : « wpa2 ») est celui envoyé par WifiSecurityChecker.kt.
enum WifiSecurity {
  open('Aucune (réseau ouvert)'),
  owe('Enhanced Open (OWE)'),
  wep('WEP'),
  wpa('WPA'),
  wpa2('WPA2 ou WPA'),
  wpa3('WPA3'),
  enterprise('Entreprise (WPA2 / WPA3)'),
  unknown('Inconnue');

  const WifiSecurity(this.label);

  final String label; // texte affiché dans les détails

  /// Retrouve la valeur à partir du texte Android ; inconnu sinon.
  static WifiSecurity fromName(Object? name) => WifiSecurity.values.firstWhere(
    (s) => s.name == name,
    orElse: () => WifiSecurity.unknown,
  );
}

/// L'état du Wi-Fi actuel, tel que renvoyé par Android.
/// Ne contient jamais le nom du réseau (pas de localisation).
class WifiStatus {
  const WifiStatus({
    required this.connected,
    this.security = WifiSecurity.unknown,
    this.captivePortal = false,
    this.privateDnsActive,
    this.sdkInt = 0,
  });

  /// Construit l'objet à partir de la Map reçue du MethodChannel.
  factory WifiStatus.fromMap(Map<Object?, Object?> map) {
    final dns = map['privateDnsActive'];
    return WifiStatus(
      connected: map['connected'] == true,
      security: WifiSecurity.fromName(map['security']),
      captivePortal: map['captivePortal'] == true,
      privateDnsActive: dns is bool ? dns : null,
      sdkInt: map['sdkInt'] as int? ?? 0,
    );
  }

  final bool connected; // connecté à un Wi-Fi
  final WifiSecurity security; // type de protection
  final bool captivePortal; // page de connexion (hôtel, gare…)
  final bool? privateDnsActive; // null : inconnu (Android 8 et avant)
  final int sdkInt; // version d'Android, ex : 35
}
