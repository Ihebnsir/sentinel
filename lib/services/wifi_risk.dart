import '../models/wifi_status.dart';

/// Le niveau de sécurité du Wi-Fi, du pire au meilleur.
enum WifiLevel {
  danger('Danger'),
  faible('Faible'),
  correct('Correct'),
  excellent('Excellent'),
  pasDeWifi('Aucun'),
  inconnu('Inconnu');

  const WifiLevel(this.label);

  final String label; // texte court affiché en couleur
}

/// Le résultat de l'analyse du Wi-Fi, prêt à afficher.
class WifiReport {
  const WifiReport({
    required this.level,
    required this.title,
    required this.summary,
    required this.explanation,
    this.advice = const [],
    this.suggestPrivateDns = false,
  });

  final WifiLevel level;
  final String title; // ex : « Wi-Fi ouvert »
  final String summary; // une phrase courte pour l'accueil
  final String explanation; // texte complet pour les détails
  final List<String> advice; // conseils, dans l'ordre
  final bool suggestPrivateDns; // afficher le bouton « DNS privé »
}

// Conseils réutilisés.
const _noBanking = 'Évitez la banque et les achats sur ce réseau';
const _useMobile = 'Utilisez plutôt les données mobiles';
const _upgradeBox =
    "Si c'est votre box, choisissez WPA2 ou WPA3 dans ses réglages";

/// Calcule le niveau et les conseils. Fonction « pure » : même entrée,
/// même résultat, sans appel à Android, donc facile à tester.
WifiReport assessWifi(WifiStatus status) {
  if (!status.connected) {
    return const WifiReport(
      level: WifiLevel.pasDeWifi,
      title: 'Pas de Wi-Fi',
      summary: "Vous n'êtes connecté à aucun Wi-Fi.",
      explanation:
          "Vous n'êtes connecté à aucun Wi-Fi : rien à vérifier "
          'pour le moment.',
    );
  }

  final base = _bySecurity(status);
  var level = base.level;
  var title = base.title;
  var summary = base.summary;
  final explanation = [base.explanation];
  final advice = [...base.advice];

  // Page de connexion : réseau public partagé, au mieux « faible ».
  if (status.captivePortal) {
    if (level != WifiLevel.danger) {
      level = WifiLevel.faible;
      title = 'Wi-Fi public';
      summary = 'Réseau partagé avec une page de connexion.';
    }
    explanation.add(
      'Ce réseau demande de se connecter sur une page '
      '(hôtel, gare, café…). Beaucoup de personnes le partagent.',
    );
    advice.add(
      "N'utilisez jamais vos mots de passe habituels sur la page de connexion",
    );
    if (!advice.contains(_noBanking)) advice.add(_noBanking);
  }

  // DNS privé désactivé : on conseille de l'activer.
  final dnsOff = status.privateDnsActive == false;
  if (dnsOff) {
    if (level == WifiLevel.excellent) level = WifiLevel.correct;
    explanation.add(
      'Le DNS privé est désactivé : le réseau peut voir '
      'les noms des sites que vous visitez.',
    );
    advice.add('Activez le DNS privé (mode automatique) dans les réglages');
  }

  return WifiReport(
    level: level,
    title: title,
    summary: summary,
    explanation: explanation.join(' '),
    advice: advice,
    suggestPrivateDns: dnsOff,
  );
}

/// Niveau et textes de départ, selon le type de protection seul.
WifiReport _bySecurity(WifiStatus status) {
  switch (status.security) {
    case WifiSecurity.open:
      return const WifiReport(
        level: WifiLevel.danger,
        title: 'Wi-Fi ouvert',
        summary: "Ce Wi-Fi n'est pas protégé.",
        explanation:
            "Ce Wi-Fi n'est pas protégé. Les personnes connectées "
            'au même réseau peuvent voir ce que vous envoyez.',
        advice: [_noBanking, _useMobile],
      );
    case WifiSecurity.wep:
      return const WifiReport(
        level: WifiLevel.danger,
        title: 'Protection WEP dépassée',
        summary: 'Sa protection se casse en quelques minutes.',
        explanation:
            'Ce Wi-Fi utilise WEP, une protection de 1999 qui se '
            "casse en quelques minutes. C'est presque comme un réseau ouvert.",
        advice: [_noBanking, _useMobile, _upgradeBox],
      );
    case WifiSecurity.wpa:
      return const WifiReport(
        level: WifiLevel.faible,
        title: 'Protection WPA ancienne',
        summary: 'Protection ancienne et fragile.',
        explanation:
            'Ce Wi-Fi utilise WPA, une protection ancienne qui '
            'a des failles connues.',
        advice: [_noBanking, _upgradeBox],
      );
    case WifiSecurity.owe:
      return const WifiReport(
        level: WifiLevel.faible,
        title: 'Wi-Fi public chiffré',
        summary: 'Chiffré, mais ouvert à tous.',
        explanation:
            'Ce Wi-Fi public chiffre vos échanges (Enhanced Open) : '
            'les autres ne peuvent pas les lire. Mais tout le monde peut '
            "s'y connecter, et un faux réseau peut imiter le vrai.",
        advice: [_noBanking],
      );
    case WifiSecurity.wpa2:
      return const WifiReport(
        level: WifiLevel.correct,
        title: 'Wi-Fi protégé (WPA2)',
        summary: 'Protégé par un mot de passe.',
        explanation:
            'Ce Wi-Fi est protégé par un mot de passe (WPA2). '
            'Les personnes qui ne le connaissent pas ne peuvent pas lire '
            'ce que vous envoyez.',
      );
    case WifiSecurity.wpa3:
      return const WifiReport(
        level: WifiLevel.excellent,
        title: 'Wi-Fi très protégé (WPA3)',
        summary: 'La meilleure protection Wi-Fi actuelle.',
        explanation:
            'Ce Wi-Fi utilise WPA3, la protection la plus récente. '
            "Même quelqu'un qui connaît le mot de passe ne peut pas lire "
            'vos échanges.',
      );
    case WifiSecurity.enterprise:
      return const WifiReport(
        level: WifiLevel.excellent,
        title: "Wi-Fi d'entreprise",
        summary: 'Chacun se connecte avec son propre identifiant.',
        explanation:
            "Ce Wi-Fi d'entreprise (WPA2 / WPA3-Entreprise) donne "
            'à chaque personne son propre identifiant et sa propre clé.',
      );
    case WifiSecurity.unknown:
      return WifiReport(
        level: WifiLevel.inconnu,
        title: 'Sécurité inconnue',
        summary: "Le type de protection n'est pas disponible.",
        // Android 11 et avant : seulement avec la localisation.
        explanation: status.sdkInt > 0 && status.sdkInt < 31
            ? "Sur Android 11 et avant, connaître la protection d'un Wi-Fi "
                  "demande l'autorisation de localisation, que Sentinel ne "
                  'demande pas.'
            : "Android n'a pas indiqué le type de protection de ce Wi-Fi.",
        advice: const ['Sur un Wi-Fi public, évitez la banque et les achats'],
      );
  }
}
