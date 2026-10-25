import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// Nom de l'app (ne pas traduire)
  ///
  /// In fr, this message translates to:
  /// **'Sentinel'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonCancel;

  /// No description provided for @commonContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get commonContinue;

  /// No description provided for @commonLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get commonLater;

  /// No description provided for @commonAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get commonAccept;

  /// No description provided for @commonClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get commonClose;

  /// No description provided for @commonDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails'**
  String get commonDetails;

  /// No description provided for @commonOn.
  ///
  /// In fr, this message translates to:
  /// **'Activé'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get commonOff;

  /// Pour « la protection »
  ///
  /// In fr, this message translates to:
  /// **'Désactivée'**
  String get commonOffFeminine;

  /// No description provided for @commonUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get commonUnknown;

  /// Pour « la date »
  ///
  /// In fr, this message translates to:
  /// **'Inconnue'**
  String get commonUnknownFeminine;

  /// No description provided for @commonYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get commonNo;

  /// No description provided for @commonAndroidOnly.
  ///
  /// In fr, this message translates to:
  /// **'Disponible sur Android'**
  String get commonAndroidOnly;

  /// No description provided for @commonOpenSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get commonOpenSettings;

  /// No description provided for @commonComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get commonComingSoon;

  /// No description provided for @commonAnalysisFailedPull.
  ///
  /// In fr, this message translates to:
  /// **'L\'analyse a échoué. Tirez vers le bas pour réessayer.'**
  String get commonAnalysisFailedPull;

  /// Date puis heure, déjà formatées
  ///
  /// In fr, this message translates to:
  /// **'{date} à {time}'**
  String commonDateAtTime(String date, String time);

  /// Sous le score de l'arche
  ///
  /// In fr, this message translates to:
  /// **'sur 100'**
  String get commonOutOf100;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navApps.
  ///
  /// In fr, this message translates to:
  /// **'Applications'**
  String get navApps;

  /// No description provided for @navMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @navVault.
  ///
  /// In fr, this message translates to:
  /// **'Coffre'**
  String get navVault;

  /// Salutation neutre, sans prénom (SEN-16)
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get homeGreeting;

  /// No description provided for @homeTitleFailed.
  ///
  /// In fr, this message translates to:
  /// **'Analyse impossible'**
  String get homeTitleFailed;

  /// No description provided for @homeTitleDefault.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité du téléphone'**
  String get homeTitleDefault;

  /// No description provided for @homeTitleProtected.
  ///
  /// In fr, this message translates to:
  /// **'Votre téléphone est bien protégé'**
  String get homeTitleProtected;

  /// No description provided for @homeTitleToImprove.
  ///
  /// In fr, this message translates to:
  /// **'Quelques points à renforcer'**
  String get homeTitleToImprove;

  /// No description provided for @homeTitleExposed.
  ///
  /// In fr, this message translates to:
  /// **'Votre téléphone est exposé'**
  String get homeTitleExposed;

  /// No description provided for @homeAndroidVersion.
  ///
  /// In fr, this message translates to:
  /// **'Android {version}'**
  String homeAndroidVersion(String version);

  /// No description provided for @homeAndroidVersionPatch.
  ///
  /// In fr, this message translates to:
  /// **'Android {version} · correctif du {date}'**
  String homeAndroidVersionPatch(String version, String date);

  /// No description provided for @homeAnalyzing.
  ///
  /// In fr, this message translates to:
  /// **'Analyse en cours…'**
  String get homeAnalyzing;

  /// No description provided for @homeAndroidOnly.
  ///
  /// In fr, this message translates to:
  /// **'L\'analyse du téléphone est disponible sur Android.'**
  String get homeAndroidOnly;

  /// No description provided for @homeToGainPoints.
  ///
  /// In fr, this message translates to:
  /// **'Pour gagner des points'**
  String get homeToGainPoints;

  /// No description provided for @homeNothingToFix.
  ///
  /// In fr, this message translates to:
  /// **'Rien à corriger pour le moment.'**
  String get homeNothingToFix;

  /// Bandeau Wi-Fi dangereux ; title = nom du réseau à risque
  ///
  /// In fr, this message translates to:
  /// **'{title} : évitez la banque et les achats.'**
  String homeWifiAlert(String title);

  /// No description provided for @scoreLockTitle.
  ///
  /// In fr, this message translates to:
  /// **'Configurer un verrouillage d\'écran'**
  String get scoreLockTitle;

  /// No description provided for @scoreLockDesc.
  ///
  /// In fr, this message translates to:
  /// **'Un code ou un schéma empêche l\'accès à vos données si le téléphone est perdu'**
  String get scoreLockDesc;

  /// No description provided for @scoreRootTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre téléphone semble rooté'**
  String get scoreRootTitle;

  /// No description provided for @scoreRootDesc.
  ///
  /// In fr, this message translates to:
  /// **'Le root contourne les protections d\'Android. Il ne se retire pas depuis les paramètres'**
  String get scoreRootDesc;

  /// No description provided for @scoreUpdateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Installer la mise à jour de sécurité'**
  String get scoreUpdateTitle;

  /// No description provided for @scoreUpdateUnknown.
  ///
  /// In fr, this message translates to:
  /// **'La date du dernier correctif est inconnue'**
  String get scoreUpdateUnknown;

  /// No description provided for @scoreUpdateOld.
  ///
  /// In fr, this message translates to:
  /// **'Le dernier correctif date de plus de 3 mois'**
  String get scoreUpdateOld;

  /// No description provided for @scoreBiometricTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activer le déverrouillage biométrique'**
  String get scoreBiometricTitle;

  /// No description provided for @scoreBiometricDesc.
  ///
  /// In fr, this message translates to:
  /// **'Empreinte ou visage pour ouvrir le téléphone'**
  String get scoreBiometricDesc;

  /// No description provided for @scoreDevOptionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver les options pour les développeurs'**
  String get scoreDevOptionsTitle;

  /// No description provided for @scoreDevOptionsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Elles donnent accès à des réglages sensibles du système'**
  String get scoreDevOptionsDesc;

  /// No description provided for @scoreUsbTitle.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver le débogage USB'**
  String get scoreUsbTitle;

  /// No description provided for @scoreUsbDesc.
  ///
  /// In fr, this message translates to:
  /// **'Un ordinateur branché pourrait accéder à vos données'**
  String get scoreUsbDesc;

  /// No description provided for @scoreEncryptTitle.
  ///
  /// In fr, this message translates to:
  /// **'Chiffrer le stockage'**
  String get scoreEncryptTitle;

  /// No description provided for @scoreEncryptDesc.
  ///
  /// In fr, this message translates to:
  /// **'Vos fichiers restent illisibles sans votre code'**
  String get scoreEncryptDesc;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get settingsTitle;

  /// No description provided for @settingsAppVersion.
  ///
  /// In fr, this message translates to:
  /// **'Sentinel {version}'**
  String settingsAppVersion(String version);

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In fr, this message translates to:
  /// **'Langue du téléphone'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsReplayOnboarding.
  ///
  /// In fr, this message translates to:
  /// **'Revoir la présentation'**
  String get settingsReplayOnboarding;

  /// No description provided for @settingsPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get settingsPrivacy;

  /// No description provided for @settingsLicenses.
  ///
  /// In fr, this message translates to:
  /// **'Licences'**
  String get settingsLicenses;

  /// No description provided for @settingsLicensesDetail.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèques, police, listes de blocage, logiciels espions'**
  String get settingsLicensesDetail;

  /// No description provided for @settingsLicenseLegalese.
  ///
  /// In fr, this message translates to:
  /// **'Licence MIT'**
  String get settingsLicenseLegalese;

  /// No description provided for @settingsAudit.
  ///
  /// In fr, this message translates to:
  /// **'Rapport d\'audit de sécurité'**
  String get settingsAudit;

  /// No description provided for @settingsReportFlaw.
  ///
  /// In fr, this message translates to:
  /// **'Signaler une faille'**
  String get settingsReportFlaw;

  /// No description provided for @settingsReportFlawDetail.
  ///
  /// In fr, this message translates to:
  /// **'En privé, via GitHub (ouvre le navigateur)'**
  String get settingsReportFlawDetail;

  /// No description provided for @onboardingNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get onboardingStart;

  /// No description provided for @onboarding1Title.
  ///
  /// In fr, this message translates to:
  /// **'Sentinel veille sur votre téléphone'**
  String get onboarding1Title;

  /// No description provided for @onboarding1Line1.
  ///
  /// In fr, this message translates to:
  /// **'Un score de sécurité et les réglages à corriger.'**
  String get onboarding1Line1;

  /// No description provided for @onboarding1Line2.
  ///
  /// In fr, this message translates to:
  /// **'Les applications suspectes : fausses apps, logiciels espions.'**
  String get onboarding1Line2;

  /// No description provided for @onboarding1Line3.
  ///
  /// In fr, this message translates to:
  /// **'Les messages d\'arnaque, analysés sur le téléphone.'**
  String get onboarding1Line3;

  /// No description provided for @onboarding1Line4.
  ///
  /// In fr, this message translates to:
  /// **'Un coffre chiffré pour vos mots de passe.'**
  String get onboarding1Line4;

  /// No description provided for @onboarding1Line5.
  ///
  /// In fr, this message translates to:
  /// **'Un pare-feu qui bloque les sites dangereux et les traqueurs.'**
  String get onboarding1Line5;

  /// No description provided for @onboarding2Title.
  ///
  /// In fr, this message translates to:
  /// **'Tout reste sur votre téléphone'**
  String get onboarding2Title;

  /// No description provided for @onboarding2Line1.
  ///
  /// In fr, this message translates to:
  /// **'Pas de compte, pas de publicité, pas de statistiques. Vos messages, vos mots de passe et la liste de vos applications ne quittent jamais le téléphone.'**
  String get onboarding2Line1;

  /// No description provided for @onboarding2Line2.
  ///
  /// In fr, this message translates to:
  /// **'Seuls trois échanges réseau existent, tous facultatifs, et seulement si vous les activez :'**
  String get onboarding2Line2;

  /// No description provided for @onboarding2Line3.
  ///
  /// In fr, this message translates to:
  /// **'• Vérifier les fuites de mots de passe (Have I Been Pwned) : 5 caractères d\'une empreinte, jamais le mot de passe.'**
  String get onboarding2Line3;

  /// No description provided for @onboarding2Line4.
  ///
  /// In fr, this message translates to:
  /// **'• Pare-feu DNS : les noms des sites autorisés sont transmis, chiffrés, au résolveur Quad9.'**
  String get onboarding2Line4;

  /// No description provided for @onboarding2Line5.
  ///
  /// In fr, this message translates to:
  /// **'• Mise à jour des listes de blocage : un simple téléchargement depuis GitHub.'**
  String get onboarding2Line5;

  /// No description provided for @onboarding3Title.
  ///
  /// In fr, this message translates to:
  /// **'Les autorisations, au bon moment'**
  String get onboarding3Title;

  /// No description provided for @onboarding3Line1.
  ///
  /// In fr, this message translates to:
  /// **'Sentinel ne demande rien maintenant.'**
  String get onboarding3Line1;

  /// No description provided for @onboarding3Line2.
  ///
  /// In fr, this message translates to:
  /// **'Chaque autorisation (notifications, accès aux notifications, VPN, biométrie) est demandée seulement quand vous activez la fonction qui en a besoin, avec une explication.'**
  String get onboarding3Line2;

  /// No description provided for @onboarding3Line3.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez tout désactiver à tout moment.'**
  String get onboarding3Line3;

  /// No description provided for @privacyBriefTitle.
  ///
  /// In fr, this message translates to:
  /// **'En bref'**
  String get privacyBriefTitle;

  /// No description provided for @privacyBrief1.
  ///
  /// In fr, this message translates to:
  /// **'Sentinel n\'a ni serveur, ni compte, ni publicité, ni statistiques d\'utilisation, ni rapport de plantage. Toutes les analyses se font sur le téléphone.'**
  String get privacyBrief1;

  /// No description provided for @privacyBrief2.
  ///
  /// In fr, this message translates to:
  /// **'Sentinel ne contacte Internet que pour les trois fonctions facultatives ci-dessous, et seulement après votre accord.'**
  String get privacyBrief2;

  /// No description provided for @privacyNetworkTitle.
  ///
  /// In fr, this message translates to:
  /// **'Les seuls échanges réseau (facultatifs)'**
  String get privacyNetworkTitle;

  /// No description provided for @privacyNetwork1.
  ///
  /// In fr, this message translates to:
  /// **'1. Vérification des fuites de mots de passe (coffre). Après votre accord, Sentinel calcule l\'empreinte SHA-1 de chaque mot de passe et envoie seulement ses 5 premiers caractères à Have I Been Pwned (api.pwnedpasswords.com), en HTTPS. Le mot de passe et son empreinte complète ne quittent jamais le téléphone. Le service voit votre adresse IP. Vous pouvez retirer cet accord ; les résultats sont alors effacés.'**
  String get privacyNetwork1;

  /// No description provided for @privacyNetwork2.
  ///
  /// In fr, this message translates to:
  /// **'2. Pare-feu DNS. Quand vous l\'activez, les noms des sites demandés par vos applications passent par Sentinel. Les sites bloqués reçoivent une réponse sur le téléphone ; les autres noms sont transmis au résolveur Quad9, chiffrés (DNS sur TLS ou sur HTTPS). Quad9 voit ces noms et votre adresse IP, selon sa propre politique de confidentialité. Si un réseau bloque le DNS chiffré, rien ne part en clair, sauf si vous l\'autorisez pour ce réseau.'**
  String get privacyNetwork2;

  /// No description provided for @privacyNetwork3.
  ///
  /// In fr, this message translates to:
  /// **'3. Mise à jour des listes de blocage. Désactivée par défaut. Si vous la lancez ou activez la mise à jour automatique (au plus une fois par jour), Sentinel télécharge les listes depuis GitHub (raw.githubusercontent.com), sans cookie ni information sur vous. GitHub voit votre adresse IP.'**
  String get privacyNetwork3;

  /// No description provided for @privacyNetwork4.
  ///
  /// In fr, this message translates to:
  /// **'Les liens « Ouvrir le site » (conseils, sources, rapport d\'audit) s\'ouvrent dans votre navigateur, seulement quand vous les touchez.'**
  String get privacyNetwork4;

  /// No description provided for @privacyLocalTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui reste sur le téléphone'**
  String get privacyLocalTitle;

  /// No description provided for @privacyLocal1.
  ///
  /// In fr, this message translates to:
  /// **'Le coffre (mots de passe, notes) : chiffré avec votre mot de passe maître (Argon2id, AES-256-GCM).'**
  String get privacyLocal1;

  /// No description provided for @privacyLocal2.
  ///
  /// In fr, this message translates to:
  /// **'Vos choix : accord pour la vérification des fuites, réglages du pare-feu et liste des sites autorisés, protection automatique activée ou non, présentation déjà vue, langue.'**
  String get privacyLocal2;

  /// No description provided for @privacyLocal3.
  ///
  /// In fr, this message translates to:
  /// **'Les listes de blocage et leurs mises à jour.'**
  String get privacyLocal3;

  /// No description provided for @privacyLocal4.
  ///
  /// In fr, this message translates to:
  /// **'Les rapports « Analyser une application » : la liste des sites contactés par l\'application choisie, effacés au plus tard 24 h après l\'analyse.'**
  String get privacyLocal4;

  /// No description provided for @privacyLocal5.
  ///
  /// In fr, this message translates to:
  /// **'La sauvegarde Android est désactivée : rien ne part dans le cloud. Une sauvegarde du coffre (fichier .sentinel chiffré) n\'est créée que si vous la demandez, à l\'endroit que vous choisissez.'**
  String get privacyLocal5;

  /// No description provided for @privacyNeverTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce que Sentinel n\'enregistre jamais'**
  String get privacyNeverTitle;

  /// No description provided for @privacyNever1.
  ///
  /// In fr, this message translates to:
  /// **'Le texte des messages analysés (collés, partagés ou lus dans les notifications) : il est analysé en mémoire puis oublié.'**
  String get privacyNever1;

  /// No description provided for @privacyNever2.
  ///
  /// In fr, this message translates to:
  /// **'Votre historique de navigation : le pare-feu ne garde que des compteurs, jamais un nom de site (sauf pendant une analyse d\'application que vous lancez).'**
  String get privacyNever2;

  /// No description provided for @privacyNever3.
  ///
  /// In fr, this message translates to:
  /// **'Le nom du Wi-Fi et votre position : Sentinel ne demande pas la localisation.'**
  String get privacyNever3;

  /// No description provided for @privacyPermissionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Les autorisations'**
  String get privacyPermissionsTitle;

  /// No description provided for @privacyPermissions1.
  ///
  /// In fr, this message translates to:
  /// **'Liste des applications installées : pour repérer les fausses apps et les logiciels espions. Elle n\'est jamais envoyée.'**
  String get privacyPermissions1;

  /// No description provided for @privacyPermissions2.
  ///
  /// In fr, this message translates to:
  /// **'Notifications : demandée quand vous activez la protection automatique ou le pare-feu, pour afficher les alertes.'**
  String get privacyPermissions2;

  /// No description provided for @privacyPermissions3.
  ///
  /// In fr, this message translates to:
  /// **'Accès aux notifications : réglage Android que vous ouvrez vous-même pour la protection automatique ; Sentinel lit les messages reçus pour y chercher des arnaques.'**
  String get privacyPermissions3;

  /// No description provided for @privacyPermissions4.
  ///
  /// In fr, this message translates to:
  /// **'VPN : demandé quand vous activez le pare-feu. Il ne capte que le DNS, pas le reste du trafic.'**
  String get privacyPermissions4;

  /// No description provided for @privacyPermissions5.
  ///
  /// In fr, this message translates to:
  /// **'Biométrie : seulement si vous choisissez de déverrouiller le coffre sans taper votre mot de passe maître.'**
  String get privacyPermissions5;

  /// No description provided for @privacyEraseTitle.
  ///
  /// In fr, this message translates to:
  /// **'Effacer vos données'**
  String get privacyEraseTitle;

  /// No description provided for @privacyErase1.
  ///
  /// In fr, this message translates to:
  /// **'Désinstaller Sentinel efface tout ce qu\'il a enregistré sur le téléphone. Il n\'existe aucune copie ailleurs.'**
  String get privacyErase1;

  /// No description provided for @auditFrameTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le cadre'**
  String get auditFrameTitle;

  /// No description provided for @auditFrame1.
  ///
  /// In fr, this message translates to:
  /// **'Audit de sécurité selon le référentiel OWASP MASVS v2, du 21 au 24 octobre 2026, sur Sentinel 1.0.0 : analyse du code, du trafic réseau, du stockage et des composants Android.'**
  String get auditFrame1;

  /// No description provided for @auditFrame2.
  ///
  /// In fr, this message translates to:
  /// **'Il a été mené pour le propriétaire de l\'application, sur son propre code : ce n\'est pas un audit indépendant.'**
  String get auditFrame2;

  /// No description provided for @auditResultsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Les résultats'**
  String get auditResultsTitle;

  /// No description provided for @auditResults1.
  ///
  /// In fr, this message translates to:
  /// **'17 constats, dont un de sévérité élevée et quatre moyens.'**
  String get auditResults1;

  /// No description provided for @auditResults2.
  ///
  /// In fr, this message translates to:
  /// **'14 sont corrigés, chacun avec un test automatique. 3 sont acceptés en connaissance de cause (modèle anti-arnaque lisible car l\'app est open source, pas d\'épinglage de certificat, un constat déjà conforme).'**
  String get auditResults2;

  /// No description provided for @auditResults3.
  ///
  /// In fr, this message translates to:
  /// **'Depuis, le pare-feu chiffre toutes ses requêtes et l\'app ne contacte plus rien sans accord.'**
  String get auditResults3;

  /// No description provided for @auditLimitsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Les limites'**
  String get auditLimitsTitle;

  /// No description provided for @auditLimits1.
  ///
  /// In fr, this message translates to:
  /// **'Aucune application n\'est sûre à 100 %. Les principaux risques restants dépendent du téléphone : un Android trop ancien, ou un logiciel espion à qui l\'on a donné l\'accessibilité ou le root.'**
  String get auditLimits1;

  /// No description provided for @auditReadFull.
  ///
  /// In fr, this message translates to:
  /// **'Lire le rapport complet sur GitHub'**
  String get auditReadFull;

  /// No description provided for @verdictScam.
  ///
  /// In fr, this message translates to:
  /// **'Arnaque probable'**
  String get verdictScam;

  /// No description provided for @verdictSuspect.
  ///
  /// In fr, this message translates to:
  /// **'Suspect'**
  String get verdictSuspect;

  /// No description provided for @verdictNothing.
  ///
  /// In fr, this message translates to:
  /// **'Rien de suspect'**
  String get verdictNothing;

  /// No description provided for @adviceScam.
  ///
  /// In fr, this message translates to:
  /// **'Ne cliquez pas sur le lien et ne communiquez aucun code. Votre banque ou La Poste ne vous demandent jamais de payer par SMS. Supprimez ce message.'**
  String get adviceScam;

  /// No description provided for @adviceSuspect.
  ///
  /// In fr, this message translates to:
  /// **'Soyez prudent : n\'ouvrez pas le lien et ne donnez aucune information. En cas de doute, appelez l\'organisme au numéro de son site officiel.'**
  String get adviceSuspect;

  /// No description provided for @adviceNothing.
  ///
  /// In fr, this message translates to:
  /// **'Aucun signe d\'arnaque trouvé. Restez quand même vigilant : ne communiquez jamais vos codes ni vos mots de passe.'**
  String get adviceNothing;

  /// No description provided for @reasonHiddenCharacters.
  ///
  /// In fr, this message translates to:
  /// **'Caractères invisibles ou d\'inversion de texte (technique d\'arnaque)'**
  String get reasonHiddenCharacters;

  /// words = liste de mots entre guillemets
  ///
  /// In fr, this message translates to:
  /// **'Mots typiques des arnaques : {words}'**
  String reasonScamWords(String words);

  /// Un mot cité
  ///
  /// In fr, this message translates to:
  /// **'« {word} »'**
  String reasonQuotedWord(String word);

  /// Entre deux éléments d'une liste
  ///
  /// In fr, this message translates to:
  /// **', '**
  String get listSeparator;

  /// No description provided for @reasonLinkImpersonation.
  ///
  /// In fr, this message translates to:
  /// **'« {host} » imite {brand} mais ce n\'est pas son site officiel'**
  String reasonLinkImpersonation(String host, String brand);

  /// No description provided for @reasonLinkIp.
  ///
  /// In fr, this message translates to:
  /// **'Le lien utilise une adresse IP ({host}) au lieu d\'un nom de site'**
  String reasonLinkIp(String host);

  /// No description provided for @reasonLinkPunycode.
  ///
  /// In fr, this message translates to:
  /// **'« {host} » contient des lettres déguisées (punycode) pour ressembler à un vrai site'**
  String reasonLinkPunycode(String host);

  /// No description provided for @reasonLinkAt.
  ///
  /// In fr, this message translates to:
  /// **'Le lien contient « @ » : la vraie destination est « {host} »'**
  String reasonLinkAt(String host);

  /// No description provided for @reasonLinkShortener.
  ///
  /// In fr, this message translates to:
  /// **'Lien raccourci ({host}) : la vraie adresse est cachée'**
  String reasonLinkShortener(String host);

  /// No description provided for @reasonLinkTld.
  ///
  /// In fr, this message translates to:
  /// **'L\'extension « .{tld} » est souvent utilisée par les arnaques'**
  String reasonLinkTld(String tld);

  /// No description provided for @reasonLinkSubdomains.
  ///
  /// In fr, this message translates to:
  /// **'« {host} » a beaucoup de sous-domaines, une technique pour tromper'**
  String reasonLinkSubdomains(String host);

  /// No description provided for @reasonLinkHttp.
  ///
  /// In fr, this message translates to:
  /// **'Le lien n\'est pas sécurisé (http au lieu de https)'**
  String get reasonLinkHttp;

  /// No description provided for @messagesHint.
  ///
  /// In fr, this message translates to:
  /// **'Collez un SMS, un message WhatsApp ou un lien'**
  String get messagesHint;

  /// No description provided for @messagesPaste.
  ///
  /// In fr, this message translates to:
  /// **'Coller'**
  String get messagesPaste;

  /// No description provided for @messagesClear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get messagesClear;

  /// No description provided for @messagesAnalyze.
  ///
  /// In fr, this message translates to:
  /// **'Analyser'**
  String get messagesAnalyze;

  /// No description provided for @messagesFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'analyse a échoué. Réessayez.'**
  String get messagesFailed;

  /// No description provided for @messagesLocalNote.
  ///
  /// In fr, this message translates to:
  /// **'L\'analyse se fait sur votre téléphone. Le message n\'est envoyé nulle part.'**
  String get messagesLocalNote;

  /// No description provided for @messagesProbability.
  ///
  /// In fr, this message translates to:
  /// **'Probabilité d\'arnaque : {percent} %'**
  String messagesProbability(String percent);

  /// No description provided for @alertDefaultReason.
  ///
  /// In fr, this message translates to:
  /// **'Ce message ressemble aux arnaques connues. Ne cliquez sur aucun lien.'**
  String get alertDefaultReason;

  /// No description provided for @alertTitleSms.
  ///
  /// In fr, this message translates to:
  /// **'Arnaque probable dans un SMS'**
  String get alertTitleSms;

  /// No description provided for @alertTitleMessage.
  ///
  /// In fr, this message translates to:
  /// **'Arnaque probable dans un message'**
  String get alertTitleMessage;

  /// app = WhatsApp, Telegram…
  ///
  /// In fr, this message translates to:
  /// **'Arnaque probable sur {app}'**
  String alertTitleApp(String app);

  /// No description provided for @autoProtectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Protection automatique'**
  String get autoProtectionTitle;

  /// No description provided for @autoProtectionOn.
  ///
  /// In fr, this message translates to:
  /// **'Analyse les messages reçus et vous prévient en cas d\'arnaque.'**
  String get autoProtectionOn;

  /// No description provided for @autoProtectionNotificationsBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Notifications de Sentinel bloquées : vous ne serez pas prévenu en cas d\'arnaque.'**
  String get autoProtectionNotificationsBlocked;

  /// No description provided for @autoProtectionAllowNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser les notifications de Sentinel'**
  String get autoProtectionAllowNotifications;

  /// No description provided for @autoProtectionRemoveAccess.
  ///
  /// In fr, this message translates to:
  /// **'Retirer aussi l\'accès dans les réglages Android'**
  String get autoProtectionRemoveAccess;

  /// No description provided for @autoProtectionDoesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce que fait Sentinel'**
  String get autoProtectionDoesTitle;

  /// No description provided for @autoProtectionDoes1.
  ///
  /// In fr, this message translates to:
  /// **'Lit le texte des notifications de vos applications de messagerie.'**
  String get autoProtectionDoes1;

  /// No description provided for @autoProtectionDoes2.
  ///
  /// In fr, this message translates to:
  /// **'L\'analyse sur votre téléphone.'**
  String get autoProtectionDoes2;

  /// No description provided for @autoProtectionDoes3.
  ///
  /// In fr, this message translates to:
  /// **'Vous prévient si c\'est une arnaque.'**
  String get autoProtectionDoes3;

  /// No description provided for @autoProtectionNeverTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce que Sentinel ne fait jamais'**
  String get autoProtectionNeverTitle;

  /// No description provided for @autoProtectionNever1.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer vos messages sur Internet.'**
  String get autoProtectionNever1;

  /// No description provided for @autoProtectionNever2.
  ///
  /// In fr, this message translates to:
  /// **'Les enregistrer.'**
  String get autoProtectionNever2;

  /// No description provided for @autoProtectionNever3.
  ///
  /// In fr, this message translates to:
  /// **'Lire les notifications des autres applications.'**
  String get autoProtectionNever3;

  /// No description provided for @wifiLevelDanger.
  ///
  /// In fr, this message translates to:
  /// **'Danger'**
  String get wifiLevelDanger;

  /// No description provided for @wifiLevelWeak.
  ///
  /// In fr, this message translates to:
  /// **'Faible'**
  String get wifiLevelWeak;

  /// No description provided for @wifiLevelOk.
  ///
  /// In fr, this message translates to:
  /// **'Correct'**
  String get wifiLevelOk;

  /// No description provided for @wifiLevelExcellent.
  ///
  /// In fr, this message translates to:
  /// **'Excellent'**
  String get wifiLevelExcellent;

  /// No description provided for @wifiLevelNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get wifiLevelNone;

  /// No description provided for @wifiLevelUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get wifiLevelUnknown;

  /// No description provided for @wifiSecurityOpen.
  ///
  /// In fr, this message translates to:
  /// **'Aucune (réseau ouvert)'**
  String get wifiSecurityOpen;

  /// No description provided for @wifiSecurityWpa2.
  ///
  /// In fr, this message translates to:
  /// **'WPA2 ou WPA'**
  String get wifiSecurityWpa2;

  /// No description provided for @wifiSecurityEnterprise.
  ///
  /// In fr, this message translates to:
  /// **'Entreprise (WPA2 / WPA3)'**
  String get wifiSecurityEnterprise;

  /// No description provided for @wifiAdviceNoBanking.
  ///
  /// In fr, this message translates to:
  /// **'Évitez la banque et les achats sur ce réseau'**
  String get wifiAdviceNoBanking;

  /// No description provided for @wifiAdviceUseMobile.
  ///
  /// In fr, this message translates to:
  /// **'Utilisez plutôt les données mobiles'**
  String get wifiAdviceUseMobile;

  /// No description provided for @wifiAdviceUpgradeBox.
  ///
  /// In fr, this message translates to:
  /// **'Si c\'est votre box, choisissez WPA2 ou WPA3 dans ses réglages'**
  String get wifiAdviceUpgradeBox;

  /// No description provided for @wifiAdvicePublicUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Sur un Wi-Fi public, évitez la banque et les achats'**
  String get wifiAdvicePublicUnknown;

  /// No description provided for @wifiNoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas de Wi-Fi'**
  String get wifiNoneTitle;

  /// No description provided for @wifiNoneSummary.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'êtes connecté à aucun Wi-Fi.'**
  String get wifiNoneSummary;

  /// No description provided for @wifiNoneExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'êtes connecté à aucun Wi-Fi : rien à vérifier pour le moment.'**
  String get wifiNoneExplanation;

  /// No description provided for @wifiPublicTitle.
  ///
  /// In fr, this message translates to:
  /// **'Wi-Fi public'**
  String get wifiPublicTitle;

  /// No description provided for @wifiPublicSummary.
  ///
  /// In fr, this message translates to:
  /// **'Réseau partagé avec une page de connexion.'**
  String get wifiPublicSummary;

  /// No description provided for @wifiCaptiveExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Ce réseau demande de se connecter sur une page (hôtel, gare, café…). Beaucoup de personnes le partagent.'**
  String get wifiCaptiveExplanation;

  /// No description provided for @wifiCaptiveAdvice.
  ///
  /// In fr, this message translates to:
  /// **'N\'utilisez jamais vos mots de passe habituels sur la page de connexion'**
  String get wifiCaptiveAdvice;

  /// No description provided for @wifiDnsOffExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Le DNS privé est désactivé : le réseau peut voir les noms des sites que vous visitez.'**
  String get wifiDnsOffExplanation;

  /// No description provided for @wifiDnsOffAdvice.
  ///
  /// In fr, this message translates to:
  /// **'Activez le DNS privé (mode automatique) dans les réglages'**
  String get wifiDnsOffAdvice;

  /// No description provided for @wifiOpenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Wi-Fi ouvert'**
  String get wifiOpenTitle;

  /// No description provided for @wifiOpenSummary.
  ///
  /// In fr, this message translates to:
  /// **'Ce Wi-Fi n\'est pas protégé.'**
  String get wifiOpenSummary;

  /// No description provided for @wifiOpenExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Ce Wi-Fi n\'est pas protégé. Les personnes connectées au même réseau peuvent voir ce que vous envoyez.'**
  String get wifiOpenExplanation;

  /// No description provided for @wifiWepTitle.
  ///
  /// In fr, this message translates to:
  /// **'Protection WEP dépassée'**
  String get wifiWepTitle;

  /// No description provided for @wifiWepSummary.
  ///
  /// In fr, this message translates to:
  /// **'Sa protection se casse en quelques minutes.'**
  String get wifiWepSummary;

  /// No description provided for @wifiWepExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Ce Wi-Fi utilise WEP, une protection de 1999 qui se casse en quelques minutes. C\'est presque comme un réseau ouvert.'**
  String get wifiWepExplanation;

  /// No description provided for @wifiWpaTitle.
  ///
  /// In fr, this message translates to:
  /// **'Protection WPA ancienne'**
  String get wifiWpaTitle;

  /// No description provided for @wifiWpaSummary.
  ///
  /// In fr, this message translates to:
  /// **'Protection ancienne et fragile.'**
  String get wifiWpaSummary;

  /// No description provided for @wifiWpaExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Ce Wi-Fi utilise WPA, une protection ancienne qui a des failles connues.'**
  String get wifiWpaExplanation;

  /// No description provided for @wifiOweTitle.
  ///
  /// In fr, this message translates to:
  /// **'Wi-Fi public chiffré'**
  String get wifiOweTitle;

  /// No description provided for @wifiOweSummary.
  ///
  /// In fr, this message translates to:
  /// **'Chiffré, mais ouvert à tous.'**
  String get wifiOweSummary;

  /// No description provided for @wifiOweExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Ce Wi-Fi public chiffre vos échanges (Enhanced Open) : les autres ne peuvent pas les lire. Mais tout le monde peut s\'y connecter, et un faux réseau peut imiter le vrai.'**
  String get wifiOweExplanation;

  /// No description provided for @wifiWpa2Title.
  ///
  /// In fr, this message translates to:
  /// **'Wi-Fi protégé (WPA2)'**
  String get wifiWpa2Title;

  /// No description provided for @wifiWpa2Summary.
  ///
  /// In fr, this message translates to:
  /// **'Protégé par un mot de passe.'**
  String get wifiWpa2Summary;

  /// No description provided for @wifiWpa2Explanation.
  ///
  /// In fr, this message translates to:
  /// **'Ce Wi-Fi est protégé par un mot de passe (WPA2). Les personnes qui ne le connaissent pas ne peuvent pas lire ce que vous envoyez.'**
  String get wifiWpa2Explanation;

  /// No description provided for @wifiWpa3Title.
  ///
  /// In fr, this message translates to:
  /// **'Wi-Fi très protégé (WPA3)'**
  String get wifiWpa3Title;

  /// No description provided for @wifiWpa3Summary.
  ///
  /// In fr, this message translates to:
  /// **'La meilleure protection Wi-Fi actuelle.'**
  String get wifiWpa3Summary;

  /// No description provided for @wifiWpa3Explanation.
  ///
  /// In fr, this message translates to:
  /// **'Ce Wi-Fi utilise WPA3, la protection la plus récente. Même quelqu\'un qui connaît le mot de passe ne peut pas lire vos échanges.'**
  String get wifiWpa3Explanation;

  /// No description provided for @wifiEnterpriseTitle.
  ///
  /// In fr, this message translates to:
  /// **'Wi-Fi d\'entreprise'**
  String get wifiEnterpriseTitle;

  /// No description provided for @wifiEnterpriseSummary.
  ///
  /// In fr, this message translates to:
  /// **'Chacun se connecte avec son propre identifiant.'**
  String get wifiEnterpriseSummary;

  /// No description provided for @wifiEnterpriseExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Ce Wi-Fi d\'entreprise (WPA2 / WPA3-Entreprise) donne à chaque personne son propre identifiant et sa propre clé.'**
  String get wifiEnterpriseExplanation;

  /// No description provided for @wifiUnknownTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité inconnue'**
  String get wifiUnknownTitle;

  /// No description provided for @wifiUnknownSummary.
  ///
  /// In fr, this message translates to:
  /// **'Le type de protection n\'est pas disponible.'**
  String get wifiUnknownSummary;

  /// No description provided for @wifiUnknownOldAndroid.
  ///
  /// In fr, this message translates to:
  /// **'Sur Android 11 et avant, connaître la protection d\'un Wi-Fi demande l\'autorisation de localisation, que Sentinel ne demande pas.'**
  String get wifiUnknownOldAndroid;

  /// No description provided for @wifiUnknownExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Android n\'a pas indiqué le type de protection de ce Wi-Fi.'**
  String get wifiUnknownExplanation;

  /// No description provided for @wifiSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réseau Wi-Fi'**
  String get wifiSectionTitle;

  /// No description provided for @wifiUnavailableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Information indisponible'**
  String get wifiUnavailableTitle;

  /// No description provided for @wifiUnavailableSummary.
  ///
  /// In fr, this message translates to:
  /// **'Android n\'a pas pu lire l\'état du Wi-Fi.'**
  String get wifiUnavailableSummary;

  /// No description provided for @wifiDetailProtection.
  ///
  /// In fr, this message translates to:
  /// **'Protection'**
  String get wifiDetailProtection;

  /// No description provided for @wifiDetailCaptive.
  ///
  /// In fr, this message translates to:
  /// **'Page de connexion'**
  String get wifiDetailCaptive;

  /// No description provided for @wifiDetailPrivateDns.
  ///
  /// In fr, this message translates to:
  /// **'DNS privé'**
  String get wifiDetailPrivateDns;

  /// No description provided for @wifiOurAdvice.
  ///
  /// In fr, this message translates to:
  /// **'Nos conseils'**
  String get wifiOurAdvice;

  /// No description provided for @wifiEnablePrivateDns.
  ///
  /// In fr, this message translates to:
  /// **'Activer le DNS privé'**
  String get wifiEnablePrivateDns;

  /// No description provided for @wifiPrivateDnsHelp.
  ///
  /// In fr, this message translates to:
  /// **'Ouvre « Réseau et Internet ». Le DNS privé se trouve parfois sous « Avancé » ou « Plus de paramètres de connexion ».'**
  String get wifiPrivateDnsHelp;

  /// No description provided for @riskLevelSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get riskLevelSystem;

  /// No description provided for @riskLevelLow.
  ///
  /// In fr, this message translates to:
  /// **'Faible'**
  String get riskLevelLow;

  /// No description provided for @riskLevelModerate.
  ///
  /// In fr, this message translates to:
  /// **'Modéré'**
  String get riskLevelModerate;

  /// No description provided for @riskLevelHigh.
  ///
  /// In fr, this message translates to:
  /// **'Élevé'**
  String get riskLevelHigh;

  /// No description provided for @riskStalkerware.
  ///
  /// In fr, this message translates to:
  /// **'Logiciel espion connu (stalkerware)'**
  String get riskStalkerware;

  /// No description provided for @riskModifiedCopy.
  ///
  /// In fr, this message translates to:
  /// **'Copie modifiée de {brand} (signature différente de l\'éditeur officiel)'**
  String riskModifiedCopy(String brand);

  /// No description provided for @riskImpersonation.
  ///
  /// In fr, this message translates to:
  /// **'Se fait passer pour {brand}, mais ce n\'est pas l\'application officielle'**
  String riskImpersonation(String brand);

  /// No description provided for @riskKnownMod.
  ///
  /// In fr, this message translates to:
  /// **'Version modifiée non officielle de {brand} : elle peut lire vos messages'**
  String riskKnownMod(String brand);

  /// No description provided for @riskSpyProfile.
  ///
  /// In fr, this message translates to:
  /// **'Icône cachée et accès typiques d\'un logiciel espion'**
  String get riskSpyProfile;

  /// No description provided for @riskBankingCombo.
  ///
  /// In fr, this message translates to:
  /// **'Combinaison typique des applications qui volent les comptes bancaires'**
  String get riskBankingCombo;

  /// No description provided for @riskAccessibility.
  ///
  /// In fr, this message translates to:
  /// **'Peut lire tout ce qui s\'affiche à l\'écran et agir à votre place'**
  String get riskAccessibility;

  /// No description provided for @riskUnknownSource.
  ///
  /// In fr, this message translates to:
  /// **'Installée en dehors du Play Store'**
  String get riskUnknownSource;

  /// No description provided for @riskDeviceAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Est administrateur de l\'appareil et peut compliquer sa désinstallation'**
  String get riskDeviceAdmin;

  /// No description provided for @riskDebugCert.
  ///
  /// In fr, this message translates to:
  /// **'Signée avec un certificat de test'**
  String get riskDebugCert;

  /// No description provided for @riskSms.
  ///
  /// In fr, this message translates to:
  /// **'Peut lire vos SMS, y compris les codes de vérification bancaires'**
  String get riskSms;

  /// No description provided for @riskNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Peut lire toutes vos notifications, y compris vos messages'**
  String get riskNotifications;

  /// No description provided for @riskMicrophone.
  ///
  /// In fr, this message translates to:
  /// **'Peut utiliser le micro'**
  String get riskMicrophone;

  /// No description provided for @riskCallLog.
  ///
  /// In fr, this message translates to:
  /// **'Peut consulter l\'historique de vos appels'**
  String get riskCallLog;

  /// No description provided for @riskOverlay.
  ///
  /// In fr, this message translates to:
  /// **'Peut s\'afficher par-dessus les autres applications'**
  String get riskOverlay;

  /// No description provided for @riskBackgroundLocation.
  ///
  /// In fr, this message translates to:
  /// **'Peut connaître votre position même quand vous ne l\'utilisez pas'**
  String get riskBackgroundLocation;

  /// No description provided for @riskOldTarget.
  ///
  /// In fr, this message translates to:
  /// **'Conçue pour une ancienne version d\'Android, avec moins de protections'**
  String get riskOldTarget;

  /// No description provided for @riskOtherStore.
  ///
  /// In fr, this message translates to:
  /// **'Installée depuis une boutique autre que le Play Store (contrôles différents)'**
  String get riskOtherStore;

  /// No description provided for @riskContacts.
  ///
  /// In fr, this message translates to:
  /// **'Peut lire vos contacts'**
  String get riskContacts;

  /// No description provided for @riskCamera.
  ///
  /// In fr, this message translates to:
  /// **'Peut utiliser l\'appareil photo'**
  String get riskCamera;

  /// count = nombre d'apps, n = le même nombre déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{n} application analysée} other{{n} applications analysées}}'**
  String appsAnalyzed(int count, String n);

  /// No description provided for @appsSummaryNoneToReview.
  ///
  /// In fr, this message translates to:
  /// **'{analyzed}, aucune à vérifier.'**
  String appsSummaryNoneToReview(String analyzed);

  /// No description provided for @appsSummaryToReview.
  ///
  /// In fr, this message translates to:
  /// **'{analyzed}, dont {count} à vérifier.'**
  String appsSummaryToReview(String analyzed, String count);

  /// No description provided for @appsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Analysez vos applications'**
  String get appsEmptyTitle;

  /// No description provided for @appsEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Sentinel vérifie les permissions de chaque application installée et signale celles qui en demandent trop.'**
  String get appsEmptyMessage;

  /// No description provided for @appsStartScan.
  ///
  /// In fr, this message translates to:
  /// **'Lancer l\'analyse'**
  String get appsStartScan;

  /// No description provided for @appsAndroidOnly.
  ///
  /// In fr, this message translates to:
  /// **'L\'analyse des applications est disponible sur Android.'**
  String get appsAndroidOnly;

  /// No description provided for @appsShowSystem.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les applications système'**
  String get appsShowSystem;

  /// No description provided for @appsSpywareFound.
  ///
  /// In fr, this message translates to:
  /// **'Un logiciel espion possible a été trouvé'**
  String get appsSpywareFound;

  /// No description provided for @appsSpywareReadAdvice.
  ///
  /// In fr, this message translates to:
  /// **'Lisez les conseils avant de le supprimer.'**
  String get appsSpywareReadAdvice;

  /// No description provided for @appsSeeAdvice.
  ///
  /// In fr, this message translates to:
  /// **'Voir les conseils'**
  String get appsSeeAdvice;

  /// No description provided for @appsScanning.
  ///
  /// In fr, this message translates to:
  /// **'Analyse de vos applications…'**
  String get appsScanning;

  /// No description provided for @appsSystemApp.
  ///
  /// In fr, this message translates to:
  /// **'Application du système Android'**
  String get appsSystemApp;

  /// No description provided for @appsNoWorry.
  ///
  /// In fr, this message translates to:
  /// **'Aucun signal inquiétant'**
  String get appsNoWorry;

  /// No description provided for @detailPreinstalled.
  ///
  /// In fr, this message translates to:
  /// **'Préinstallée'**
  String get detailPreinstalled;

  /// No description provided for @detailUnknownSource.
  ///
  /// In fr, this message translates to:
  /// **'Source inconnue'**
  String get detailUnknownSource;

  /// No description provided for @detailKnownSpyware.
  ///
  /// In fr, this message translates to:
  /// **'Logiciel espion connu : {name}'**
  String detailKnownSpyware(String name);

  /// No description provided for @detailSignatureVerified.
  ///
  /// In fr, this message translates to:
  /// **'Signature vérifiée pour {brand}'**
  String detailSignatureVerified(String brand);

  /// No description provided for @detailSignatureDifferent.
  ///
  /// In fr, this message translates to:
  /// **'Signature différente de l\'éditeur officiel de {brand}'**
  String detailSignatureDifferent(String brand);

  /// No description provided for @detailNotOfficial.
  ///
  /// In fr, this message translates to:
  /// **'Ce n\'est pas l\'application officielle de {brand}'**
  String detailNotOfficial(String brand);

  /// No description provided for @detailKnownMod.
  ///
  /// In fr, this message translates to:
  /// **'Version modifiée non officielle de {brand}'**
  String detailKnownMod(String brand);

  /// No description provided for @detailUnchecked.
  ///
  /// In fr, this message translates to:
  /// **'Empreinte officielle de {brand} pas encore enregistrée dans Sentinel'**
  String detailUnchecked(String brand);

  /// No description provided for @detailSignatureUnreadable.
  ///
  /// In fr, this message translates to:
  /// **'Signature illisible'**
  String get detailSignatureUnreadable;

  /// No description provided for @detailSha256.
  ///
  /// In fr, this message translates to:
  /// **'Empreinte SHA-256'**
  String get detailSha256;

  /// No description provided for @detailCertificate.
  ///
  /// In fr, this message translates to:
  /// **'Certificat'**
  String get detailCertificate;

  /// No description provided for @detailPublisherMissing.
  ///
  /// In fr, this message translates to:
  /// **'Éditeur non renseigné'**
  String get detailPublisherMissing;

  /// No description provided for @detailOtherCertificates.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Et 1 autre certificat (ancien ou multiple)} other{Et {n} autres certificats (anciens ou multiples)}}'**
  String detailOtherCertificates(int count, String n);

  /// No description provided for @detailWhatToDo.
  ///
  /// In fr, this message translates to:
  /// **'Que faire ?'**
  String get detailWhatToDo;

  /// No description provided for @detailManagePermissions.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les autorisations'**
  String get detailManagePermissions;

  /// No description provided for @detailUninstall.
  ///
  /// In fr, this message translates to:
  /// **'Désinstaller'**
  String get detailUninstall;

  /// No description provided for @detailRiskLevel.
  ///
  /// In fr, this message translates to:
  /// **'Niveau de risque'**
  String get detailRiskLevel;

  /// No description provided for @detailSource.
  ///
  /// In fr, this message translates to:
  /// **'Source'**
  String get detailSource;

  /// No description provided for @detailInstalledOn.
  ///
  /// In fr, this message translates to:
  /// **'Installée le'**
  String get detailInstalledOn;

  /// No description provided for @detailUpdatedOn.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour le'**
  String get detailUpdatedOn;

  /// No description provided for @detailWhyLevel.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi ce niveau'**
  String get detailWhyLevel;

  /// No description provided for @detailSystemExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Cette application fait partie d\'Android ou de votre fabricant. Ses autorisations étendues sont normales pour son fonctionnement.'**
  String get detailSystemExplanation;

  /// No description provided for @detailSignature.
  ///
  /// In fr, this message translates to:
  /// **'Signature'**
  String get detailSignature;

  /// No description provided for @detailGrantedPermissions.
  ///
  /// In fr, this message translates to:
  /// **'Autorisations accordées'**
  String get detailGrantedPermissions;

  /// No description provided for @detailNoPermissions.
  ///
  /// In fr, this message translates to:
  /// **'Aucune autorisation accordée'**
  String get detailNoPermissions;

  /// No description provided for @detailOtherPermissions.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Et 1 autre autorisation technique} other{Et {n} autres autorisations techniques}}'**
  String detailOtherPermissions(int count, String n);

  /// No description provided for @spywareTitle.
  ///
  /// In fr, this message translates to:
  /// **'Avant de toucher à cette application'**
  String get spywareTitle;

  /// No description provided for @spywareParagraph1.
  ///
  /// In fr, this message translates to:
  /// **'Si vous pensez que quelqu\'un de votre entourage a installé cette application, sa suppression peut le prévenir. Si vous êtes en danger, contactez d\'abord une association d\'aide ou la police.'**
  String get spywareParagraph1;

  /// No description provided for @spywareParagraph2.
  ///
  /// In fr, this message translates to:
  /// **'Avant d\'agir, vous pouvez noter le nom de l\'application et faire une capture d\'écran : cela peut servir de preuve.'**
  String get spywareParagraph2;

  /// No description provided for @spywareParagraph3.
  ///
  /// In fr, this message translates to:
  /// **'Sentinel ne prévient personne et n\'envoie aucune notification à ce sujet.'**
  String get spywareParagraph3;

  /// No description provided for @spywareGetHelp.
  ///
  /// In fr, this message translates to:
  /// **'Se faire aider'**
  String get spywareGetHelp;

  /// No description provided for @spywareCoalition.
  ///
  /// In fr, this message translates to:
  /// **'Coalition Against Stalkerware : des conseils pour les personnes surveillées et des contacts d\'associations.'**
  String get spywareCoalition;

  /// No description provided for @spywareBrowserNote.
  ///
  /// In fr, this message translates to:
  /// **'Le site s\'ouvre dans votre navigateur et restera dans son historique. Vous pouvez aussi copier l\'adresse et l\'ouvrir en navigation privée, ou depuis un autre appareil.'**
  String get spywareBrowserNote;

  /// No description provided for @spywareOpenSite.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le site'**
  String get spywareOpenSite;

  /// No description provided for @spywareCopyAddress.
  ///
  /// In fr, this message translates to:
  /// **'Copier l\'adresse'**
  String get spywareCopyAddress;

  /// No description provided for @spywareAddressCopied.
  ///
  /// In fr, this message translates to:
  /// **'Adresse copiée'**
  String get spywareAddressCopied;

  /// Mention exigée par la licence CC BY 4.0
  ///
  /// In fr, this message translates to:
  /// **'Liste de logiciels espions : projet Stalkerware Indicators (Echap), licence CC BY 4.0.'**
  String get spywareIocCredit;

  /// Permission android.permission.READ_SMS
  ///
  /// In fr, this message translates to:
  /// **'Lire vos SMS'**
  String get permReadSms;

  /// Permission android.permission.RECEIVE_SMS
  ///
  /// In fr, this message translates to:
  /// **'Recevoir vos SMS'**
  String get permReceiveSms;

  /// Permission android.permission.SEND_SMS
  ///
  /// In fr, this message translates to:
  /// **'Envoyer des SMS (parfois payants)'**
  String get permSendSms;

  /// Permission android.permission.RECEIVE_MMS
  ///
  /// In fr, this message translates to:
  /// **'Recevoir des MMS'**
  String get permReceiveMms;

  /// Permission android.permission.READ_CALL_LOG
  ///
  /// In fr, this message translates to:
  /// **'Consulter l\'historique des appels'**
  String get permReadCallLog;

  /// Permission android.permission.WRITE_CALL_LOG
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'historique des appels'**
  String get permWriteCallLog;

  /// Permission android.permission.CALL_PHONE
  ///
  /// In fr, this message translates to:
  /// **'Passer des appels'**
  String get permCallPhone;

  /// Permission android.permission.ANSWER_PHONE_CALLS
  ///
  /// In fr, this message translates to:
  /// **'Répondre aux appels'**
  String get permAnswerPhoneCalls;

  /// Permission android.permission.READ_PHONE_STATE
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'état du téléphone et des appels'**
  String get permReadPhoneState;

  /// Permission android.permission.READ_PHONE_NUMBERS
  ///
  /// In fr, this message translates to:
  /// **'Connaître votre numéro de téléphone'**
  String get permReadPhoneNumbers;

  /// Permission android.permission.READ_CONTACTS
  ///
  /// In fr, this message translates to:
  /// **'Lire vos contacts'**
  String get permReadContacts;

  /// Permission android.permission.WRITE_CONTACTS
  ///
  /// In fr, this message translates to:
  /// **'Modifier vos contacts'**
  String get permWriteContacts;

  /// Permission android.permission.GET_ACCOUNTS
  ///
  /// In fr, this message translates to:
  /// **'Voir les comptes enregistrés sur le téléphone'**
  String get permGetAccounts;

  /// Permission android.permission.READ_CALENDAR
  ///
  /// In fr, this message translates to:
  /// **'Lire votre agenda'**
  String get permReadCalendar;

  /// Permission android.permission.WRITE_CALENDAR
  ///
  /// In fr, this message translates to:
  /// **'Modifier votre agenda'**
  String get permWriteCalendar;

  /// Permission android.permission.RECORD_AUDIO
  ///
  /// In fr, this message translates to:
  /// **'Utiliser le micro'**
  String get permRecordAudio;

  /// Permission android.permission.CAMERA
  ///
  /// In fr, this message translates to:
  /// **'Utiliser l\'appareil photo'**
  String get permCamera;

  /// Permission android.permission.BODY_SENSORS
  ///
  /// In fr, this message translates to:
  /// **'Lire les capteurs corporels (rythme cardiaque…)'**
  String get permBodySensors;

  /// Permission android.permission.BODY_SENSORS_BACKGROUND
  ///
  /// In fr, this message translates to:
  /// **'Lire les capteurs corporels en arrière-plan'**
  String get permBodySensorsBackground;

  /// Permission android.permission.ACTIVITY_RECOGNITION
  ///
  /// In fr, this message translates to:
  /// **'Détecter votre activité physique'**
  String get permActivityRecognition;

  /// Permission android.permission.ACCESS_FINE_LOCATION
  ///
  /// In fr, this message translates to:
  /// **'Connaître votre position précise'**
  String get permAccessFineLocation;

  /// Permission android.permission.ACCESS_COARSE_LOCATION
  ///
  /// In fr, this message translates to:
  /// **'Connaître votre position approximative'**
  String get permAccessCoarseLocation;

  /// Permission android.permission.ACCESS_BACKGROUND_LOCATION
  ///
  /// In fr, this message translates to:
  /// **'Connaître votre position même quand l\'app est fermée'**
  String get permAccessBackgroundLocation;

  /// Permission android.permission.ACCESS_MEDIA_LOCATION
  ///
  /// In fr, this message translates to:
  /// **'Lire le lieu de prise de vos photos'**
  String get permAccessMediaLocation;

  /// Permission android.permission.READ_EXTERNAL_STORAGE
  ///
  /// In fr, this message translates to:
  /// **'Lire vos fichiers'**
  String get permReadExternalStorage;

  /// Permission android.permission.WRITE_EXTERNAL_STORAGE
  ///
  /// In fr, this message translates to:
  /// **'Modifier vos fichiers'**
  String get permWriteExternalStorage;

  /// Permission android.permission.MANAGE_EXTERNAL_STORAGE
  ///
  /// In fr, this message translates to:
  /// **'Accéder à tous vos fichiers'**
  String get permManageExternalStorage;

  /// Permission android.permission.READ_MEDIA_IMAGES
  ///
  /// In fr, this message translates to:
  /// **'Voir vos photos'**
  String get permReadMediaImages;

  /// Permission android.permission.READ_MEDIA_VIDEO
  ///
  /// In fr, this message translates to:
  /// **'Voir vos vidéos'**
  String get permReadMediaVideo;

  /// Permission android.permission.READ_MEDIA_AUDIO
  ///
  /// In fr, this message translates to:
  /// **'Accéder à vos fichiers audio'**
  String get permReadMediaAudio;

  /// Permission android.permission.READ_MEDIA_VISUAL_USER_SELECTED
  ///
  /// In fr, this message translates to:
  /// **'Voir les photos que vous choisissez'**
  String get permReadMediaVisualUserSelected;

  /// Permission android.permission.BLUETOOTH
  ///
  /// In fr, this message translates to:
  /// **'Utiliser le Bluetooth'**
  String get permBluetooth;

  /// Permission android.permission.BLUETOOTH_CONNECT
  ///
  /// In fr, this message translates to:
  /// **'Se connecter aux appareils Bluetooth'**
  String get permBluetoothConnect;

  /// Permission android.permission.BLUETOOTH_SCAN
  ///
  /// In fr, this message translates to:
  /// **'Rechercher des appareils Bluetooth'**
  String get permBluetoothScan;

  /// Permission android.permission.NEARBY_WIFI_DEVICES
  ///
  /// In fr, this message translates to:
  /// **'Trouver les appareils Wi-Fi à proximité'**
  String get permNearbyWifiDevices;

  /// Permission android.permission.NFC
  ///
  /// In fr, this message translates to:
  /// **'Utiliser le NFC (paiement sans contact…)'**
  String get permNfc;

  /// Permission android.permission.INTERNET
  ///
  /// In fr, this message translates to:
  /// **'Accéder à internet'**
  String get permInternet;

  /// Permission android.permission.ACCESS_NETWORK_STATE
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'état de la connexion'**
  String get permAccessNetworkState;

  /// Permission android.permission.ACCESS_WIFI_STATE
  ///
  /// In fr, this message translates to:
  /// **'Voir les réseaux Wi-Fi'**
  String get permAccessWifiState;

  /// Permission android.permission.CHANGE_WIFI_STATE
  ///
  /// In fr, this message translates to:
  /// **'Activer ou couper le Wi-Fi'**
  String get permChangeWifiState;

  /// Permission android.permission.SYSTEM_ALERT_WINDOW
  ///
  /// In fr, this message translates to:
  /// **'S\'afficher par-dessus les autres applications'**
  String get permSystemAlertWindow;

  /// Permission android.permission.POST_NOTIFICATIONS
  ///
  /// In fr, this message translates to:
  /// **'Afficher des notifications'**
  String get permPostNotifications;

  /// Permission android.permission.REQUEST_INSTALL_PACKAGES
  ///
  /// In fr, this message translates to:
  /// **'Proposer d\'installer d\'autres applications'**
  String get permRequestInstallPackages;

  /// Permission android.permission.REQUEST_DELETE_PACKAGES
  ///
  /// In fr, this message translates to:
  /// **'Proposer de désinstaller des applications'**
  String get permRequestDeletePackages;

  /// Permission android.permission.QUERY_ALL_PACKAGES
  ///
  /// In fr, this message translates to:
  /// **'Voir la liste de vos applications'**
  String get permQueryAllPackages;

  /// Permission android.permission.PACKAGE_USAGE_STATS
  ///
  /// In fr, this message translates to:
  /// **'Voir quelles applications vous utilisez'**
  String get permPackageUsageStats;

  /// Permission android.permission.RECEIVE_BOOT_COMPLETED
  ///
  /// In fr, this message translates to:
  /// **'Se lancer au démarrage du téléphone'**
  String get permReceiveBootCompleted;

  /// Permission android.permission.FOREGROUND_SERVICE
  ///
  /// In fr, this message translates to:
  /// **'Fonctionner en continu en arrière-plan'**
  String get permForegroundService;

  /// Permission android.permission.WAKE_LOCK
  ///
  /// In fr, this message translates to:
  /// **'Empêcher la mise en veille'**
  String get permWakeLock;

  /// Permission android.permission.VIBRATE
  ///
  /// In fr, this message translates to:
  /// **'Faire vibrer le téléphone'**
  String get permVibrate;

  /// Permission android.permission.USE_BIOMETRIC
  ///
  /// In fr, this message translates to:
  /// **'Utiliser l\'empreinte ou le visage'**
  String get permUseBiometric;

  /// Permission android.permission.USE_FINGERPRINT
  ///
  /// In fr, this message translates to:
  /// **'Utiliser l\'empreinte digitale'**
  String get permUseFingerprint;

  /// Permission android.permission.SCHEDULE_EXACT_ALARM
  ///
  /// In fr, this message translates to:
  /// **'Programmer des alarmes précises'**
  String get permScheduleExactAlarm;

  /// Permission android.permission.USE_FULL_SCREEN_INTENT
  ///
  /// In fr, this message translates to:
  /// **'Afficher des alertes en plein écran'**
  String get permUseFullScreenIntent;

  /// No description provided for @firewallTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pare-feu DNS'**
  String get firewallTitle;

  /// n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Activé · {n} requête bloquée} other{Activé · {n} requêtes bloquées}}'**
  String firewallOnBlocked(int count, String n);

  /// No description provided for @categoryMalware.
  ///
  /// In fr, this message translates to:
  /// **'Malware et hameçonnage'**
  String get categoryMalware;

  /// No description provided for @categoryImpersonation.
  ///
  /// In fr, this message translates to:
  /// **'Imitations de marques'**
  String get categoryImpersonation;

  /// No description provided for @categoryTrackers.
  ///
  /// In fr, this message translates to:
  /// **'Traqueurs'**
  String get categoryTrackers;

  /// No description provided for @categoryAds.
  ///
  /// In fr, this message translates to:
  /// **'Publicités'**
  String get categoryAds;

  /// No description provided for @categoryOther.
  ///
  /// In fr, this message translates to:
  /// **'Autres domaines'**
  String get categoryOther;

  /// n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{n} marque surveillée · sites qui les imitent} other{{n} marques surveillées · sites qui les imitent}}'**
  String categoryBrandsWatched(int count, String n);

  /// n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{n} domaine} other{{n} domaines}}'**
  String domainsCount(int count, String n);

  /// No description provided for @firewallListsBundled.
  ///
  /// In fr, this message translates to:
  /// **'Listes livrées avec l\'application'**
  String get firewallListsBundled;

  /// No description provided for @firewallLastUpdate.
  ///
  /// In fr, this message translates to:
  /// **'Dernière mise à jour : {date}'**
  String firewallLastUpdate(String date);

  /// No description provided for @firewallLastAttemptFailed.
  ///
  /// In fr, this message translates to:
  /// **'dernière tentative échouée'**
  String get firewallLastAttemptFailed;

  /// No description provided for @analysisErrorFirewallOff.
  ///
  /// In fr, this message translates to:
  /// **'Activez d\'abord le pare-feu DNS.'**
  String get analysisErrorFirewallOff;

  /// No description provided for @analysisErrorRunning.
  ///
  /// In fr, this message translates to:
  /// **'Une analyse est déjà en cours.'**
  String get analysisErrorRunning;

  /// No description provided for @analysisErrorUnknownApp.
  ///
  /// In fr, this message translates to:
  /// **'Cette application n\'est plus installée.'**
  String get analysisErrorUnknownApp;

  /// No description provided for @analysisErrorFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lancer l\'analyse.'**
  String get analysisErrorFailed;

  /// Durée courte, ex : 5 min. n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, other{{n} min}}'**
  String durationMinutes(int count, String n);

  /// Durée dans une phrase. n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{n} minute} other{{n} minutes}}'**
  String durationMinutesLong(int count, String n);

  /// Secondes
  ///
  /// In fr, this message translates to:
  /// **'{n} s'**
  String durationSeconds(String n);

  /// Ex : 1 min 40 s
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min {seconds} s'**
  String durationMinutesSeconds(String minutes, String seconds);

  /// No description provided for @durationMinutesOnly.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min'**
  String durationMinutesOnly(String minutes);

  /// No description provided for @durationLessThanSecond.
  ///
  /// In fr, this message translates to:
  /// **'moins d\'1 s'**
  String get durationLessThanSecond;

  /// No description provided for @reportStoppedEarly.
  ///
  /// In fr, this message translates to:
  /// **'{duration} (arrêtée avant les {planned} prévues)'**
  String reportStoppedEarly(String duration, String planned);

  /// No description provided for @reportNoDomain.
  ///
  /// In fr, this message translates to:
  /// **'{app} n\'a contacté aucun domaine pendant l\'analyse.'**
  String reportNoDomain(String app);

  /// No description provided for @reportContacted.
  ///
  /// In fr, this message translates to:
  /// **'{app} a contacté {domains}'**
  String reportContacted(String app, String domains);

  /// No description provided for @reportNothingKnown.
  ///
  /// In fr, this message translates to:
  /// **'{start}, aucun connu comme traqueur, publicité ou site dangereux.'**
  String reportNothingKnown(String start);

  /// No description provided for @reportIncluding.
  ///
  /// In fr, this message translates to:
  /// **'{start}, dont {parts}.'**
  String reportIncluding(String start, String parts);

  /// n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{n} site dangereux} other{{n} sites dangereux}}'**
  String reportDangerousCount(int count, String n);

  /// n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{n} traqueur} other{{n} traqueurs}}'**
  String reportTrackersCount(int count, String n);

  /// n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{n} publicité} other{{n} publicités}}'**
  String reportAdsCount(int count, String n);

  /// Avant le dernier élément : « a, b et c »
  ///
  /// In fr, this message translates to:
  /// **' et '**
  String get listLastSeparator;

  /// No description provided for @analysisLessThanMinuteLeft.
  ///
  /// In fr, this message translates to:
  /// **'Reste moins d\'1 min'**
  String get analysisLessThanMinuteLeft;

  /// n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, other{Reste {n} min}}'**
  String analysisMinutesLeft(int count, String n);

  /// n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{n} domaine vu} other{{n} domaines vus}}'**
  String analysisDomainsSeen(int count, String n);

  /// No description provided for @analysisSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Analyser une application'**
  String get analysisSectionTitle;

  /// No description provided for @analysisRunning.
  ///
  /// In fr, this message translates to:
  /// **'Analyse de {app} en cours'**
  String analysisRunning(String app);

  /// No description provided for @analysisUnprotectedWarning.
  ///
  /// In fr, this message translates to:
  /// **'Les autres applications ne sont pas protégées par le pare-feu jusqu\'à la fin de l\'analyse.'**
  String get analysisUnprotectedWarning;

  /// No description provided for @analysisStop.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter l\'analyse'**
  String get analysisStop;

  /// No description provided for @analysisIntroActive.
  ///
  /// In fr, this message translates to:
  /// **'Découvrez quels sites une application contacte pendant quelques minutes : traqueurs, publicités, sites dangereux.'**
  String get analysisIntroActive;

  /// No description provided for @analysisIntroInactive.
  ///
  /// In fr, this message translates to:
  /// **'Activez le pare-feu pour analyser une application.'**
  String get analysisIntroInactive;

  /// No description provided for @analysisChooseApp.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une application'**
  String get analysisChooseApp;

  /// No description provided for @analysisRecentReports.
  ///
  /// In fr, this message translates to:
  /// **'Rapports des dernières 24 heures'**
  String get analysisRecentReports;

  /// No description provided for @analysisScreenIntro.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez l\'application à observer. Pendant quelques minutes, Sentinel note les sites (domaines) qu\'elle contacte.'**
  String get analysisScreenIntro;

  /// No description provided for @analysisListFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lister les applications.'**
  String get analysisListFailed;

  /// No description provided for @analysisNoApps.
  ///
  /// In fr, this message translates to:
  /// **'Aucune application à analyser.'**
  String get analysisNoApps;

  /// No description provided for @analysisSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Analyser {app}'**
  String analysisSheetTitle(String app);

  /// No description provided for @analysisSheetLine1.
  ///
  /// In fr, this message translates to:
  /// **'Pendant {duration}, seules les demandes de {app} passent par le pare-feu : chaque domaine vu lui appartient.'**
  String analysisSheetLine1(String duration, String app);

  /// No description provided for @analysisSheetLine2.
  ///
  /// In fr, this message translates to:
  /// **'Les autres applications ne sont PAS protégées pendant ce temps : ni blocage, ni alerte. Évitez d\'ouvrir des liens inconnus.'**
  String get analysisSheetLine2;

  /// No description provided for @analysisSheetLine3.
  ///
  /// In fr, this message translates to:
  /// **'À la fin, le pare-feu normal revient tout seul. Vous pouvez arrêter avant, depuis Sentinel ou la notification.'**
  String get analysisSheetLine3;

  /// No description provided for @analysisSheetLine4.
  ///
  /// In fr, this message translates to:
  /// **'Le rapport reste sur ce téléphone 24 heures au plus, puis il est supprimé. Il n\'est jamais envoyé.'**
  String get analysisSheetLine4;

  /// No description provided for @analysisSheetLine5.
  ///
  /// In fr, this message translates to:
  /// **'{app} va s\'ouvrir : utilisez-la normalement.'**
  String analysisSheetLine5(String app);

  /// No description provided for @reportDateLine.
  ///
  /// In fr, this message translates to:
  /// **'Analyse du {date} · {duration}'**
  String reportDateLine(String date, String duration);

  /// No description provided for @reportDomainsContacted.
  ///
  /// In fr, this message translates to:
  /// **'Domaines contactés'**
  String get reportDomainsContacted;

  /// No description provided for @reportDangerousSites.
  ///
  /// In fr, this message translates to:
  /// **'Sites dangereux'**
  String get reportDangerousSites;

  /// No description provided for @reportTruncated.
  ///
  /// In fr, this message translates to:
  /// **'Liste incomplète : l\'application a contacté trop de domaines différents.'**
  String get reportTruncated;

  /// No description provided for @reportSeeApp.
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'application'**
  String get reportSeeApp;

  /// No description provided for @reportDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce rapport'**
  String get reportDelete;

  /// No description provided for @reportLocalOnly.
  ///
  /// In fr, this message translates to:
  /// **'Ce rapport reste uniquement sur ce téléphone, jusqu\'au {date}, puis il est supprimé automatiquement. Il n\'est jamais envoyé.'**
  String reportLocalOnly(String date);

  /// No description provided for @reportApproximate.
  ///
  /// In fr, this message translates to:
  /// **'Le nombre de requêtes est approximatif : Android garde certaines réponses en mémoire quelques minutes.'**
  String get reportApproximate;

  /// n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{n} requête} other{{n} requêtes}}'**
  String reportRequests(int count, String n);

  /// No description provided for @reportImitates.
  ///
  /// In fr, this message translates to:
  /// **'Imite {brand}'**
  String reportImitates(String brand);

  /// No description provided for @reportBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Bloqué'**
  String get reportBlocked;

  /// No description provided for @firewallIntro.
  ///
  /// In fr, this message translates to:
  /// **'Bloque les sites dangereux et les traqueurs avant même qu\'une application ne s\'y connecte. Tout se passe sur votre téléphone.'**
  String get firewallIntro;

  /// No description provided for @firewallSinceActivation.
  ///
  /// In fr, this message translates to:
  /// **'Depuis l\'activation'**
  String get firewallSinceActivation;

  /// No description provided for @firewallQueriesAnalyzed.
  ///
  /// In fr, this message translates to:
  /// **'Requêtes analysées'**
  String get firewallQueriesAnalyzed;

  /// No description provided for @firewallQueriesBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Requêtes bloquées'**
  String get firewallQueriesBlocked;

  /// No description provided for @firewallListsLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des listes…'**
  String get firewallListsLoading;

  /// No description provided for @firewallOneVpn.
  ///
  /// In fr, this message translates to:
  /// **'Android n\'autorise qu\'un seul VPN à la fois : si vous en activez un autre, le pare-feu s\'arrête.'**
  String get firewallOneVpn;

  /// No description provided for @firewallUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Listes mises à jour.'**
  String get firewallUpdated;

  /// No description provided for @firewallUpdateFailed.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour impossible : les listes actuelles sont conservées.'**
  String get firewallUpdateFailed;

  /// No description provided for @firewallInvalidDomain.
  ///
  /// In fr, this message translates to:
  /// **'Domaine invalide, par exemple : exemple.fr'**
  String get firewallInvalidDomain;

  /// No description provided for @firewallDomainRefused.
  ///
  /// In fr, this message translates to:
  /// **'Domaine refusé (format invalide ou liste pleine)'**
  String get firewallDomainRefused;

  /// No description provided for @firewallExplain1.
  ///
  /// In fr, this message translates to:
  /// **'Android va vous demander d\'autoriser une « connexion VPN » : c\'est ainsi que Sentinel voit les noms de sites demandés.'**
  String get firewallExplain1;

  /// No description provided for @firewallExplain2.
  ///
  /// In fr, this message translates to:
  /// **'Seules les demandes de noms de sites (DNS) passent par Sentinel, le reste de votre trafic ne change pas.'**
  String get firewallExplain2;

  /// No description provided for @firewallExplain3.
  ///
  /// In fr, this message translates to:
  /// **'Les sites autorisés sont demandés à Quad9 (résolveur suisse), de façon chiffrée : votre réseau ne voit plus les noms des sites.'**
  String get firewallExplain3;

  /// No description provided for @firewallExplain4.
  ///
  /// In fr, this message translates to:
  /// **'Aucun site visité n\'est enregistré : seuls des compteurs existent (sauf pendant une analyse d\'application que vous lancez vous-même).'**
  String get firewallExplain4;

  /// No description provided for @firewallExplain5.
  ///
  /// In fr, this message translates to:
  /// **'Une notification discrète reste affichée tant que le pare-feu est actif.'**
  String get firewallExplain5;

  /// No description provided for @firewallUpdateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour des listes'**
  String get firewallUpdateTitle;

  /// No description provided for @firewallConsent1.
  ///
  /// In fr, this message translates to:
  /// **'Sentinel télécharge les listes de blocage depuis GitHub (raw.githubusercontent.com), en HTTPS, au plus une fois par jour.'**
  String get firewallConsent1;

  /// No description provided for @firewallConsent2.
  ///
  /// In fr, this message translates to:
  /// **'Aucune information vous concernant n\'est envoyée : ni sites visités, ni identifiant. Comme pour toute connexion, GitHub voit l\'adresse IP de votre téléphone.'**
  String get firewallConsent2;

  /// No description provided for @firewallConsent3.
  ///
  /// In fr, this message translates to:
  /// **'Chaque liste est vérifiée (taille, format, cohérence) avant usage. En cas de problème, l\'ancienne version est conservée.'**
  String get firewallConsent3;

  /// No description provided for @blocklistCacheNote.
  ///
  /// In fr, this message translates to:
  /// **'Les changements peuvent prendre quelques minutes à s\'appliquer (cache DNS du navigateur).'**
  String get blocklistCacheNote;

  /// No description provided for @blocklistListsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Listes de blocage'**
  String get blocklistListsTitle;

  /// No description provided for @blocklistAdsWarning.
  ///
  /// In fr, this message translates to:
  /// **'Peut empêcher certaines applications de fonctionner.'**
  String get blocklistAdsWarning;

  /// No description provided for @blocklistImpersonationWarning.
  ///
  /// In fr, this message translates to:
  /// **'Peut bloquer un vrai site non répertorié : ajoutez-le alors à la liste blanche.'**
  String get blocklistImpersonationWarning;

  /// No description provided for @blocklistAutoUpdateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mises à jour automatiques'**
  String get blocklistAutoUpdateTitle;

  /// No description provided for @blocklistUpdateDaily.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour chaque jour'**
  String get blocklistUpdateDaily;

  /// No description provided for @blocklistUpdateNote.
  ///
  /// In fr, this message translates to:
  /// **'Les listes sont téléchargées en HTTPS depuis GitHub, au plus une fois par jour. Aucune information vous concernant n\'est envoyée.'**
  String get blocklistUpdateNote;

  /// No description provided for @blocklistUpdating.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour en cours…'**
  String get blocklistUpdating;

  /// No description provided for @blocklistUpdateNow.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour'**
  String get blocklistUpdateNow;

  /// No description provided for @allowlistTitle.
  ///
  /// In fr, this message translates to:
  /// **'Liste blanche'**
  String get allowlistTitle;

  /// No description provided for @allowlistIntro.
  ///
  /// In fr, this message translates to:
  /// **'Ces sites ne sont jamais bloqués, même s\'ils figurent dans une liste. Leurs sous-domaines non plus.'**
  String get allowlistIntro;

  /// No description provided for @allowlistHint.
  ///
  /// In fr, this message translates to:
  /// **'exemple.fr'**
  String get allowlistHint;

  /// No description provided for @allowlistAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get allowlistAdd;

  /// No description provided for @allowlistEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun site pour l\'instant.'**
  String get allowlistEmpty;

  /// No description provided for @allowlistRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {domain}'**
  String allowlistRemove(String domain);

  /// No description provided for @sourcesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sources et licences'**
  String get sourcesTitle;

  /// No description provided for @sourcesSeeSource.
  ///
  /// In fr, this message translates to:
  /// **'Voir la source'**
  String get sourcesSeeSource;

  /// No description provided for @upstreamIdle.
  ///
  /// In fr, this message translates to:
  /// **'En attente de la première requête'**
  String get upstreamIdle;

  /// No description provided for @upstreamDot.
  ///
  /// In fr, this message translates to:
  /// **'Chiffré (DNS-over-TLS)'**
  String get upstreamDot;

  /// No description provided for @upstreamDoh.
  ///
  /// In fr, this message translates to:
  /// **'Chiffré (DNS-over-HTTPS)'**
  String get upstreamDoh;

  /// No description provided for @upstreamPlain.
  ///
  /// In fr, this message translates to:
  /// **'Non chiffré : autorisé sur ce réseau'**
  String get upstreamPlain;

  /// No description provided for @upstreamFailing.
  ///
  /// In fr, this message translates to:
  /// **'Quad9 injoignable de façon chiffrée'**
  String get upstreamFailing;

  /// No description provided for @upstreamFailingHelp.
  ///
  /// In fr, this message translates to:
  /// **'Ce réseau bloque le DNS chiffré : les sites ne s\'ouvrent pas. Sentinel n\'envoie jamais vos requêtes en clair sans votre accord. Si vous faites confiance à ce réseau, vous pouvez l\'autoriser ci-dessous : les noms des sites visités deviendront alors visibles sur le réseau.'**
  String get upstreamFailingHelp;

  /// No description provided for @upstreamLabel.
  ///
  /// In fr, this message translates to:
  /// **'Requêtes vers Quad9'**
  String get upstreamLabel;

  /// No description provided for @upstreamAllowPlain.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser le DNS non chiffré sur ce réseau'**
  String get upstreamAllowPlain;

  /// No description provided for @dnsStrictTitle.
  ///
  /// In fr, this message translates to:
  /// **'DNS privé incompatible'**
  String get dnsStrictTitle;

  /// No description provided for @dnsStrictMessage.
  ///
  /// In fr, this message translates to:
  /// **'Votre DNS privé est réglé sur « {server} » (mode strict). Avec le pare-feu, plus aucun site ne s\'ouvrirait. Choisissez « Automatique » dans les réglages : Sentinel chiffre déjà vos requêtes DNS.'**
  String dnsStrictMessage(String server);

  /// No description provided for @dnsStrictOpenSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages du DNS privé'**
  String get dnsStrictOpenSettings;

  /// No description provided for @networkProtectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Protection réseau'**
  String get networkProtectionTitle;

  /// No description provided for @vaultSettingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réglages du coffre'**
  String get vaultSettingsTitle;

  /// No description provided for @vaultLock.
  ///
  /// In fr, this message translates to:
  /// **'Verrouiller'**
  String get vaultLock;

  /// No description provided for @vaultEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vos mots de passe, chiffrés'**
  String get vaultEmptyTitle;

  /// No description provided for @vaultEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Stockez vos mots de passe et notes secrètes. Ils sont chiffrés sur votre téléphone et personne d\'autre ne peut les lire.'**
  String get vaultEmptyMessage;

  /// No description provided for @vaultCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon coffre'**
  String get vaultCreate;

  /// No description provided for @vaultUnreadableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Coffre illisible'**
  String get vaultUnreadableTitle;

  /// No description provided for @vaultUnreadableMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier du coffre semble endommagé ou modifié. Sentinel ne peut pas l\'ouvrir.'**
  String get vaultUnreadableMessage;

  /// No description provided for @vaultCreateFailed.
  ///
  /// In fr, this message translates to:
  /// **'La création du coffre a échoué.'**
  String get vaultCreateFailed;

  /// No description provided for @vaultCreateIntro.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un mot de passe maître : il ouvre le coffre et chiffre tout son contenu.'**
  String get vaultCreateIntro;

  /// No description provided for @vaultCreateWarning.
  ///
  /// In fr, this message translates to:
  /// **'Personne, pas même Sentinel, ne peut retrouver ce mot de passe. Vous recevrez ensuite une clé de récupération : notez-la, c\'est le seul moyen d\'ouvrir le coffre si vous l\'oubliez.'**
  String get vaultCreateWarning;

  /// No description provided for @vaultMasterPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe maître'**
  String get vaultMasterPassword;

  /// No description provided for @vaultConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Confirmation'**
  String get vaultConfirmation;

  /// No description provided for @vaultPasswordsDiffer.
  ///
  /// In fr, this message translates to:
  /// **'Les deux mots de passe diffèrent'**
  String get vaultPasswordsDiffer;

  /// No description provided for @vaultUnderstood.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai compris que ce mot de passe ne peut pas être récupéré'**
  String get vaultUnderstood;

  /// No description provided for @vaultCreating.
  ///
  /// In fr, this message translates to:
  /// **'Création…'**
  String get vaultCreating;

  /// No description provided for @vaultRestoreBackup.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer une sauvegarde'**
  String get vaultRestoreBackup;

  /// No description provided for @vaultFingerprintsChanged.
  ///
  /// In fr, this message translates to:
  /// **'Les empreintes du téléphone ont changé. Ouvrez le coffre avec votre mot de passe, puis réactivez l\'empreinte.'**
  String get vaultFingerprintsChanged;

  /// No description provided for @vaultTooManyTries.
  ///
  /// In fr, this message translates to:
  /// **'Trop d\'essais. Utilisez votre mot de passe.'**
  String get vaultTooManyTries;

  /// No description provided for @vaultFingerprintFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'empreinte n\'a pas pu ouvrir le coffre. Utilisez votre mot de passe.'**
  String get vaultFingerprintFailed;

  /// No description provided for @vaultWeeklyPassword.
  ///
  /// In fr, this message translates to:
  /// **'Pour votre sécurité, le mot de passe maître est demandé au moins une fois tous les 7 jours.'**
  String get vaultWeeklyPassword;

  /// No description provided for @vaultLockedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Coffre verrouillé'**
  String get vaultLockedTitle;

  /// No description provided for @vaultUseFingerprintOrPassword.
  ///
  /// In fr, this message translates to:
  /// **'Utilisez votre empreinte ou votre mot de passe maître.'**
  String get vaultUseFingerprintOrPassword;

  /// No description provided for @vaultEnterMasterPassword.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre mot de passe maître.'**
  String get vaultEnterMasterPassword;

  /// No description provided for @vaultOpenWithFingerprint.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir avec l\'empreinte'**
  String get vaultOpenWithFingerprint;

  /// No description provided for @vaultOrWithPassword.
  ///
  /// In fr, this message translates to:
  /// **'Ou avec le mot de passe :'**
  String get vaultOrWithPassword;

  /// No description provided for @vaultWrongPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe incorrect.'**
  String get vaultWrongPassword;

  /// No description provided for @vaultRetryIn.
  ///
  /// In fr, this message translates to:
  /// **'Réessayez dans {seconds} s.'**
  String vaultRetryIn(String seconds);

  /// No description provided for @vaultOpening.
  ///
  /// In fr, this message translates to:
  /// **'Ouverture…'**
  String get vaultOpening;

  /// No description provided for @vaultOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le coffre'**
  String get vaultOpen;

  /// No description provided for @vaultForgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get vaultForgotPassword;

  /// No description provided for @vaultSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement a échoué.'**
  String get vaultSaveFailed;

  /// No description provided for @vaultForgotTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié'**
  String get vaultForgotTitle;

  /// No description provided for @vaultKeyAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Clé acceptée. Choisissez un nouveau mot de passe maître.'**
  String get vaultKeyAccepted;

  /// No description provided for @vaultEnterRecoveryKey.
  ///
  /// In fr, this message translates to:
  /// **'Entrez la clé de récupération notée à la création du coffre. Les tirets et les minuscules sont acceptés.'**
  String get vaultEnterRecoveryKey;

  /// No description provided for @vaultRecoveryKeyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Clé de récupération'**
  String get vaultRecoveryKeyLabel;

  /// No description provided for @vaultWrongRecoveryKey.
  ///
  /// In fr, this message translates to:
  /// **'Clé de récupération incorrecte'**
  String get vaultWrongRecoveryKey;

  /// No description provided for @vaultNewMasterPassword.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe maître'**
  String get vaultNewMasterPassword;

  /// No description provided for @vaultNewKeyWillBeCreated.
  ///
  /// In fr, this message translates to:
  /// **'Une nouvelle clé de récupération sera créée ; l\'ancienne ne fonctionnera plus.'**
  String get vaultNewKeyWillBeCreated;

  /// No description provided for @vaultSaving.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement…'**
  String get vaultSaving;

  /// No description provided for @vaultSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get vaultSave;

  /// No description provided for @vaultKeyCopied.
  ///
  /// In fr, this message translates to:
  /// **'Clé copiée. Elle sera effacée du presse-papiers dans {seconds} s.'**
  String vaultKeyCopied(String seconds);

  /// No description provided for @vaultYourRecoveryKey.
  ///
  /// In fr, this message translates to:
  /// **'Votre clé de récupération'**
  String get vaultYourRecoveryKey;

  /// No description provided for @vaultWriteKeyDown.
  ///
  /// In fr, this message translates to:
  /// **'Écrivez-la sur papier et gardez-la en lieu sûr. C\'est le seul moyen d\'ouvrir le coffre si vous oubliez votre mot de passe.'**
  String get vaultWriteKeyDown;

  /// No description provided for @vaultKeyShownOnce.
  ///
  /// In fr, this message translates to:
  /// **'Elle ne sera plus jamais affichée.'**
  String get vaultKeyShownOnce;

  /// No description provided for @vaultCopy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get vaultCopy;

  /// No description provided for @vaultRetypeLast4.
  ///
  /// In fr, this message translates to:
  /// **'Pour vérifier que vous l\'avez notée, retapez ses 4 derniers caractères.'**
  String get vaultRetypeLast4;

  /// No description provided for @vaultLast4Label.
  ///
  /// In fr, this message translates to:
  /// **'4 derniers caractères'**
  String get vaultLast4Label;

  /// No description provided for @vaultKeyNoted.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai noté ma clé'**
  String get vaultKeyNoted;

  /// No description provided for @vaultKeyCreateFailed.
  ///
  /// In fr, this message translates to:
  /// **'La création de la clé a échoué.'**
  String get vaultKeyCreateFailed;

  /// No description provided for @vaultKeyOfferTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau : la clé de récupération'**
  String get vaultKeyOfferTitle;

  /// No description provided for @vaultKeyOfferText.
  ///
  /// In fr, this message translates to:
  /// **'Si vous oubliez votre mot de passe maître, une clé de récupération est le seul moyen d\'ouvrir le coffre. Créez-la maintenant et notez-la sur papier.'**
  String get vaultKeyOfferText;

  /// No description provided for @vaultCreateKey.
  ///
  /// In fr, this message translates to:
  /// **'Créer ma clé'**
  String get vaultCreateKey;

  /// No description provided for @backupEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier est vide.'**
  String get backupEmpty;

  /// No description provided for @backupUnreadable.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'est pas une sauvegarde Sentinel, ou il est abîmé.'**
  String get backupUnreadable;

  /// No description provided for @backupNewerVersion.
  ///
  /// In fr, this message translates to:
  /// **'Cette sauvegarde vient d\'une version plus récente de Sentinel. Mettez l\'application à jour, puis réessayez.'**
  String get backupNewerVersion;

  /// No description provided for @backupTooBig.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier est trop gros pour être une sauvegarde Sentinel.'**
  String get backupTooBig;

  /// No description provided for @backupCannotReadFile.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire ce fichier.'**
  String get backupCannotReadFile;

  /// No description provided for @backupWrongPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe incorrect, ou fichier modifié depuis l\'export.'**
  String get backupWrongPassword;

  /// No description provided for @backupCannotRead.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire cette sauvegarde.'**
  String get backupCannotRead;

  /// No description provided for @backupRestoreFailed.
  ///
  /// In fr, this message translates to:
  /// **'La restauration a échoué.'**
  String get backupRestoreFailed;

  /// No description provided for @backupIntroFile.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez le fichier .sentinel créé avec « Exporter une sauvegarde chiffrée » sur votre ancien téléphone.'**
  String get backupIntroFile;

  /// No description provided for @backupIntroPassword.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le mot de passe choisi au moment de l\'export.'**
  String get backupIntroPassword;

  /// n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde ouverte : {count, plural, one{{n} élément} other{{n} éléments}}. Choisissez le mot de passe maître de ce téléphone.'**
  String backupIntroNewPassword(int count, String n);

  /// No description provided for @backupPasswordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe de la sauvegarde'**
  String get backupPasswordLabel;

  /// No description provided for @backupNewKeyNote.
  ///
  /// In fr, this message translates to:
  /// **'Une nouvelle clé de récupération sera créée pour ce téléphone.'**
  String get backupNewKeyNote;

  /// No description provided for @backupChooseFile.
  ///
  /// In fr, this message translates to:
  /// **'Choisir le fichier'**
  String get backupChooseFile;

  /// No description provided for @backupRestoring.
  ///
  /// In fr, this message translates to:
  /// **'Restauration…'**
  String get backupRestoring;

  /// No description provided for @backupRestore.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get backupRestore;

  /// No description provided for @vaultAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get vaultAdd;

  /// No description provided for @vaultEmptyList.
  ///
  /// In fr, this message translates to:
  /// **'Votre coffre est vide. Ajoutez un premier mot de passe ou une note secrète.'**
  String get vaultEmptyList;

  /// No description provided for @vaultNoResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat.'**
  String get vaultNoResults;

  /// No description provided for @vaultHealthTitle.
  ///
  /// In fr, this message translates to:
  /// **'Santé des mots de passe'**
  String get vaultHealthTitle;

  /// No description provided for @vaultAllGood.
  ///
  /// In fr, this message translates to:
  /// **'Tout va bien'**
  String get vaultAllGood;

  /// No description provided for @vaultToFix.
  ///
  /// In fr, this message translates to:
  /// **'{count} à corriger'**
  String vaultToFix(String count);

  /// No description provided for @vaultSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get vaultSearch;

  /// No description provided for @vaultTypePassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get vaultTypePassword;

  /// No description provided for @vaultTypeNote.
  ///
  /// In fr, this message translates to:
  /// **'Note secrète'**
  String get vaultTypeNote;

  /// No description provided for @vaultPasswordCopied.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe copié. Il sera effacé du presse-papiers dans {seconds} s.'**
  String vaultPasswordCopied(String seconds);

  /// No description provided for @vaultNeedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un titre à cet élément.'**
  String get vaultNeedTitle;

  /// No description provided for @vaultDeleteItemTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {title} » ?'**
  String vaultDeleteItemTitle(String title);

  /// No description provided for @vaultDeleteItemText.
  ///
  /// In fr, this message translates to:
  /// **'Cet élément sera définitivement effacé du coffre.'**
  String get vaultDeleteItemText;

  /// No description provided for @vaultDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get vaultDelete;

  /// No description provided for @vaultNewPassword.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau : mot de passe'**
  String get vaultNewPassword;

  /// No description provided for @vaultNewNote.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau : note secrète'**
  String get vaultNewNote;

  /// No description provided for @vaultFieldTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get vaultFieldTitle;

  /// No description provided for @vaultFieldNote.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get vaultFieldNote;

  /// No description provided for @vaultFieldUsername.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant'**
  String get vaultFieldUsername;

  /// No description provided for @vaultFieldWebsite.
  ///
  /// In fr, this message translates to:
  /// **'Site web'**
  String get vaultFieldWebsite;

  /// No description provided for @vaultHideGenerator.
  ///
  /// In fr, this message translates to:
  /// **'Masquer le générateur'**
  String get vaultHideGenerator;

  /// No description provided for @vaultGenerate.
  ///
  /// In fr, this message translates to:
  /// **'Générer'**
  String get vaultGenerate;

  /// n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Longueur : {n} caractère} other{Longueur : {n} caractères}}'**
  String generatorLength(int count, String n);

  /// No description provided for @generatorUppercase.
  ///
  /// In fr, this message translates to:
  /// **'Majuscules (A-Z)'**
  String get generatorUppercase;

  /// No description provided for @generatorDigits.
  ///
  /// In fr, this message translates to:
  /// **'Chiffres (0-9)'**
  String get generatorDigits;

  /// No description provided for @generatorSymbols.
  ///
  /// In fr, this message translates to:
  /// **'Symboles (!#\$…)'**
  String get generatorSymbols;

  /// No description provided for @generatorNewPassword.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get generatorNewPassword;

  /// No description provided for @healthToFix.
  ///
  /// In fr, this message translates to:
  /// **'{count} à corriger. Touchez un élément pour changer son mot de passe.'**
  String healthToFix(String count);

  /// No description provided for @healthBreached.
  ///
  /// In fr, this message translates to:
  /// **'Trouvés dans des fuites'**
  String get healthBreached;

  /// No description provided for @healthNoBreach.
  ///
  /// In fr, this message translates to:
  /// **'Aucun mot de passe trouvé dans une fuite.'**
  String get healthNoBreach;

  /// No description provided for @healthReused.
  ///
  /// In fr, this message translates to:
  /// **'Utilisés plusieurs fois'**
  String get healthReused;

  /// No description provided for @healthAllUnique.
  ///
  /// In fr, this message translates to:
  /// **'Chaque mot de passe est unique.'**
  String get healthAllUnique;

  /// No description provided for @healthAlsoUsedFor.
  ///
  /// In fr, this message translates to:
  /// **'Aussi utilisé pour : {titles}'**
  String healthAlsoUsedFor(String titles);

  /// No description provided for @healthWeak.
  ///
  /// In fr, this message translates to:
  /// **'Trop faibles'**
  String get healthWeak;

  /// No description provided for @healthNoWeak.
  ///
  /// In fr, this message translates to:
  /// **'Aucun mot de passe trop faible.'**
  String get healthNoWeak;

  /// No description provided for @healthEasyToGuess.
  ///
  /// In fr, this message translates to:
  /// **'Facile à deviner'**
  String get healthEasyToGuess;

  /// No description provided for @healthCheckIntro.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez si vos mots de passe apparaissent dans des fuites connues (Have I Been Pwned).'**
  String get healthCheckIntro;

  /// No description provided for @healthCheckButton.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier les fuites'**
  String get healthCheckButton;

  /// No description provided for @healthChecking.
  ///
  /// In fr, this message translates to:
  /// **'Vérification… {done} / {total}'**
  String healthChecking(String done, String total);

  /// No description provided for @healthRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get healthRetry;

  /// Nombre de fois où le mot de passe a été vu (« fois » invariable). n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, other{Ce mot de passe a été vu {n} fois dans des fuites de données. Changez-le.}}'**
  String breachMessage(int count, String n);

  /// n = le même nombre, déjà formaté
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, other{Vu {n} fois dans des fuites}}'**
  String breachShort(int count, String n);

  /// No description provided for @breachConsentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier les fuites ?'**
  String get breachConsentTitle;

  /// No description provided for @breachConsentText.
  ///
  /// In fr, this message translates to:
  /// **'Sentinel envoie seulement les 5 premiers caractères d\'une empreinte (hash) de chaque mot de passe à Have I Been Pwned. Votre mot de passe ne quitte jamais le téléphone.'**
  String get breachConsentText;

  /// No description provided for @breachConsentDetail.
  ///
  /// In fr, this message translates to:
  /// **'Le service répond avec une liste de fuites connues, et la comparaison se fait sur votre téléphone. Vous pourrez retirer cet accord dans les réglages du coffre.'**
  String get breachConsentDetail;

  /// No description provided for @breachConsentCheck.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier'**
  String get breachConsentCheck;

  /// No description provided for @breachErrorTimeout.
  ///
  /// In fr, this message translates to:
  /// **'Le service ne répond pas. Réessayez plus tard.'**
  String get breachErrorTimeout;

  /// No description provided for @breachErrorOffline.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion Internet. Vérifiez le Wi-Fi ou les données mobiles.'**
  String get breachErrorOffline;

  /// No description provided for @breachErrorTooMany.
  ///
  /// In fr, this message translates to:
  /// **'Trop de demandes. Réessayez dans un instant.'**
  String get breachErrorTooMany;

  /// No description provided for @breachErrorUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Le service Have I Been Pwned est indisponible (erreur {code}).'**
  String breachErrorUnavailable(String code);

  /// No description provided for @clipboardSharedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Presse-papiers partagé'**
  String get clipboardSharedTitle;

  /// No description provided for @clipboardSharedWarning.
  ///
  /// In fr, this message translates to:
  /// **'Sur cette version d\'Android, toutes les applications peuvent lire ce que vous copiez. Le presse-papiers sera vidé après 10 secondes.'**
  String get clipboardSharedWarning;

  /// No description provided for @clipboardCopyAnyway.
  ///
  /// In fr, this message translates to:
  /// **'Copier quand même'**
  String get clipboardCopyAnyway;

  /// No description provided for @fieldShow.
  ///
  /// In fr, this message translates to:
  /// **'Afficher'**
  String get fieldShow;

  /// No description provided for @fieldHide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get fieldHide;

  /// No description provided for @strengthWeak.
  ///
  /// In fr, this message translates to:
  /// **'faible'**
  String get strengthWeak;

  /// No description provided for @strengthMedium.
  ///
  /// In fr, this message translates to:
  /// **'moyen'**
  String get strengthMedium;

  /// No description provided for @strengthStrong.
  ///
  /// In fr, this message translates to:
  /// **'fort'**
  String get strengthStrong;

  /// No description provided for @strengthLine.
  ///
  /// In fr, this message translates to:
  /// **'Force : {strength}'**
  String strengthLine(String strength);

  /// No description provided for @strengthLineTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Force : {strength} · {length} / {min} caractères minimum'**
  String strengthLineTooShort(String strength, String length, String min);

  /// No description provided for @vaultFingerprintEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Ouverture par l\'empreinte activée.'**
  String get vaultFingerprintEnabled;

  /// No description provided for @vaultBiometricTooManyTries.
  ///
  /// In fr, this message translates to:
  /// **'Trop d\'essais. Réessayez dans quelques instants.'**
  String get vaultBiometricTooManyTries;

  /// No description provided for @vaultNoFingerprint.
  ///
  /// In fr, this message translates to:
  /// **'Aucune empreinte enregistrée sur ce téléphone.'**
  String get vaultNoFingerprint;

  /// No description provided for @vaultFingerprintActivationFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'activation de l\'empreinte a échoué.'**
  String get vaultFingerprintActivationFailed;

  /// No description provided for @vaultNewKeyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle clé de récupération ?'**
  String get vaultNewKeyTitle;

  /// No description provided for @vaultNewKeyText.
  ///
  /// In fr, this message translates to:
  /// **'L\'ancienne clé ne fonctionnera plus. Pensez à noter la nouvelle.'**
  String get vaultNewKeyText;

  /// No description provided for @vaultDeleteFailed.
  ///
  /// In fr, this message translates to:
  /// **'La suppression a échoué.'**
  String get vaultDeleteFailed;

  /// No description provided for @vaultFingerprintWeekly.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe reste demandé au moins une fois tous les 7 jours.'**
  String get vaultFingerprintWeekly;

  /// No description provided for @vaultBreachSettingDetail.
  ///
  /// In fr, this message translates to:
  /// **'Have I Been Pwned. Seul un début d\'empreinte est envoyé, jamais le mot de passe.'**
  String get vaultBreachSettingDetail;

  /// No description provided for @vaultChangeMaster.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe maître'**
  String get vaultChangeMaster;

  /// No description provided for @vaultNewRecoveryKey.
  ///
  /// In fr, this message translates to:
  /// **'Générer une nouvelle clé de récupération'**
  String get vaultNewRecoveryKey;

  /// No description provided for @vaultExport.
  ///
  /// In fr, this message translates to:
  /// **'Exporter une sauvegarde chiffrée'**
  String get vaultExport;

  /// No description provided for @vaultDeleteVault.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le coffre'**
  String get vaultDeleteVault;

  /// No description provided for @vaultDeleteVaultTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le coffre ?'**
  String get vaultDeleteVaultTitle;

  /// No description provided for @vaultDeleteVaultText.
  ///
  /// In fr, this message translates to:
  /// **'Tous les mots de passe et notes seront définitivement effacés. Tapez {word} pour confirmer.'**
  String vaultDeleteVaultText(String word);

  /// Mot à taper pour confirmer
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER'**
  String get vaultDeleteWord;

  /// No description provided for @vaultMasterChanged.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe maître changé.'**
  String get vaultMasterChanged;

  /// No description provided for @vaultCurrentPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe actuel'**
  String get vaultCurrentPassword;

  /// No description provided for @vaultWrongPasswordShort.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe incorrect'**
  String get vaultWrongPasswordShort;

  /// No description provided for @vaultChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get vaultChange;

  /// No description provided for @exportSaved.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde enregistrée. Gardez son mot de passe en lieu sûr.'**
  String get exportSaved;

  /// No description provided for @exportCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Export annulé.'**
  String get exportCancelled;

  /// No description provided for @exportFileFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement du fichier a échoué.'**
  String get exportFileFailed;

  /// No description provided for @exportFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'export a échoué.'**
  String get exportFailed;

  /// No description provided for @exportIntro.
  ///
  /// In fr, this message translates to:
  /// **'Pour passer à un nouveau téléphone : un fichier .sentinel, chiffré par le mot de passe choisi ici. Sans ce mot de passe, personne ne peut le lire, pas même Sentinel.'**
  String get exportIntro;

  /// No description provided for @exportStore.
  ///
  /// In fr, this message translates to:
  /// **'Rangez le fichier où vous voulez (Drive, clé USB, ordinateur) et ne le perdez pas avec son mot de passe.'**
  String get exportStore;

  /// No description provided for @exportPasswordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe d\'export'**
  String get exportPasswordLabel;

  /// No description provided for @exportEncrypting.
  ///
  /// In fr, this message translates to:
  /// **'Chiffrement…'**
  String get exportEncrypting;

  /// No description provided for @exportButton.
  ///
  /// In fr, this message translates to:
  /// **'Exporter'**
  String get exportButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
