import 'package:material_ui/material_ui.dart';

import '../widgets/text_page.dart';

/// Politique de confidentialité, écrite d'après ce que fait le code.
/// Toute nouvelle fonction réseau ou donnée stockée doit être ajoutée ici
/// (et dans la présentation, onboarding_screen.dart).
const privacySections = [
  TextSection('En bref', [
    "Sentinel n'a ni serveur, ni compte, ni publicité, ni statistiques "
        "d'utilisation, ni rapport de plantage. Toutes les analyses se font "
        'sur le téléphone.',
    'Sentinel ne contacte Internet que pour les trois fonctions facultatives '
        'ci-dessous, et seulement après votre accord.',
  ]),
  TextSection('Les seuls échanges réseau (facultatifs)', [
    '1. Vérification des fuites de mots de passe (coffre). Après votre '
        'accord, Sentinel calcule l\'empreinte SHA-1 de chaque mot de passe '
        'et envoie seulement ses 5 premiers caractères à Have I Been Pwned '
        '(api.pwnedpasswords.com), en HTTPS. Le mot de passe et son '
        'empreinte complète ne quittent jamais le téléphone. Le service '
        'voit votre adresse IP. Vous pouvez retirer cet accord ; les '
        'résultats sont alors effacés.',
    '2. Pare-feu DNS. Quand vous l\'activez, les noms des sites demandés '
        'par vos applications passent par Sentinel. Les sites bloqués '
        'reçoivent une réponse sur le téléphone ; les autres noms sont '
        'transmis au résolveur Quad9, chiffrés (DNS sur TLS ou sur HTTPS). '
        'Quad9 voit ces noms et votre adresse IP, selon sa propre politique '
        'de confidentialité. Si un réseau bloque le DNS chiffré, rien ne '
        'part en clair, sauf si vous l\'autorisez pour ce réseau.',
    '3. Mise à jour des listes de blocage. Désactivée par défaut. Si vous '
        'la lancez ou activez la mise à jour automatique (au plus une fois '
        'par jour), Sentinel télécharge les listes depuis GitHub '
        '(raw.githubusercontent.com), sans cookie ni information sur vous. '
        'GitHub voit votre adresse IP.',
    "Les liens « Ouvrir le site » (conseils, sources, rapport d'audit) "
        "s'ouvrent dans votre navigateur, seulement quand vous les touchez.",
  ]),
  TextSection('Ce qui reste sur le téléphone', [
    'Le coffre (mots de passe, notes) : chiffré avec votre mot de passe '
        'maître (Argon2id, AES-256-GCM).',
    "Vos choix : accord pour la vérification des fuites, réglages du "
        "pare-feu et liste des sites autorisés, protection automatique "
        "activée ou non, présentation déjà vue.",
    "Les listes de blocage et leurs mises à jour.",
    "Les rapports « Analyser une application » : la liste des sites "
        "contactés par l'application choisie, effacés au plus tard 24 h "
        "après l'analyse.",
    'La sauvegarde Android est désactivée : rien ne part dans le cloud. '
        'Une sauvegarde du coffre (fichier .sentinel chiffré) n\'est créée '
        'que si vous la demandez, à l\'endroit que vous choisissez.',
  ]),
  TextSection("Ce que Sentinel n'enregistre jamais", [
    "Le texte des messages analysés (collés, partagés ou lus dans les "
        "notifications) : il est analysé en mémoire puis oublié.",
    'Votre historique de navigation : le pare-feu ne garde que des '
        "compteurs, jamais un nom de site (sauf pendant une analyse "
        "d'application que vous lancez).",
    'Le nom du Wi-Fi et votre position : Sentinel ne demande pas la '
        'localisation.',
  ]),
  TextSection('Les autorisations', [
    "Liste des applications installées : pour repérer les fausses apps et "
        "les logiciels espions. Elle n'est jamais envoyée.",
    'Notifications : demandée quand vous activez la protection '
        'automatique ou le pare-feu, pour afficher les alertes.',
    'Accès aux notifications : réglage Android que vous ouvrez vous-même '
        'pour la protection automatique ; Sentinel lit les messages reçus '
        'pour y chercher des arnaques.',
    'VPN : demandé quand vous activez le pare-feu. Il ne capte que le '
        'DNS, pas le reste du trafic.',
    'Biométrie : seulement si vous choisissez de déverrouiller le coffre '
        'sans taper votre mot de passe maître.',
  ]),
  TextSection('Effacer vos données', [
    'Désinstaller Sentinel efface tout ce qu\'il a enregistré sur le '
        'téléphone. Il n\'existe aucune copie ailleurs.',
  ]),
];

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TextPage(
      title: 'Politique de confidentialité',
      sections: privacySections,
    );
  }
}
