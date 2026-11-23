/// « Partager mon Wi-Fi » : texte WIFI: à mettre dans un QR code.
/// Calcul pur, sans Flutter. Rien n'est enregistré.
library;

/// Protection choisie par l'utilisateur.
enum WifiShareSecurity { wpa, wep, none }

/// Pourquoi le QR code ne peut pas encore être créé.
enum WifiShareProblem { missingName, wpaPassword, wepPassword }

final _hex = RegExp(r'^[0-9A-Fa-f]+$');

/// Vérifie la saisie ; null si tout va bien.
WifiShareProblem? checkWifiShare(
  String ssid,
  String password,
  WifiShareSecurity security,
) {
  if (ssid.isEmpty) return WifiShareProblem.missingName;
  switch (security) {
    case WifiShareSecurity.wpa:
      // 8 à 63 caractères, ou la clé brute de 64 chiffres hexadécimaux.
      final ok =
          (password.length >= 8 && password.length <= 63) ||
          (password.length == 64 && _hex.hasMatch(password));
      return ok ? null : WifiShareProblem.wpaPassword;
    case WifiShareSecurity.wep:
      final ok =
          password.length == 5 ||
          password.length == 13 ||
          ((password.length == 10 || password.length == 26) &&
              _hex.hasMatch(password));
      return ok ? null : WifiShareProblem.wepPassword;
    case WifiShareSecurity.none:
      return null;
  }
}

// « \ » protège les caractères spéciaux du format : \ ; , : "
String _escape(String value) =>
    value.replaceAllMapped(RegExp(r'[\\;,:"]'), (m) => '\\${m[0]}');

/// WIFI:T:WPA;S:nom;P:mot de passe;H:true;;
/// (format lu par l'appareil photo d'Android et d'iPhone).
String buildWifiQr({
  required String ssid,
  required String password,
  required WifiShareSecurity security,
  bool hidden = false,
}) {
  final type = switch (security) {
    WifiShareSecurity.wpa => 'WPA',
    WifiShareSecurity.wep => 'WEP',
    WifiShareSecurity.none => 'nopass',
  };
  final buffer = StringBuffer('WIFI:T:$type;S:${_escape(ssid)};');
  if (security != WifiShareSecurity.none) {
    buffer.write('P:${_escape(password)};');
  }
  if (hidden) buffer.write('H:true;');
  buffer.write(';');
  return buffer.toString();
}
