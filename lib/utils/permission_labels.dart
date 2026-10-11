/// Libellés en français simple des permissions Android courantes.
/// La clé est le nom court, sans « android.permission. ».
const _labels = {
  // Messages et appels
  'READ_SMS': 'Lire vos SMS',
  'RECEIVE_SMS': 'Recevoir vos SMS',
  'SEND_SMS': 'Envoyer des SMS (parfois payants)',
  'RECEIVE_MMS': 'Recevoir des MMS',
  'READ_CALL_LOG': "Consulter l'historique des appels",
  'WRITE_CALL_LOG': "Modifier l'historique des appels",
  'CALL_PHONE': 'Passer des appels',
  'ANSWER_PHONE_CALLS': 'Répondre aux appels',
  'READ_PHONE_STATE': "Voir l'état du téléphone et des appels",
  'READ_PHONE_NUMBERS': 'Connaître votre numéro de téléphone',
  // Contacts, agenda, comptes
  'READ_CONTACTS': 'Lire vos contacts',
  'WRITE_CONTACTS': 'Modifier vos contacts',
  'GET_ACCOUNTS': 'Voir les comptes enregistrés sur le téléphone',
  'READ_CALENDAR': 'Lire votre agenda',
  'WRITE_CALENDAR': 'Modifier votre agenda',
  // Micro, caméra, capteurs
  'RECORD_AUDIO': 'Utiliser le micro',
  'CAMERA': "Utiliser l'appareil photo",
  'BODY_SENSORS': 'Lire les capteurs corporels (rythme cardiaque…)',
  'BODY_SENSORS_BACKGROUND': 'Lire les capteurs corporels en arrière-plan',
  'ACTIVITY_RECOGNITION': 'Détecter votre activité physique',
  // Position
  'ACCESS_FINE_LOCATION': 'Connaître votre position précise',
  'ACCESS_COARSE_LOCATION': 'Connaître votre position approximative',
  'ACCESS_BACKGROUND_LOCATION':
      "Connaître votre position même quand l'app est fermée",
  'ACCESS_MEDIA_LOCATION': 'Lire le lieu de prise de vos photos',
  // Fichiers et médias
  'READ_EXTERNAL_STORAGE': 'Lire vos fichiers',
  'WRITE_EXTERNAL_STORAGE': 'Modifier vos fichiers',
  'MANAGE_EXTERNAL_STORAGE': 'Accéder à tous vos fichiers',
  'READ_MEDIA_IMAGES': 'Voir vos photos',
  'READ_MEDIA_VIDEO': 'Voir vos vidéos',
  'READ_MEDIA_AUDIO': 'Accéder à vos fichiers audio',
  'READ_MEDIA_VISUAL_USER_SELECTED': 'Voir les photos que vous choisissez',
  // Appareils à proximité
  'BLUETOOTH': 'Utiliser le Bluetooth',
  'BLUETOOTH_CONNECT': 'Se connecter aux appareils Bluetooth',
  'BLUETOOTH_SCAN': 'Rechercher des appareils Bluetooth',
  'NEARBY_WIFI_DEVICES': 'Trouver les appareils Wi-Fi à proximité',
  'NFC': 'Utiliser le NFC (paiement sans contact…)',
  // Réseau
  'INTERNET': 'Accéder à internet',
  'ACCESS_NETWORK_STATE': "Voir l'état de la connexion",
  'ACCESS_WIFI_STATE': 'Voir les réseaux Wi-Fi',
  'CHANGE_WIFI_STATE': 'Activer ou couper le Wi-Fi',
  // Système
  'SYSTEM_ALERT_WINDOW': "S'afficher par-dessus les autres applications",
  'POST_NOTIFICATIONS': 'Afficher des notifications',
  'REQUEST_INSTALL_PACKAGES': "Proposer d'installer d'autres applications",
  'REQUEST_DELETE_PACKAGES': 'Proposer de désinstaller des applications',
  'QUERY_ALL_PACKAGES': 'Voir la liste de vos applications',
  'PACKAGE_USAGE_STATS': 'Voir quelles applications vous utilisez',
  'RECEIVE_BOOT_COMPLETED': 'Se lancer au démarrage du téléphone',
  'FOREGROUND_SERVICE': 'Fonctionner en continu en arrière-plan',
  'WAKE_LOCK': 'Empêcher la mise en veille',
  'VIBRATE': 'Faire vibrer le téléphone',
  'USE_BIOMETRIC': "Utiliser l'empreinte ou le visage",
  'USE_FINGERPRINT': "Utiliser l'empreinte digitale",
  'SCHEDULE_EXACT_ALARM': 'Programmer des alarmes précises',
  'USE_FULL_SCREEN_INTENT': 'Afficher des alertes en plein écran',
};

/// Libellé français d'une permission, ex : android.permission.CAMERA
/// → « Utiliser l'appareil photo ». Null si la permission est inconnue.
String? permissionLabel(String permission) {
  const prefix = 'android.permission.';
  if (!permission.startsWith(prefix)) return null;
  return _labels[permission.substring(prefix.length)];
}
