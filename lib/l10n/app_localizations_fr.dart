// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Sentinel';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonLater => 'Plus tard';

  @override
  String get commonAccept => 'Accepter';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonDetails => 'Détails';

  @override
  String get commonOn => 'Activé';

  @override
  String get commonOff => 'Désactivé';

  @override
  String get commonOffFeminine => 'Désactivée';

  @override
  String get commonUnknown => 'Inconnu';

  @override
  String get commonUnknownFeminine => 'Inconnue';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonAndroidOnly => 'Disponible sur Android';

  @override
  String get commonOpenSettings => 'Ouvrir les réglages';

  @override
  String get commonComingSoon => 'Bientôt disponible';

  @override
  String get commonAnalysisFailedPull =>
      'L\'analyse a échoué. Tirez vers le bas pour réessayer.';

  @override
  String commonDateAtTime(String date, String time) {
    return '$date à $time';
  }

  @override
  String get commonOutOf100 => 'sur 100';

  @override
  String get commonLoading => 'Chargement en cours';

  @override
  String scoreSemantics(int score) {
    return 'Score de sécurité : $score sur 100';
  }

  @override
  String get navHome => 'Accueil';

  @override
  String get navApps => 'Applications';

  @override
  String get navMessages => 'Messages';

  @override
  String get navVault => 'Coffre';

  @override
  String get homeGreeting => 'Bonjour';

  @override
  String get homeTitleFailed => 'Analyse impossible';

  @override
  String get homeTitleDefault => 'Sécurité du téléphone';

  @override
  String get homeTitleProtected => 'Votre téléphone est bien protégé';

  @override
  String get homeTitleToImprove => 'Quelques points à renforcer';

  @override
  String get homeTitleExposed => 'Votre téléphone est exposé';

  @override
  String homeAndroidVersion(String version) {
    return 'Android $version';
  }

  @override
  String homeAndroidVersionPatch(String version, String date) {
    return 'Android $version · correctif du $date';
  }

  @override
  String get homeAnalyzing => 'Analyse en cours…';

  @override
  String get homeAndroidOnly =>
      'L\'analyse du téléphone est disponible sur Android.';

  @override
  String get homeToGainPoints => 'Pour gagner des points';

  @override
  String get homeNothingToFix => 'Rien à corriger pour le moment.';

  @override
  String homeWifiAlert(String title) {
    return '$title : évitez la banque et les achats.';
  }

  @override
  String get scoreLockTitle => 'Configurer un verrouillage d\'écran';

  @override
  String get scoreLockDesc =>
      'Un code ou un schéma empêche l\'accès à vos données si le téléphone est perdu';

  @override
  String get scoreRootTitle => 'Votre téléphone semble rooté';

  @override
  String get scoreRootDesc =>
      'Le root contourne les protections d\'Android. Il ne se retire pas depuis les paramètres';

  @override
  String get scoreUpdateTitle => 'Installer la mise à jour de sécurité';

  @override
  String get scoreUpdateUnknown => 'La date du dernier correctif est inconnue';

  @override
  String get scoreUpdateOld => 'Le dernier correctif date de plus de 3 mois';

  @override
  String get scoreBiometricTitle => 'Activer le déverrouillage biométrique';

  @override
  String get scoreBiometricDesc =>
      'Empreinte ou visage pour ouvrir le téléphone';

  @override
  String get scoreDevOptionsTitle =>
      'Désactiver les options pour les développeurs';

  @override
  String get scoreDevOptionsDesc =>
      'Elles donnent accès à des réglages sensibles du système';

  @override
  String get scoreUsbTitle => 'Désactiver le débogage USB';

  @override
  String get scoreUsbDesc =>
      'Un ordinateur branché pourrait accéder à vos données';

  @override
  String get scoreEncryptTitle => 'Chiffrer le stockage';

  @override
  String get scoreEncryptDesc =>
      'Vos fichiers restent illisibles sans votre code';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String settingsAppVersion(String version) {
    return 'Sentinel $version';
  }

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Langue du téléphone';

  @override
  String get settingsTheme => 'Apparence';

  @override
  String get settingsThemeSystem => 'Comme le téléphone';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsReplayOnboarding => 'Revoir la présentation';

  @override
  String get settingsPrivacy => 'Politique de confidentialité';

  @override
  String get settingsLicenses => 'Licences';

  @override
  String get settingsLicensesDetail =>
      'Bibliothèques, police, listes de blocage, logiciels espions';

  @override
  String get settingsLicenseLegalese => 'Licence MIT';

  @override
  String get settingsAudit => 'Rapport d\'audit de sécurité';

  @override
  String get settingsReportFlaw => 'Signaler une faille';

  @override
  String get settingsReportFlawDetail =>
      'En privé, via GitHub (ouvre le navigateur)';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingStart => 'Commencer';

  @override
  String get onboarding1Title => 'Sentinel veille sur votre téléphone';

  @override
  String get onboarding1Line1 =>
      'Un score de sécurité et les réglages à corriger.';

  @override
  String get onboarding1Line2 =>
      'Les applications suspectes : fausses apps, logiciels espions.';

  @override
  String get onboarding1Line3 =>
      'Les messages d\'arnaque, analysés sur le téléphone.';

  @override
  String get onboarding1Line4 => 'Un coffre chiffré pour vos mots de passe.';

  @override
  String get onboarding1Line5 =>
      'Un pare-feu qui bloque les sites dangereux et les traqueurs.';

  @override
  String get onboarding2Title => 'Tout reste sur votre téléphone';

  @override
  String get onboarding2Line1 =>
      'Pas de compte, pas de publicité, pas de statistiques. Vos messages, vos mots de passe et la liste de vos applications ne quittent jamais le téléphone.';

  @override
  String get onboarding2Line2 =>
      'Seuls trois échanges réseau existent, tous facultatifs, et seulement si vous les activez :';

  @override
  String get onboarding2Line3 =>
      '• Vérifier les fuites de mots de passe (Have I Been Pwned) : 5 caractères d\'une empreinte, jamais le mot de passe.';

  @override
  String get onboarding2Line4 =>
      '• Pare-feu DNS : les noms des sites autorisés sont transmis, chiffrés, au résolveur Quad9.';

  @override
  String get onboarding2Line5 =>
      '• Mise à jour des listes de blocage : un simple téléchargement depuis GitHub.';

  @override
  String get onboarding3Title => 'Les autorisations, au bon moment';

  @override
  String get onboarding3Line1 => 'Sentinel ne demande rien maintenant.';

  @override
  String get onboarding3Line2 =>
      'Chaque autorisation (notifications, accès aux notifications, VPN, biométrie) est demandée seulement quand vous activez la fonction qui en a besoin, avec une explication.';

  @override
  String get onboarding3Line3 => 'Vous pouvez tout désactiver à tout moment.';

  @override
  String get privacyBriefTitle => 'En bref';

  @override
  String get privacyBrief1 =>
      'Sentinel n\'a ni serveur, ni compte, ni publicité, ni statistiques d\'utilisation, ni rapport de plantage. Toutes les analyses se font sur le téléphone.';

  @override
  String get privacyBrief2 =>
      'Sentinel ne contacte Internet que pour les trois fonctions facultatives ci-dessous, et seulement après votre accord.';

  @override
  String get privacyNetworkTitle => 'Les seuls échanges réseau (facultatifs)';

  @override
  String get privacyNetwork1 =>
      '1. Vérification des fuites de mots de passe (coffre). Après votre accord, Sentinel calcule l\'empreinte SHA-1 de chaque mot de passe et envoie seulement ses 5 premiers caractères à Have I Been Pwned (api.pwnedpasswords.com), en HTTPS. Le mot de passe et son empreinte complète ne quittent jamais le téléphone. Le service voit votre adresse IP. Vous pouvez retirer cet accord ; les résultats sont alors effacés.';

  @override
  String get privacyNetwork2 =>
      '2. Pare-feu DNS. Quand vous l\'activez, les noms des sites demandés par vos applications passent par Sentinel. Les sites bloqués reçoivent une réponse sur le téléphone ; les autres noms sont transmis au résolveur Quad9, chiffrés (DNS sur TLS ou sur HTTPS). Quad9 voit ces noms et votre adresse IP, selon sa propre politique de confidentialité. Si un réseau bloque le DNS chiffré, rien ne part en clair, sauf si vous l\'autorisez pour ce réseau.';

  @override
  String get privacyNetwork3 =>
      '3. Mise à jour des listes de blocage. Désactivée par défaut. Si vous la lancez ou activez la mise à jour automatique (au plus une fois par jour), Sentinel télécharge les listes depuis GitHub (raw.githubusercontent.com), sans cookie ni information sur vous. GitHub voit votre adresse IP.';

  @override
  String get privacyNetwork4 =>
      'Les liens « Ouvrir le site » (conseils, sources, rapport d\'audit) s\'ouvrent dans votre navigateur, seulement quand vous les touchez.';

  @override
  String get privacyLocalTitle => 'Ce qui reste sur le téléphone';

  @override
  String get privacyLocal1 =>
      'Le coffre (mots de passe, notes) : chiffré avec votre mot de passe maître (Argon2id, AES-256-GCM).';

  @override
  String get privacyLocal2 =>
      'Vos choix : accord pour la vérification des fuites, réglages du pare-feu et liste des sites autorisés, protection automatique activée ou non, présentation déjà vue, langue, thème.';

  @override
  String get privacyLocal3 => 'Les listes de blocage et leurs mises à jour.';

  @override
  String get privacyLocal4 =>
      'Les rapports « Analyser une application » : la liste des sites contactés par l\'application choisie, effacés au plus tard 24 h après l\'analyse.';

  @override
  String get privacyLocal5 =>
      'La sauvegarde Android est désactivée : rien ne part dans le cloud. Une sauvegarde du coffre (fichier .sentinel chiffré) n\'est créée que si vous la demandez, à l\'endroit que vous choisissez.';

  @override
  String get privacyNeverTitle => 'Ce que Sentinel n\'enregistre jamais';

  @override
  String get privacyNever1 =>
      'Le texte des messages et des QR codes analysés (collés, partagés, scannés ou lus dans les notifications) : il est analysé en mémoire puis oublié. L\'image de la caméra n\'est jamais enregistrée.';

  @override
  String get privacyNever2 =>
      'Votre historique de navigation : le pare-feu ne garde que des compteurs, jamais un nom de site (sauf pendant une analyse d\'application que vous lancez).';

  @override
  String get privacyNever3 =>
      'Le nom du Wi-Fi et votre position : Sentinel ne demande pas la localisation.';

  @override
  String get privacyPermissionsTitle => 'Les autorisations';

  @override
  String get privacyPermissions1 =>
      'Liste des applications installées : pour repérer les fausses apps et les logiciels espions. Elle n\'est jamais envoyée.';

  @override
  String get privacyPermissions2 =>
      'Notifications : demandée quand vous activez la protection automatique ou le pare-feu, pour afficher les alertes.';

  @override
  String get privacyPermissions3 =>
      'Accès aux notifications : réglage Android que vous ouvrez vous-même pour la protection automatique ; Sentinel lit les messages reçus pour y chercher des arnaques.';

  @override
  String get privacyPermissions4 =>
      'VPN : demandé quand vous activez le pare-feu. Il ne capte que le DNS, pas le reste du trafic.';

  @override
  String get privacyPermissions5 =>
      'Biométrie : seulement si vous choisissez de déverrouiller le coffre sans taper votre mot de passe maître.';

  @override
  String get privacyPermissions6 =>
      'Caméra : demandée quand vous touchez « Scanner un QR code », seulement pour lire le QR code, sur le téléphone.';

  @override
  String get privacyEraseTitle => 'Effacer vos données';

  @override
  String get privacyErase1 =>
      'Désinstaller Sentinel efface tout ce qu\'il a enregistré sur le téléphone. Il n\'existe aucune copie ailleurs.';

  @override
  String get auditFrameTitle => 'Le cadre';

  @override
  String get auditFrame1 =>
      'Audit de sécurité selon le référentiel OWASP MASVS v2, du 21 au 24 octobre 2026, sur Sentinel 1.0.0 : analyse du code, du trafic réseau, du stockage et des composants Android.';

  @override
  String get auditFrame2 =>
      'Il a été mené pour le propriétaire de l\'application, sur son propre code : ce n\'est pas un audit indépendant.';

  @override
  String get auditResultsTitle => 'Les résultats';

  @override
  String get auditResults1 =>
      '17 constats, dont un de sévérité élevée et quatre moyens.';

  @override
  String get auditResults2 =>
      '14 sont corrigés, chacun avec un test automatique. 3 sont acceptés en connaissance de cause (modèle anti-arnaque lisible car l\'app est open source, pas d\'épinglage de certificat, un constat déjà conforme).';

  @override
  String get auditResults3 =>
      'Depuis, le pare-feu chiffre toutes ses requêtes et l\'app ne contacte plus rien sans accord.';

  @override
  String get auditLimitsTitle => 'Les limites';

  @override
  String get auditLimits1 =>
      'Aucune application n\'est sûre à 100 %. Les principaux risques restants dépendent du téléphone : un Android trop ancien, ou un logiciel espion à qui l\'on a donné l\'accessibilité ou le root.';

  @override
  String get auditReadFull => 'Lire le rapport complet sur GitHub';

  @override
  String get verdictScam => 'Arnaque probable';

  @override
  String get verdictSuspect => 'Suspect';

  @override
  String get verdictNothing => 'Rien de suspect';

  @override
  String get adviceScam =>
      'Ne cliquez pas sur le lien et ne communiquez aucun code. Votre banque ou La Poste ne vous demandent jamais de payer par SMS. Supprimez ce message.';

  @override
  String get adviceSuspect =>
      'Soyez prudent : n\'ouvrez pas le lien et ne donnez aucune information. En cas de doute, appelez l\'organisme au numéro de son site officiel.';

  @override
  String get adviceNothing =>
      'Aucun signe d\'arnaque trouvé. Restez quand même vigilant : ne communiquez jamais vos codes ni vos mots de passe.';

  @override
  String get reasonHiddenCharacters =>
      'Caractères invisibles ou d\'inversion de texte (technique d\'arnaque)';

  @override
  String reasonScamWords(String words) {
    return 'Mots typiques des arnaques : $words';
  }

  @override
  String reasonQuotedWord(String word) {
    return '« $word »';
  }

  @override
  String get listSeparator => ', ';

  @override
  String reasonLinkImpersonation(String host, String brand) {
    return '« $host » imite $brand mais ce n\'est pas son site officiel';
  }

  @override
  String reasonLinkIp(String host) {
    return 'Le lien utilise une adresse IP ($host) au lieu d\'un nom de site';
  }

  @override
  String reasonLinkPunycode(String host) {
    return '« $host » contient des lettres déguisées (punycode) pour ressembler à un vrai site';
  }

  @override
  String reasonLinkAt(String host) {
    return 'Le lien contient « @ » : la vraie destination est « $host »';
  }

  @override
  String reasonLinkShortener(String host) {
    return 'Lien raccourci ($host) : la vraie adresse est cachée';
  }

  @override
  String reasonLinkTld(String tld) {
    return 'L\'extension « .$tld » est souvent utilisée par les arnaques';
  }

  @override
  String reasonLinkSubdomains(String host) {
    return '« $host » a beaucoup de sous-domaines, une technique pour tromper';
  }

  @override
  String get reasonLinkHttp =>
      'Le lien n\'est pas sécurisé (http au lieu de https)';

  @override
  String get messagesHint => 'Collez un SMS, un message WhatsApp ou un lien';

  @override
  String get messagesPaste => 'Coller';

  @override
  String get messagesClear => 'Effacer';

  @override
  String get messagesAnalyze => 'Analyser';

  @override
  String get messagesFailed => 'L\'analyse a échoué. Réessayez.';

  @override
  String get messagesLocalNote =>
      'L\'analyse se fait sur votre téléphone. Le message n\'est envoyé nulle part.';

  @override
  String messagesProbability(String percent) {
    return 'Probabilité d\'arnaque : $percent %';
  }

  @override
  String get alertDefaultReason =>
      'Ce message ressemble aux arnaques connues. Ne cliquez sur aucun lien.';

  @override
  String get alertTitleSms => 'Arnaque probable dans un SMS';

  @override
  String get alertTitleMessage => 'Arnaque probable dans un message';

  @override
  String alertTitleApp(String app) {
    return 'Arnaque probable sur $app';
  }

  @override
  String get autoProtectionTitle => 'Protection automatique';

  @override
  String get autoProtectionOn =>
      'Analyse les messages reçus et vous prévient en cas d\'arnaque.';

  @override
  String get autoProtectionNotificationsBlocked =>
      'Notifications de Sentinel bloquées : vous ne serez pas prévenu en cas d\'arnaque.';

  @override
  String get autoProtectionAllowNotifications =>
      'Autoriser les notifications de Sentinel';

  @override
  String get autoProtectionRemoveAccess =>
      'Retirer aussi l\'accès dans les réglages Android';

  @override
  String get autoProtectionDoesTitle => 'Ce que fait Sentinel';

  @override
  String get autoProtectionDoes1 =>
      'Lit le texte des notifications de vos applications de messagerie.';

  @override
  String get autoProtectionDoes2 => 'L\'analyse sur votre téléphone.';

  @override
  String get autoProtectionDoes3 => 'Vous prévient si c\'est une arnaque.';

  @override
  String get autoProtectionNeverTitle => 'Ce que Sentinel ne fait jamais';

  @override
  String get autoProtectionNever1 => 'Envoyer vos messages sur Internet.';

  @override
  String get autoProtectionNever2 => 'Les enregistrer.';

  @override
  String get autoProtectionNever3 =>
      'Lire les notifications des autres applications.';

  @override
  String get wifiLevelDanger => 'Danger';

  @override
  String get wifiLevelWeak => 'Faible';

  @override
  String get wifiLevelOk => 'Correct';

  @override
  String get wifiLevelExcellent => 'Excellent';

  @override
  String get wifiLevelNone => 'Aucun';

  @override
  String get wifiLevelUnknown => 'Inconnu';

  @override
  String get wifiSecurityOpen => 'Aucune (réseau ouvert)';

  @override
  String get wifiSecurityWpa2 => 'WPA2 ou WPA';

  @override
  String get wifiSecurityEnterprise => 'Entreprise (WPA2 / WPA3)';

  @override
  String get wifiAdviceNoBanking =>
      'Évitez la banque et les achats sur ce réseau';

  @override
  String get wifiAdviceUseMobile => 'Utilisez plutôt les données mobiles';

  @override
  String get wifiAdviceUpgradeBox =>
      'Si c\'est votre box, choisissez WPA2 ou WPA3 dans ses réglages';

  @override
  String get wifiAdvicePublicUnknown =>
      'Sur un Wi-Fi public, évitez la banque et les achats';

  @override
  String get wifiNoneTitle => 'Pas de Wi-Fi';

  @override
  String get wifiNoneSummary => 'Vous n\'êtes connecté à aucun Wi-Fi.';

  @override
  String get wifiNoneExplanation =>
      'Vous n\'êtes connecté à aucun Wi-Fi : rien à vérifier pour le moment.';

  @override
  String get wifiPublicTitle => 'Wi-Fi public';

  @override
  String get wifiPublicSummary => 'Réseau partagé avec une page de connexion.';

  @override
  String get wifiCaptiveExplanation =>
      'Ce réseau demande de se connecter sur une page (hôtel, gare, café…). Beaucoup de personnes le partagent.';

  @override
  String get wifiCaptiveAdvice =>
      'N\'utilisez jamais vos mots de passe habituels sur la page de connexion';

  @override
  String get wifiDnsOffExplanation =>
      'Le DNS privé est désactivé : le réseau peut voir les noms des sites que vous visitez.';

  @override
  String get wifiDnsOffAdvice =>
      'Activez le DNS privé (mode automatique) dans les réglages';

  @override
  String get wifiOpenTitle => 'Wi-Fi ouvert';

  @override
  String get wifiOpenSummary => 'Ce Wi-Fi n\'est pas protégé.';

  @override
  String get wifiOpenExplanation =>
      'Ce Wi-Fi n\'est pas protégé. Les personnes connectées au même réseau peuvent voir ce que vous envoyez.';

  @override
  String get wifiWepTitle => 'Protection WEP dépassée';

  @override
  String get wifiWepSummary => 'Sa protection se casse en quelques minutes.';

  @override
  String get wifiWepExplanation =>
      'Ce Wi-Fi utilise WEP, une protection de 1999 qui se casse en quelques minutes. C\'est presque comme un réseau ouvert.';

  @override
  String get wifiWpaTitle => 'Protection WPA ancienne';

  @override
  String get wifiWpaSummary => 'Protection ancienne et fragile.';

  @override
  String get wifiWpaExplanation =>
      'Ce Wi-Fi utilise WPA, une protection ancienne qui a des failles connues.';

  @override
  String get wifiOweTitle => 'Wi-Fi public chiffré';

  @override
  String get wifiOweSummary => 'Chiffré, mais ouvert à tous.';

  @override
  String get wifiOweExplanation =>
      'Ce Wi-Fi public chiffre vos échanges (Enhanced Open) : les autres ne peuvent pas les lire. Mais tout le monde peut s\'y connecter, et un faux réseau peut imiter le vrai.';

  @override
  String get wifiWpa2Title => 'Wi-Fi protégé (WPA2)';

  @override
  String get wifiWpa2Summary => 'Protégé par un mot de passe.';

  @override
  String get wifiWpa2Explanation =>
      'Ce Wi-Fi est protégé par un mot de passe (WPA2). Les personnes qui ne le connaissent pas ne peuvent pas lire ce que vous envoyez.';

  @override
  String get wifiWpa3Title => 'Wi-Fi très protégé (WPA3)';

  @override
  String get wifiWpa3Summary => 'La meilleure protection Wi-Fi actuelle.';

  @override
  String get wifiWpa3Explanation =>
      'Ce Wi-Fi utilise WPA3, la protection la plus récente. Même quelqu\'un qui connaît le mot de passe ne peut pas lire vos échanges.';

  @override
  String get wifiEnterpriseTitle => 'Wi-Fi d\'entreprise';

  @override
  String get wifiEnterpriseSummary =>
      'Chacun se connecte avec son propre identifiant.';

  @override
  String get wifiEnterpriseExplanation =>
      'Ce Wi-Fi d\'entreprise (WPA2 / WPA3-Entreprise) donne à chaque personne son propre identifiant et sa propre clé.';

  @override
  String get wifiUnknownTitle => 'Sécurité inconnue';

  @override
  String get wifiUnknownSummary =>
      'Le type de protection n\'est pas disponible.';

  @override
  String get wifiUnknownOldAndroid =>
      'Sur Android 11 et avant, connaître la protection d\'un Wi-Fi demande l\'autorisation de localisation, que Sentinel ne demande pas.';

  @override
  String get wifiUnknownExplanation =>
      'Android n\'a pas indiqué le type de protection de ce Wi-Fi.';

  @override
  String get wifiSectionTitle => 'Réseau Wi-Fi';

  @override
  String get wifiUnavailableTitle => 'Information indisponible';

  @override
  String get wifiUnavailableSummary =>
      'Android n\'a pas pu lire l\'état du Wi-Fi.';

  @override
  String get wifiDetailProtection => 'Protection';

  @override
  String get wifiDetailCaptive => 'Page de connexion';

  @override
  String get wifiDetailPrivateDns => 'DNS privé';

  @override
  String get wifiOurAdvice => 'Nos conseils';

  @override
  String get wifiEnablePrivateDns => 'Activer le DNS privé';

  @override
  String get wifiPrivateDnsHelp =>
      'Ouvre « Réseau et Internet ». Le DNS privé se trouve parfois sous « Avancé » ou « Plus de paramètres de connexion ».';

  @override
  String get riskLevelSystem => 'Système';

  @override
  String get riskLevelLow => 'Faible';

  @override
  String get riskLevelModerate => 'Modéré';

  @override
  String get riskLevelHigh => 'Élevé';

  @override
  String get riskStalkerware => 'Logiciel espion connu (stalkerware)';

  @override
  String riskModifiedCopy(String brand) {
    return 'Copie modifiée de $brand (signature différente de l\'éditeur officiel)';
  }

  @override
  String riskImpersonation(String brand) {
    return 'Se fait passer pour $brand, mais ce n\'est pas l\'application officielle';
  }

  @override
  String riskKnownMod(String brand) {
    return 'Version modifiée non officielle de $brand : elle peut lire vos messages';
  }

  @override
  String get riskSpyProfile =>
      'Icône cachée et accès typiques d\'un logiciel espion';

  @override
  String get riskBankingCombo =>
      'Combinaison typique des applications qui volent les comptes bancaires';

  @override
  String get riskAccessibility =>
      'Peut lire tout ce qui s\'affiche à l\'écran et agir à votre place';

  @override
  String get riskUnknownSource => 'Installée en dehors du Play Store';

  @override
  String get riskDeviceAdmin =>
      'Est administrateur de l\'appareil et peut compliquer sa désinstallation';

  @override
  String get riskDebugCert => 'Signée avec un certificat de test';

  @override
  String get riskSms =>
      'Peut lire vos SMS, y compris les codes de vérification bancaires';

  @override
  String get riskNotifications =>
      'Peut lire toutes vos notifications, y compris vos messages';

  @override
  String get riskMicrophone => 'Peut utiliser le micro';

  @override
  String get riskCallLog => 'Peut consulter l\'historique de vos appels';

  @override
  String get riskOverlay =>
      'Peut s\'afficher par-dessus les autres applications';

  @override
  String get riskBackgroundLocation =>
      'Peut connaître votre position même quand vous ne l\'utilisez pas';

  @override
  String get riskOldTarget =>
      'Conçue pour une ancienne version d\'Android, avec moins de protections';

  @override
  String get riskOtherStore =>
      'Installée depuis une boutique autre que le Play Store (contrôles différents)';

  @override
  String get riskContacts => 'Peut lire vos contacts';

  @override
  String get riskCamera => 'Peut utiliser l\'appareil photo';

  @override
  String appsAnalyzed(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n applications analysées',
      one: '$n application analysée',
    );
    return '$_temp0';
  }

  @override
  String appsSummaryNoneToReview(String analyzed) {
    return '$analyzed, aucune à vérifier.';
  }

  @override
  String appsSummaryToReview(String analyzed, String count) {
    return '$analyzed, dont $count à vérifier.';
  }

  @override
  String get appsEmptyTitle => 'Analysez vos applications';

  @override
  String get appsEmptyMessage =>
      'Sentinel vérifie les permissions de chaque application installée et signale celles qui en demandent trop.';

  @override
  String get appsStartScan => 'Lancer l\'analyse';

  @override
  String get appsAndroidOnly =>
      'L\'analyse des applications est disponible sur Android.';

  @override
  String get appsShowSystem => 'Afficher les applications système';

  @override
  String get appsSpywareFound => 'Un logiciel espion possible a été trouvé';

  @override
  String get appsSpywareReadAdvice =>
      'Lisez les conseils avant de le supprimer.';

  @override
  String get appsSeeAdvice => 'Voir les conseils';

  @override
  String get appsScanning => 'Analyse de vos applications…';

  @override
  String get appsSystemApp => 'Application du système Android';

  @override
  String get appsNoWorry => 'Aucun signal inquiétant';

  @override
  String get detailPreinstalled => 'Préinstallée';

  @override
  String get detailUnknownSource => 'Source inconnue';

  @override
  String detailKnownSpyware(String name) {
    return 'Logiciel espion connu : $name';
  }

  @override
  String detailSignatureVerified(String brand) {
    return 'Signature vérifiée pour $brand';
  }

  @override
  String detailSignatureDifferent(String brand) {
    return 'Signature différente de l\'éditeur officiel de $brand';
  }

  @override
  String detailNotOfficial(String brand) {
    return 'Ce n\'est pas l\'application officielle de $brand';
  }

  @override
  String detailKnownMod(String brand) {
    return 'Version modifiée non officielle de $brand';
  }

  @override
  String detailUnchecked(String brand) {
    return 'Empreinte officielle de $brand pas encore enregistrée dans Sentinel';
  }

  @override
  String get detailSignatureUnreadable => 'Signature illisible';

  @override
  String get detailSha256 => 'Empreinte SHA-256';

  @override
  String get detailCertificate => 'Certificat';

  @override
  String get detailPublisherMissing => 'Éditeur non renseigné';

  @override
  String detailOtherCertificates(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Et $n autres certificats (anciens ou multiples)',
      one: 'Et 1 autre certificat (ancien ou multiple)',
    );
    return '$_temp0';
  }

  @override
  String get detailWhatToDo => 'Que faire ?';

  @override
  String get detailManagePermissions => 'Gérer les autorisations';

  @override
  String get detailUninstall => 'Désinstaller';

  @override
  String get detailRiskLevel => 'Niveau de risque';

  @override
  String get detailSource => 'Source';

  @override
  String get detailInstalledOn => 'Installée le';

  @override
  String get detailUpdatedOn => 'Mise à jour le';

  @override
  String get detailWhyLevel => 'Pourquoi ce niveau';

  @override
  String get detailSystemExplanation =>
      'Cette application fait partie d\'Android ou de votre fabricant. Ses autorisations étendues sont normales pour son fonctionnement.';

  @override
  String get detailSignature => 'Signature';

  @override
  String get detailGrantedPermissions => 'Autorisations accordées';

  @override
  String get detailNoPermissions => 'Aucune autorisation accordée';

  @override
  String detailOtherPermissions(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Et $n autres autorisations techniques',
      one: 'Et 1 autre autorisation technique',
    );
    return '$_temp0';
  }

  @override
  String get spywareTitle => 'Avant de toucher à cette application';

  @override
  String get spywareParagraph1 =>
      'Si vous pensez que quelqu\'un de votre entourage a installé cette application, sa suppression peut le prévenir. Si vous êtes en danger, contactez d\'abord une association d\'aide ou la police.';

  @override
  String get spywareParagraph2 =>
      'Avant d\'agir, vous pouvez noter le nom de l\'application et faire une capture d\'écran : cela peut servir de preuve.';

  @override
  String get spywareParagraph3 =>
      'Sentinel ne prévient personne et n\'envoie aucune notification à ce sujet.';

  @override
  String get spywareGetHelp => 'Se faire aider';

  @override
  String get spywareCoalition =>
      'Coalition Against Stalkerware : des conseils pour les personnes surveillées et des contacts d\'associations.';

  @override
  String get spywareBrowserNote =>
      'Le site s\'ouvre dans votre navigateur et restera dans son historique. Vous pouvez aussi copier l\'adresse et l\'ouvrir en navigation privée, ou depuis un autre appareil.';

  @override
  String get spywareOpenSite => 'Ouvrir le site';

  @override
  String get spywareCopyAddress => 'Copier l\'adresse';

  @override
  String get spywareAddressCopied => 'Adresse copiée';

  @override
  String get spywareIocCredit =>
      'Liste de logiciels espions : projet Stalkerware Indicators (Echap), licence CC BY 4.0.';

  @override
  String get permReadSms => 'Lire vos SMS';

  @override
  String get permReceiveSms => 'Recevoir vos SMS';

  @override
  String get permSendSms => 'Envoyer des SMS (parfois payants)';

  @override
  String get permReceiveMms => 'Recevoir des MMS';

  @override
  String get permReadCallLog => 'Consulter l\'historique des appels';

  @override
  String get permWriteCallLog => 'Modifier l\'historique des appels';

  @override
  String get permCallPhone => 'Passer des appels';

  @override
  String get permAnswerPhoneCalls => 'Répondre aux appels';

  @override
  String get permReadPhoneState => 'Voir l\'état du téléphone et des appels';

  @override
  String get permReadPhoneNumbers => 'Connaître votre numéro de téléphone';

  @override
  String get permReadContacts => 'Lire vos contacts';

  @override
  String get permWriteContacts => 'Modifier vos contacts';

  @override
  String get permGetAccounts => 'Voir les comptes enregistrés sur le téléphone';

  @override
  String get permReadCalendar => 'Lire votre agenda';

  @override
  String get permWriteCalendar => 'Modifier votre agenda';

  @override
  String get permRecordAudio => 'Utiliser le micro';

  @override
  String get permCamera => 'Utiliser l\'appareil photo';

  @override
  String get permBodySensors =>
      'Lire les capteurs corporels (rythme cardiaque…)';

  @override
  String get permBodySensorsBackground =>
      'Lire les capteurs corporels en arrière-plan';

  @override
  String get permActivityRecognition => 'Détecter votre activité physique';

  @override
  String get permAccessFineLocation => 'Connaître votre position précise';

  @override
  String get permAccessCoarseLocation =>
      'Connaître votre position approximative';

  @override
  String get permAccessBackgroundLocation =>
      'Connaître votre position même quand l\'app est fermée';

  @override
  String get permAccessMediaLocation => 'Lire le lieu de prise de vos photos';

  @override
  String get permReadExternalStorage => 'Lire vos fichiers';

  @override
  String get permWriteExternalStorage => 'Modifier vos fichiers';

  @override
  String get permManageExternalStorage => 'Accéder à tous vos fichiers';

  @override
  String get permReadMediaImages => 'Voir vos photos';

  @override
  String get permReadMediaVideo => 'Voir vos vidéos';

  @override
  String get permReadMediaAudio => 'Accéder à vos fichiers audio';

  @override
  String get permReadMediaVisualUserSelected =>
      'Voir les photos que vous choisissez';

  @override
  String get permBluetooth => 'Utiliser le Bluetooth';

  @override
  String get permBluetoothConnect => 'Se connecter aux appareils Bluetooth';

  @override
  String get permBluetoothScan => 'Rechercher des appareils Bluetooth';

  @override
  String get permNearbyWifiDevices => 'Trouver les appareils Wi-Fi à proximité';

  @override
  String get permNfc => 'Utiliser le NFC (paiement sans contact…)';

  @override
  String get permInternet => 'Accéder à internet';

  @override
  String get permAccessNetworkState => 'Voir l\'état de la connexion';

  @override
  String get permAccessWifiState => 'Voir les réseaux Wi-Fi';

  @override
  String get permChangeWifiState => 'Activer ou couper le Wi-Fi';

  @override
  String get permSystemAlertWindow =>
      'S\'afficher par-dessus les autres applications';

  @override
  String get permPostNotifications => 'Afficher des notifications';

  @override
  String get permRequestInstallPackages =>
      'Proposer d\'installer d\'autres applications';

  @override
  String get permRequestDeletePackages =>
      'Proposer de désinstaller des applications';

  @override
  String get permQueryAllPackages => 'Voir la liste de vos applications';

  @override
  String get permPackageUsageStats => 'Voir quelles applications vous utilisez';

  @override
  String get permReceiveBootCompleted => 'Se lancer au démarrage du téléphone';

  @override
  String get permForegroundService => 'Fonctionner en continu en arrière-plan';

  @override
  String get permWakeLock => 'Empêcher la mise en veille';

  @override
  String get permVibrate => 'Faire vibrer le téléphone';

  @override
  String get permUseBiometric => 'Utiliser l\'empreinte ou le visage';

  @override
  String get permUseFingerprint => 'Utiliser l\'empreinte digitale';

  @override
  String get permScheduleExactAlarm => 'Programmer des alarmes précises';

  @override
  String get permUseFullScreenIntent => 'Afficher des alertes en plein écran';

  @override
  String get firewallTitle => 'Pare-feu DNS';

  @override
  String firewallOnBlocked(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Activé · $n requêtes bloquées',
      one: 'Activé · $n requête bloquée',
    );
    return '$_temp0';
  }

  @override
  String get categoryMalware => 'Malware et hameçonnage';

  @override
  String get categoryImpersonation => 'Imitations de marques';

  @override
  String get categoryTrackers => 'Traqueurs';

  @override
  String get categoryAds => 'Publicités';

  @override
  String get categoryOther => 'Autres domaines';

  @override
  String categoryBrandsWatched(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n marques surveillées · sites qui les imitent',
      one: '$n marque surveillée · sites qui les imitent',
    );
    return '$_temp0';
  }

  @override
  String domainsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n domaines',
      one: '$n domaine',
    );
    return '$_temp0';
  }

  @override
  String get firewallListsBundled => 'Listes livrées avec l\'application';

  @override
  String firewallLastUpdate(String date) {
    return 'Dernière mise à jour : $date';
  }

  @override
  String get firewallLastAttemptFailed => 'dernière tentative échouée';

  @override
  String get analysisErrorFirewallOff => 'Activez d\'abord le pare-feu DNS.';

  @override
  String get analysisErrorRunning => 'Une analyse est déjà en cours.';

  @override
  String get analysisErrorUnknownApp =>
      'Cette application n\'est plus installée.';

  @override
  String get analysisErrorFailed => 'Impossible de lancer l\'analyse.';

  @override
  String durationMinutes(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n min',
    );
    return '$_temp0';
  }

  @override
  String durationMinutesLong(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n minutes',
      one: '$n minute',
    );
    return '$_temp0';
  }

  @override
  String durationSeconds(String n) {
    return '$n s';
  }

  @override
  String durationMinutesSeconds(String minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String durationMinutesOnly(String minutes) {
    return '$minutes min';
  }

  @override
  String get durationLessThanSecond => 'moins d\'1 s';

  @override
  String reportStoppedEarly(String duration, String planned) {
    return '$duration (arrêtée avant les $planned prévues)';
  }

  @override
  String reportNoDomain(String app) {
    return '$app n\'a contacté aucun domaine pendant l\'analyse.';
  }

  @override
  String reportContacted(String app, String domains) {
    return '$app a contacté $domains';
  }

  @override
  String reportNothingKnown(String start) {
    return '$start, aucun connu comme traqueur, publicité ou site dangereux.';
  }

  @override
  String reportIncluding(String start, String parts) {
    return '$start, dont $parts.';
  }

  @override
  String reportDangerousCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n sites dangereux',
      one: '$n site dangereux',
    );
    return '$_temp0';
  }

  @override
  String reportTrackersCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n traqueurs',
      one: '$n traqueur',
    );
    return '$_temp0';
  }

  @override
  String reportAdsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n publicités',
      one: '$n publicité',
    );
    return '$_temp0';
  }

  @override
  String get listLastSeparator => ' et ';

  @override
  String get analysisLessThanMinuteLeft => 'Reste moins d\'1 min';

  @override
  String analysisMinutesLeft(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reste $n min',
    );
    return '$_temp0';
  }

  @override
  String analysisDomainsSeen(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n domaines vus',
      one: '$n domaine vu',
    );
    return '$_temp0';
  }

  @override
  String get analysisSectionTitle => 'Analyser une application';

  @override
  String analysisRunning(String app) {
    return 'Analyse de $app en cours';
  }

  @override
  String get analysisUnprotectedWarning =>
      'Les autres applications ne sont pas protégées par le pare-feu jusqu\'à la fin de l\'analyse.';

  @override
  String get analysisStop => 'Arrêter l\'analyse';

  @override
  String get analysisIntroActive =>
      'Découvrez quels sites une application contacte pendant quelques minutes : traqueurs, publicités, sites dangereux.';

  @override
  String get analysisIntroInactive =>
      'Activez le pare-feu pour analyser une application.';

  @override
  String get analysisChooseApp => 'Choisir une application';

  @override
  String get analysisRecentReports => 'Rapports des dernières 24 heures';

  @override
  String get analysisScreenIntro =>
      'Choisissez l\'application à observer. Pendant quelques minutes, Sentinel note les sites (domaines) qu\'elle contacte.';

  @override
  String get analysisListFailed => 'Impossible de lister les applications.';

  @override
  String get analysisNoApps => 'Aucune application à analyser.';

  @override
  String analysisSheetTitle(String app) {
    return 'Analyser $app';
  }

  @override
  String analysisSheetLine1(String duration, String app) {
    return 'Pendant $duration, seules les demandes de $app passent par le pare-feu : chaque domaine vu lui appartient.';
  }

  @override
  String get analysisSheetLine2 =>
      'Les autres applications ne sont PAS protégées pendant ce temps : ni blocage, ni alerte. Évitez d\'ouvrir des liens inconnus.';

  @override
  String get analysisSheetLine3 =>
      'À la fin, le pare-feu normal revient tout seul. Vous pouvez arrêter avant, depuis Sentinel ou la notification.';

  @override
  String get analysisSheetLine4 =>
      'Le rapport reste sur ce téléphone 24 heures au plus, puis il est supprimé. Il n\'est jamais envoyé.';

  @override
  String analysisSheetLine5(String app) {
    return '$app va s\'ouvrir : utilisez-la normalement.';
  }

  @override
  String reportDateLine(String date, String duration) {
    return 'Analyse du $date · $duration';
  }

  @override
  String get reportDomainsContacted => 'Domaines contactés';

  @override
  String get reportDangerousSites => 'Sites dangereux';

  @override
  String get reportTruncated =>
      'Liste incomplète : l\'application a contacté trop de domaines différents.';

  @override
  String get reportSeeApp => 'Voir l\'application';

  @override
  String get reportDelete => 'Supprimer ce rapport';

  @override
  String reportLocalOnly(String date) {
    return 'Ce rapport reste uniquement sur ce téléphone, jusqu\'au $date, puis il est supprimé automatiquement. Il n\'est jamais envoyé.';
  }

  @override
  String get reportApproximate =>
      'Le nombre de requêtes est approximatif : Android garde certaines réponses en mémoire quelques minutes.';

  @override
  String reportRequests(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n requêtes',
      one: '$n requête',
    );
    return '$_temp0';
  }

  @override
  String reportImitates(String brand) {
    return 'Imite $brand';
  }

  @override
  String get reportBlocked => 'Bloqué';

  @override
  String get firewallIntro =>
      'Bloque les sites dangereux et les traqueurs avant même qu\'une application ne s\'y connecte. Tout se passe sur votre téléphone.';

  @override
  String get firewallSinceActivation => 'Depuis l\'activation';

  @override
  String get firewallQueriesAnalyzed => 'Requêtes analysées';

  @override
  String get firewallQueriesBlocked => 'Requêtes bloquées';

  @override
  String get firewallListsLoading => 'Chargement des listes…';

  @override
  String get firewallOneVpn =>
      'Android n\'autorise qu\'un seul VPN à la fois : si vous en activez un autre, le pare-feu s\'arrête.';

  @override
  String get firewallUpdated => 'Listes mises à jour.';

  @override
  String get firewallUpdateFailed =>
      'Mise à jour impossible : les listes actuelles sont conservées.';

  @override
  String get firewallInvalidDomain =>
      'Domaine invalide, par exemple : exemple.fr';

  @override
  String get firewallDomainRefused =>
      'Domaine refusé (format invalide ou liste pleine)';

  @override
  String get firewallExplain1 =>
      'Android va vous demander d\'autoriser une « connexion VPN » : c\'est ainsi que Sentinel voit les noms de sites demandés.';

  @override
  String get firewallExplain2 =>
      'Seules les demandes de noms de sites (DNS) passent par Sentinel, le reste de votre trafic ne change pas.';

  @override
  String get firewallExplain3 =>
      'Les sites autorisés sont demandés à Quad9 (résolveur suisse), de façon chiffrée : votre réseau ne voit plus les noms des sites.';

  @override
  String get firewallExplain4 =>
      'Aucun site visité n\'est enregistré : seuls des compteurs existent (sauf pendant une analyse d\'application que vous lancez vous-même).';

  @override
  String get firewallExplain5 =>
      'Une notification discrète reste affichée tant que le pare-feu est actif.';

  @override
  String get firewallUpdateTitle => 'Mise à jour des listes';

  @override
  String get firewallConsent1 =>
      'Sentinel télécharge les listes de blocage depuis GitHub (raw.githubusercontent.com), en HTTPS, au plus une fois par jour.';

  @override
  String get firewallConsent2 =>
      'Aucune information vous concernant n\'est envoyée : ni sites visités, ni identifiant. Comme pour toute connexion, GitHub voit l\'adresse IP de votre téléphone.';

  @override
  String get firewallConsent3 =>
      'Chaque liste est vérifiée (taille, format, cohérence) avant usage. En cas de problème, l\'ancienne version est conservée.';

  @override
  String get blocklistCacheNote =>
      'Les changements peuvent prendre quelques minutes à s\'appliquer (cache DNS du navigateur).';

  @override
  String get blocklistListsTitle => 'Listes de blocage';

  @override
  String get blocklistAdsWarning =>
      'Peut empêcher certaines applications de fonctionner.';

  @override
  String get blocklistImpersonationWarning =>
      'Peut bloquer un vrai site non répertorié : ajoutez-le alors à la liste blanche.';

  @override
  String get blocklistAutoUpdateTitle => 'Mises à jour automatiques';

  @override
  String get blocklistUpdateDaily => 'Mettre à jour chaque jour';

  @override
  String get blocklistUpdateNote =>
      'Les listes sont téléchargées en HTTPS depuis GitHub, au plus une fois par jour. Aucune information vous concernant n\'est envoyée.';

  @override
  String get blocklistUpdating => 'Mise à jour en cours…';

  @override
  String get blocklistUpdateNow => 'Mettre à jour';

  @override
  String get allowlistTitle => 'Liste blanche';

  @override
  String get allowlistIntro =>
      'Ces sites ne sont jamais bloqués, même s\'ils figurent dans une liste. Leurs sous-domaines non plus.';

  @override
  String get allowlistHint => 'exemple.fr';

  @override
  String get allowlistAdd => 'Ajouter';

  @override
  String get allowlistEmpty => 'Aucun site pour l\'instant.';

  @override
  String allowlistRemove(String domain) {
    return 'Retirer $domain';
  }

  @override
  String get sourcesTitle => 'Sources et licences';

  @override
  String get sourcesSeeSource => 'Voir la source';

  @override
  String get upstreamIdle => 'En attente de la première requête';

  @override
  String get upstreamDot => 'Chiffré (DNS-over-TLS)';

  @override
  String get upstreamDoh => 'Chiffré (DNS-over-HTTPS)';

  @override
  String get upstreamPlain => 'Non chiffré : autorisé sur ce réseau';

  @override
  String get upstreamFailing => 'Quad9 injoignable de façon chiffrée';

  @override
  String get upstreamFailingHelp =>
      'Ce réseau bloque le DNS chiffré : les sites ne s\'ouvrent pas. Sentinel n\'envoie jamais vos requêtes en clair sans votre accord. Si vous faites confiance à ce réseau, vous pouvez l\'autoriser ci-dessous : les noms des sites visités deviendront alors visibles sur le réseau.';

  @override
  String get upstreamLabel => 'Requêtes vers Quad9';

  @override
  String get upstreamAllowPlain => 'Autoriser le DNS non chiffré sur ce réseau';

  @override
  String get dnsStrictTitle => 'DNS privé incompatible';

  @override
  String dnsStrictMessage(String server) {
    return 'Votre DNS privé est réglé sur « $server » (mode strict). Avec le pare-feu, plus aucun site ne s\'ouvrirait. Choisissez « Automatique » dans les réglages : Sentinel chiffre déjà vos requêtes DNS.';
  }

  @override
  String get dnsStrictOpenSettings => 'Ouvrir les réglages du DNS privé';

  @override
  String get networkProtectionTitle => 'Protection réseau';

  @override
  String get vaultSettingsTitle => 'Réglages du coffre';

  @override
  String get vaultLock => 'Verrouiller';

  @override
  String get vaultEmptyTitle => 'Vos mots de passe, chiffrés';

  @override
  String get vaultEmptyMessage =>
      'Stockez vos mots de passe et notes secrètes. Ils sont chiffrés sur votre téléphone et personne d\'autre ne peut les lire.';

  @override
  String get vaultCreate => 'Créer mon coffre';

  @override
  String get vaultUnreadableTitle => 'Coffre illisible';

  @override
  String get vaultUnreadableMessage =>
      'Le fichier du coffre semble endommagé ou modifié. Sentinel ne peut pas l\'ouvrir.';

  @override
  String get vaultCreateFailed => 'La création du coffre a échoué.';

  @override
  String get vaultCreateIntro =>
      'Choisissez un mot de passe maître : il ouvre le coffre et chiffre tout son contenu.';

  @override
  String get vaultCreateWarning =>
      'Personne, pas même Sentinel, ne peut retrouver ce mot de passe. Vous recevrez ensuite une clé de récupération : notez-la, c\'est le seul moyen d\'ouvrir le coffre si vous l\'oubliez.';

  @override
  String get vaultMasterPassword => 'Mot de passe maître';

  @override
  String get vaultConfirmation => 'Confirmation';

  @override
  String get vaultPasswordsDiffer => 'Les deux mots de passe diffèrent';

  @override
  String get vaultUnderstood =>
      'J\'ai compris que ce mot de passe ne peut pas être récupéré';

  @override
  String get vaultCreating => 'Création…';

  @override
  String get vaultRestoreBackup => 'Restaurer une sauvegarde';

  @override
  String get vaultFingerprintsChanged =>
      'Les empreintes du téléphone ont changé. Ouvrez le coffre avec votre mot de passe, puis réactivez l\'empreinte.';

  @override
  String get vaultTooManyTries =>
      'Trop d\'essais. Utilisez votre mot de passe.';

  @override
  String get vaultFingerprintFailed =>
      'L\'empreinte n\'a pas pu ouvrir le coffre. Utilisez votre mot de passe.';

  @override
  String get vaultWeeklyPassword =>
      'Pour votre sécurité, le mot de passe maître est demandé au moins une fois tous les 7 jours.';

  @override
  String get vaultLockedTitle => 'Coffre verrouillé';

  @override
  String get vaultUseFingerprintOrPassword =>
      'Utilisez votre empreinte ou votre mot de passe maître.';

  @override
  String get vaultEnterMasterPassword => 'Entrez votre mot de passe maître.';

  @override
  String get vaultOpenWithFingerprint => 'Ouvrir avec l\'empreinte';

  @override
  String get vaultOrWithPassword => 'Ou avec le mot de passe :';

  @override
  String get vaultWrongPassword => 'Mot de passe incorrect.';

  @override
  String vaultRetryIn(String seconds) {
    return 'Réessayez dans $seconds s.';
  }

  @override
  String get vaultOpening => 'Ouverture…';

  @override
  String get vaultOpen => 'Ouvrir le coffre';

  @override
  String get vaultForgotPassword => 'Mot de passe oublié ?';

  @override
  String get vaultSaveFailed => 'L\'enregistrement a échoué.';

  @override
  String get vaultForgotTitle => 'Mot de passe oublié';

  @override
  String get vaultKeyAccepted =>
      'Clé acceptée. Choisissez un nouveau mot de passe maître.';

  @override
  String get vaultEnterRecoveryKey =>
      'Entrez la clé de récupération notée à la création du coffre. Les tirets et les minuscules sont acceptés.';

  @override
  String get vaultRecoveryKeyLabel => 'Clé de récupération';

  @override
  String get vaultWrongRecoveryKey => 'Clé de récupération incorrecte';

  @override
  String get vaultNewMasterPassword => 'Nouveau mot de passe maître';

  @override
  String get vaultNewKeyWillBeCreated =>
      'Une nouvelle clé de récupération sera créée ; l\'ancienne ne fonctionnera plus.';

  @override
  String get vaultSaving => 'Enregistrement…';

  @override
  String get vaultSave => 'Enregistrer';

  @override
  String vaultKeyCopied(String seconds) {
    return 'Clé copiée. Elle sera effacée du presse-papiers dans $seconds s.';
  }

  @override
  String get vaultYourRecoveryKey => 'Votre clé de récupération';

  @override
  String get vaultWriteKeyDown =>
      'Écrivez-la sur papier et gardez-la en lieu sûr. C\'est le seul moyen d\'ouvrir le coffre si vous oubliez votre mot de passe.';

  @override
  String get vaultKeyShownOnce => 'Elle ne sera plus jamais affichée.';

  @override
  String get vaultCopy => 'Copier';

  @override
  String get vaultRetypeLast4 =>
      'Pour vérifier que vous l\'avez notée, retapez ses 4 derniers caractères.';

  @override
  String get vaultLast4Label => '4 derniers caractères';

  @override
  String get vaultKeyNoted => 'J\'ai noté ma clé';

  @override
  String get vaultKeyCreateFailed => 'La création de la clé a échoué.';

  @override
  String get vaultKeyOfferTitle => 'Nouveau : la clé de récupération';

  @override
  String get vaultKeyOfferText =>
      'Si vous oubliez votre mot de passe maître, une clé de récupération est le seul moyen d\'ouvrir le coffre. Créez-la maintenant et notez-la sur papier.';

  @override
  String get vaultCreateKey => 'Créer ma clé';

  @override
  String get backupEmpty => 'Ce fichier est vide.';

  @override
  String get backupUnreadable =>
      'Ce fichier n\'est pas une sauvegarde Sentinel, ou il est abîmé.';

  @override
  String get backupNewerVersion =>
      'Cette sauvegarde vient d\'une version plus récente de Sentinel. Mettez l\'application à jour, puis réessayez.';

  @override
  String get backupTooBig =>
      'Ce fichier est trop gros pour être une sauvegarde Sentinel.';

  @override
  String get backupCannotReadFile => 'Impossible de lire ce fichier.';

  @override
  String get backupWrongPassword =>
      'Mot de passe incorrect, ou fichier modifié depuis l\'export.';

  @override
  String get backupCannotRead => 'Impossible de lire cette sauvegarde.';

  @override
  String get backupRestoreFailed => 'La restauration a échoué.';

  @override
  String get backupIntroFile =>
      'Choisissez le fichier .sentinel créé avec « Exporter une sauvegarde chiffrée » sur votre ancien téléphone.';

  @override
  String get backupIntroPassword =>
      'Entrez le mot de passe choisi au moment de l\'export.';

  @override
  String backupIntroNewPassword(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n éléments',
      one: '$n élément',
    );
    return 'Sauvegarde ouverte : $_temp0. Choisissez le mot de passe maître de ce téléphone.';
  }

  @override
  String get backupPasswordLabel => 'Mot de passe de la sauvegarde';

  @override
  String get backupNewKeyNote =>
      'Une nouvelle clé de récupération sera créée pour ce téléphone.';

  @override
  String get backupChooseFile => 'Choisir le fichier';

  @override
  String get backupRestoring => 'Restauration…';

  @override
  String get backupRestore => 'Restaurer';

  @override
  String get vaultAdd => 'Ajouter';

  @override
  String get vaultEmptyList =>
      'Votre coffre est vide. Ajoutez un premier mot de passe ou une note secrète.';

  @override
  String get vaultNoResults => 'Aucun résultat.';

  @override
  String get vaultHealthTitle => 'Santé des mots de passe';

  @override
  String get vaultAllGood => 'Tout va bien';

  @override
  String vaultToFix(String count) {
    return '$count à corriger';
  }

  @override
  String get vaultSearch => 'Rechercher';

  @override
  String get vaultTypePassword => 'Mot de passe';

  @override
  String get vaultTypeNote => 'Note secrète';

  @override
  String vaultPasswordCopied(String seconds) {
    return 'Mot de passe copié. Il sera effacé du presse-papiers dans $seconds s.';
  }

  @override
  String get vaultNeedTitle => 'Donnez un titre à cet élément.';

  @override
  String vaultDeleteItemTitle(String title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String get vaultDeleteItemText =>
      'Cet élément sera définitivement effacé du coffre.';

  @override
  String get vaultDelete => 'Supprimer';

  @override
  String get vaultNewPassword => 'Nouveau : mot de passe';

  @override
  String get vaultNewNote => 'Nouveau : note secrète';

  @override
  String get vaultFieldTitle => 'Titre';

  @override
  String get vaultFieldNote => 'Note';

  @override
  String get vaultFieldUsername => 'Identifiant';

  @override
  String get vaultFieldWebsite => 'Site web';

  @override
  String get vaultHideGenerator => 'Masquer le générateur';

  @override
  String get vaultGenerate => 'Générer';

  @override
  String generatorLength(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Longueur : $n caractères',
      one: 'Longueur : $n caractère',
    );
    return '$_temp0';
  }

  @override
  String get generatorUppercase => 'Majuscules (A-Z)';

  @override
  String get generatorDigits => 'Chiffres (0-9)';

  @override
  String get generatorSymbols => 'Symboles (!#\$…)';

  @override
  String get generatorNewPassword => 'Nouveau mot de passe';

  @override
  String healthToFix(String count) {
    return '$count à corriger. Touchez un élément pour changer son mot de passe.';
  }

  @override
  String get healthBreached => 'Trouvés dans des fuites';

  @override
  String get healthNoBreach => 'Aucun mot de passe trouvé dans une fuite.';

  @override
  String get healthReused => 'Utilisés plusieurs fois';

  @override
  String get healthAllUnique => 'Chaque mot de passe est unique.';

  @override
  String healthAlsoUsedFor(String titles) {
    return 'Aussi utilisé pour : $titles';
  }

  @override
  String get healthWeak => 'Trop faibles';

  @override
  String get healthNoWeak => 'Aucun mot de passe trop faible.';

  @override
  String get healthEasyToGuess => 'Facile à deviner';

  @override
  String get healthCheckIntro =>
      'Vérifiez si vos mots de passe apparaissent dans des fuites connues (Have I Been Pwned).';

  @override
  String get healthCheckButton => 'Vérifier les fuites';

  @override
  String healthChecking(String done, String total) {
    return 'Vérification… $done / $total';
  }

  @override
  String get healthRetry => 'Réessayer';

  @override
  String breachMessage(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ce mot de passe a été vu $n fois dans des fuites de données. Changez-le.',
    );
    return '$_temp0';
  }

  @override
  String breachShort(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vu $n fois dans des fuites',
    );
    return '$_temp0';
  }

  @override
  String get breachConsentTitle => 'Vérifier les fuites ?';

  @override
  String get breachConsentText =>
      'Sentinel envoie seulement les 5 premiers caractères d\'une empreinte (hash) de chaque mot de passe à Have I Been Pwned. Votre mot de passe ne quitte jamais le téléphone.';

  @override
  String get breachConsentDetail =>
      'Le service répond avec une liste de fuites connues, et la comparaison se fait sur votre téléphone. Vous pourrez retirer cet accord dans les réglages du coffre.';

  @override
  String get breachConsentCheck => 'Vérifier';

  @override
  String get breachErrorTimeout =>
      'Le service ne répond pas. Réessayez plus tard.';

  @override
  String get breachErrorOffline =>
      'Pas de connexion Internet. Vérifiez le Wi-Fi ou les données mobiles.';

  @override
  String get breachErrorTooMany =>
      'Trop de demandes. Réessayez dans un instant.';

  @override
  String breachErrorUnavailable(String code) {
    return 'Le service Have I Been Pwned est indisponible (erreur $code).';
  }

  @override
  String get clipboardSharedTitle => 'Presse-papiers partagé';

  @override
  String get clipboardSharedWarning =>
      'Sur cette version d\'Android, toutes les applications peuvent lire ce que vous copiez. Le presse-papiers sera vidé après 10 secondes.';

  @override
  String get clipboardCopyAnyway => 'Copier quand même';

  @override
  String get fieldShow => 'Afficher';

  @override
  String get fieldHide => 'Masquer';

  @override
  String get strengthWeak => 'faible';

  @override
  String get strengthMedium => 'moyen';

  @override
  String get strengthStrong => 'fort';

  @override
  String strengthLine(String strength) {
    return 'Force : $strength';
  }

  @override
  String strengthLineTooShort(String strength, String length, String min) {
    return 'Force : $strength · $length / $min caractères minimum';
  }

  @override
  String get vaultFingerprintEnabled => 'Ouverture par l\'empreinte activée.';

  @override
  String get vaultBiometricTooManyTries =>
      'Trop d\'essais. Réessayez dans quelques instants.';

  @override
  String get vaultNoFingerprint =>
      'Aucune empreinte enregistrée sur ce téléphone.';

  @override
  String get vaultFingerprintActivationFailed =>
      'L\'activation de l\'empreinte a échoué.';

  @override
  String get vaultNewKeyTitle => 'Nouvelle clé de récupération ?';

  @override
  String get vaultNewKeyText =>
      'L\'ancienne clé ne fonctionnera plus. Pensez à noter la nouvelle.';

  @override
  String get vaultDeleteFailed => 'La suppression a échoué.';

  @override
  String get vaultFingerprintWeekly =>
      'Le mot de passe reste demandé au moins une fois tous les 7 jours.';

  @override
  String get vaultBreachSettingDetail =>
      'Have I Been Pwned. Seul un début d\'empreinte est envoyé, jamais le mot de passe.';

  @override
  String get vaultChangeMaster => 'Changer le mot de passe maître';

  @override
  String get vaultNewRecoveryKey => 'Générer une nouvelle clé de récupération';

  @override
  String get vaultExport => 'Exporter une sauvegarde chiffrée';

  @override
  String get vaultDeleteVault => 'Supprimer le coffre';

  @override
  String get vaultDeleteVaultTitle => 'Supprimer le coffre ?';

  @override
  String vaultDeleteVaultText(String word) {
    return 'Tous les mots de passe et notes seront définitivement effacés. Tapez $word pour confirmer.';
  }

  @override
  String get vaultDeleteWord => 'SUPPRIMER';

  @override
  String get vaultMasterChanged => 'Mot de passe maître changé.';

  @override
  String get vaultCurrentPassword => 'Mot de passe actuel';

  @override
  String get vaultWrongPasswordShort => 'Mot de passe incorrect';

  @override
  String get vaultChange => 'Changer';

  @override
  String get exportSaved =>
      'Sauvegarde enregistrée. Gardez son mot de passe en lieu sûr.';

  @override
  String get exportCancelled => 'Export annulé.';

  @override
  String get exportFileFailed => 'L\'enregistrement du fichier a échoué.';

  @override
  String get exportFailed => 'L\'export a échoué.';

  @override
  String get exportIntro =>
      'Pour passer à un nouveau téléphone : un fichier .sentinel, chiffré par le mot de passe choisi ici. Sans ce mot de passe, personne ne peut le lire, pas même Sentinel.';

  @override
  String get exportStore =>
      'Rangez le fichier où vous voulez (Drive, clé USB, ordinateur) et ne le perdez pas avec son mot de passe.';

  @override
  String get exportPasswordLabel => 'Mot de passe d\'export';

  @override
  String get exportEncrypting => 'Chiffrement…';

  @override
  String get exportButton => 'Exporter';

  @override
  String get qrScanButton => 'Scanner un QR code';

  @override
  String get qrScanSubtitle =>
      'Vérifier un QR code (affiche, parcmètre, colis) avant de l\'ouvrir';

  @override
  String get qrScanPrompt =>
      'Placez le QR code dans le cadre. Rien ne s\'ouvre tout seul.';

  @override
  String get qrCameraTitle => 'Autoriser la caméra ?';

  @override
  String get qrCameraText =>
      'Sentinel utilise la caméra seulement pendant le scan, pour lire le QR code. L\'image n\'est ni enregistrée ni envoyée : tout reste sur le téléphone.';

  @override
  String get qrOpenSettings => 'Réglages';

  @override
  String get qrErrorNoCamera => 'Aucune caméra disponible sur ce téléphone.';

  @override
  String get qrErrorPermissionDenied =>
      'Sans la caméra, Sentinel ne peut pas lire le QR code.';

  @override
  String get qrErrorPermissionBlocked =>
      'La caméra est refusée pour Sentinel. Autorisez-la dans les réglages d\'Android.';

  @override
  String get qrErrorFailed => 'Le scan a échoué. Réessayez.';

  @override
  String get qrResultTitle => 'QR code scanné';

  @override
  String get qrRawContent => 'Contenu brut';

  @override
  String get qrEmpty => '(QR code vide)';

  @override
  String get qrKindLink => 'Lien';

  @override
  String get qrKindUnsafeLink => 'Lien d\'un type dangereux';

  @override
  String get qrKindWifi => 'Réseau Wi-Fi';

  @override
  String get qrKindPhone => 'Numéro de téléphone';

  @override
  String get qrKindSms => 'SMS à envoyer';

  @override
  String get qrKindPayment => 'Demande de paiement';

  @override
  String get qrKindText => 'Texte';

  @override
  String get qrWifiName => 'Réseau';

  @override
  String get qrWifiSecurity => 'Protection';

  @override
  String get qrWifiPassword => 'Mot de passe';

  @override
  String get qrWifiPasswordYes => 'Inclus dans le QR code';

  @override
  String get qrWifiPasswordNo => 'Aucun';

  @override
  String get qrPhoneNumber => 'Numéro';

  @override
  String get qrSmsRecipient => 'Destinataire';

  @override
  String get qrSmsText => 'Texte du SMS';

  @override
  String get qrPaymentRecipient => 'Bénéficiaire';

  @override
  String get qrPaymentAmount => 'Montant';

  @override
  String get qrNotSpecified => 'Non indiqué';

  @override
  String get qrWarningUnsafeLink =>
      'Ce QR code contient un lien qui peut lancer du code ou ouvrir un fichier, pas une page web. Sentinel ne l\'ouvrira pas.';

  @override
  String get qrWarningUssd =>
      'Le numéro contient * ou # : c\'est un code qui peut changer les réglages du téléphone (renvoi d\'appel, effacement). Ne le composez pas.';

  @override
  String get qrWarningShortNumber =>
      'Numéro court : un SMS vers ce type de numéro peut être surtaxé ou vous abonner à un service payant.';

  @override
  String get qrWarningPayment =>
      'Les faux QR codes de paiement sont souvent collés par-dessus les vrais (parcmètres, affiches). Vérifiez le bénéficiaire et le montant avant de payer.';

  @override
  String get qrWarningWifiOpen =>
      'Réseau ouvert : sans mot de passe, tout ce qui passe en clair peut être lu par les autres.';

  @override
  String get qrWarningWifiWep =>
      'Protection WEP : elle se casse en quelques minutes.';

  @override
  String get qrActionOpenLink => 'Ouvrir le lien';

  @override
  String get qrActionOpenAnyway => 'Ouvrir quand même';

  @override
  String get qrActionCall => 'Appeler ce numéro';

  @override
  String get qrActionSms => 'Préparer le SMS';

  @override
  String get qrActionPayment => 'Ouvrir dans une app de paiement';

  @override
  String get qrActionBlocked => 'Bloqué par Sentinel : arnaque probable.';

  @override
  String get qrActionFailed =>
      'Impossible d\'ouvrir : aucune app compatible ou contenu refusé.';

  @override
  String qrConfirmLink(String url) {
    return 'Ne saisissez aucun code ni mot de passe si la page vous le demande. Lien qui va s\'ouvrir dans votre navigateur : $url';
  }

  @override
  String qrConfirmCall(String number) {
    return 'Le téléphone ouvre l\'écran d\'appel avec le $number. L\'appel ne part que si vous appuyez sur Appeler.';
  }

  @override
  String qrConfirmSms(String number) {
    return 'Votre app SMS s\'ouvre avec un message pour le $number. Rien n\'est envoyé tant que vous n\'appuyez pas sur Envoyer.';
  }

  @override
  String qrConfirmPayment(String recipient) {
    return 'Une app de paiement va s\'ouvrir pour : $recipient. Vérifiez le bénéficiaire et le montant avant de valider.';
  }
}
