# Notes de travail autonome

## Export / import chiffré du coffre (2026-10-25)

Choix faits sans demander :

- **Format `.sentinel` en JSON**, comme `vault.json` : `format` (`"sentinel-sauvegarde"`), `version` (1), `kdf` (Argon2id), `data` (nonce + chiffré). Tout sauf `data` forme l'en-tête, utilisé comme AAD. Code : `lib/services/vault/vault_backup.dart`.
- **Clé = Argon2id du mot de passe d'export** (sel neuf, paramètres par défaut du coffre), qui chiffre directement la liste des éléments en AES-256-GCM. Pas de DEK intermédiaire : un seul usage, un sel neuf par export. Aucune primitive nouvelle : `deriveKek` et `_encrypt` / `_decrypt` de `vault_crypto.dart`.
- **Mot de passe d'export** : mêmes règles que le mot de passe maître (`isMasterPasswordAcceptable`) + confirmation. Il peut être identique au mot de passe maître (pas interdit, la sécurité est la même).
- **Ce qui est exporté** : seulement les éléments (mots de passe, notes). Pas les emplacements de clé, ni l'empreinte, ni la clé de récupération, ni le consentement HIBP.
- **Restauration = coffre neuf** : nouvelle DEK, nouveau mot de passe maître, nouvelle clé de récupération (affichée ensuite, comme à la création). Interdite si un coffre existe déjà (le bouton n'est visible que sur l'écran de création).
- **Messages** : mauvais mot de passe et fichier modifié donnent le même message (GCM ne permet pas de les distinguer). Fichier vide, pas une sauvegarde, trop gros (> 16 Mio) ou version inconnue : vérifiés dès le choix du fichier, avant de demander le mot de passe.
- **Sélecteur Android sans dépendance** : `ACTION_CREATE_DOCUMENT` / `ACTION_OPEN_DOCUMENT` dans `VaultDocuments.kt`, sur le canal existant `com.iheb.sentinel/vault` (pas de paquet `file_picker`). Lecture/écriture sur un thread à part. Codes de requête 3 et 4 (1 et 2 déjà pris).
- **Windows** : le sélecteur n'existe pas, les deux boutons sont masqués (`VaultPlatform.supportsDocuments`).
- **Nom proposé** : `sentinel-coffre-AAAA-MM-JJ.sentinel`, type MIME `application/octet-stream` (aucun type pour `.sentinel`). À l'ouverture, `*/*` : certains gestionnaires de fichiers ne savent pas filtrer par extension.
- **Verrouillage automatique** : le fichier chiffré est calculé avant d'ouvrir le sélecteur. Si l'utilisateur reste plus de 30 s dans le sélecteur, le coffre se verrouille, mais l'enregistrement se termine quand même (les octets sont déjà chiffrés).
- **Bouton « Restaurer une sauvegarde »** placé en bas de l'écran « Créer mon coffre » (comme demandé), pas sur l'écran vide d'accueil du coffre.

Non vérifié : l'interface n'a pas été lancée sur un téléphone (règle : pas de `flutter run`). Le parcours réel avec le sélecteur Android est à tester à la main.

## Présentation du premier lancement et Réglages / À propos (2026-10-25)

Choix faits sans demander :

- **Préférence « présentation vue »** : petit fichier `onboarding.json` dans le dossier privé de l'app (`OnboardingStore`, même modèle que `BreachConsentStore`). Pas de paquet `shared_preferences` ajouté. Fichier absent ou abîmé : la présentation revient. Si l'écriture échoue, l'app s'ouvre quand même (la présentation reviendra au lancement suivant).
- **Démarrage** : `StartupGate` lit la préférence avant de construire `MainShell`. Pendant cette lecture (quelques ms), un fond uni ; l'accueil (et son analyse Android) ne démarre qu'après « Commencer ».
- **3 écrans** : ce que fait Sentinel ; vie privée avec la liste exacte des 3 échanges réseau facultatifs (Have I Been Pwned, Quad9, mise à jour des listes depuis GitHub) ; autorisations demandées au moment où elles servent. Boutons « Suivant » puis « Commencer », pas de bouton « Passer » (3 écrans courts). Arche pleine en bleu en haut de chaque écran.
- **Icône Réglages** : roue dentée discrète (encre à 50 %) à droite de « Bonjour » sur l'accueil.
- **Version** : constante `appVersion` dans `lib/app_info.dart` plutôt qu'un paquet `package_info_plus` ou un canal Kotlin. Un test vérifie qu'elle suit `version:` de `pubspec.yaml` : il faudra la changer en même temps.
- **Liens GitHub en minuscules** (`github.com/ihebnsir/sentinel`) : `test/home_greeting_test.dart` interdit le prénom dans `lib/` ; GitHub ignore la casse du nom de compte. Les liens supposent que le dépôt est public et que la branche s'appelle `main`.
- **Politique de confidentialité** : écrite d'après le code (manifeste, `pwned_passwords.dart`, `FirewallEngine.kt`, `FirewallSettings.kt`, `ProtectionSettings.kt`, `SECURITY_DESIGN.md`). Rien sur iOS ni Windows (non distribués). Le texte est dans `privacySections` ; un test vérifie que la présentation et la politique citent les mêmes trois services.
- **Licences** : `showLicensePage` (bibliothèques Dart, Readex Pro déjà enregistrée) + deux entrées ajoutées dans `main.dart` : `assets/blocklists/LICENSES.txt` (Phishing.Database, AdGuard, AdAway, ShadowWhisperer) et la mention CC BY 4.0 lue dans `assets/data/stalkerware_ioc.json`. Le modèle anti-arnaque est entraîné sur des données synthétiques du projet : pas de licence tierce.
- **Rapport d'audit** : page de résumé (d'après la section 1 de `docs/audit/RAPPORT_AUDIT.md`) + bouton vers le rapport complet sur GitHub. À mettre à jour si le rapport change.
- **Signaler une faille** : ouvre directement `SECURITY.md` sur GitHub dans le navigateur (canal existant `openWebPage`, https uniquement).

Non vérifié : l'interface n'a pas été lancée sur un téléphone (règle : pas de `flutter run`). Le bouton Réglages de l'accueil n'a pas de test widget (l'accueil appelle les canaux Android) ; les écrans eux-mêmes sont testés.

## Traduction : français, arabe, anglais (2026-10-25)

Choix faits sans demander :

- **Système officiel** : `flutter_localizations` + `gen-l10n` (`l10n.yaml`). Fichiers ARB dans `lib/l10n` : `app_fr.arb` (modèle, chaque valeur à insérer y est décrite), `app_ar.arb`, `app_en.arb`. Les fichiers générés (`app_localizations*.dart`) sont écrits dans `lib/l10n` et commités (le « paquet synthétique » n'existe plus). Clés en camelCase, préfixées par l'écran ou la fonction (`home…`, `vault…`, `risk…`, `reason…`, `perm…`).
- **material_ui** : les délégués `GlobalMaterialLocalizations` de `material_ui` (pas ceux de `flutter_localizations`, d'un autre type), `GlobalCupertinoLocalizations` de `cupertino_ui`, `GlobalWidgetsLocalizations` (sens de lecture). Liste dans `lib/l10n/l10n.dart`, avec `context.l10n` et les formats de nombres et de dates. `intl` et `cupertino_ui` ajoutés en dépendances directes (déjà présents en indirect).
- **Langue** : celle du téléphone, sinon le français (premier de la liste). Choix manuel en tête de Réglages (« Langue » : langue du téléphone, Français, العربية, English ; chaque nom écrit dans sa langue). Mémorisé dans `language.json` (même modèle que `onboarding.json`), lu avant le premier écran.
- **Kotlin** : `res/values` (français, par défaut), `values-en`, `values-ar` pour les notifications (arnaque, pare-feu, VPN), leurs canaux, la fenêtre d'empreinte et les deux libellés du manifeste. Le choix de Réglages est envoyé par le canal `com.iheb.sentinel/language` et gardé dans `AppLanguage.kt` ; les textes passent par `createConfigurationContext`. Les deux libellés du manifeste (menu « Vérifier avec Sentinel », réglage d'accès aux notifications) sont affichés par Android : ils suivent la langue du téléphone. L'analyse en arrière-plan reçoit la langue de Kotlin (`language`).
- **Textes des règles** : les règles renvoient des données (`AppRiskRule`, `LinkFinding`, `MessageAnalysis`, `AnalysisStartError`, `BreachProblem`…) et la phrase est écrite à l'affichage. Le score et le Wi-Fi sont recalculés dans `build`. Changer de langue retraduit tout sans relancer d'analyse.
- **Pluriels** ICU, avec les 6 formes de l'arabe. **Nombres** : français inchangé (espace insécable) ; arabe et anglais en chiffres 0-9 avec virgule (format `intl` « ar », courant au Maghreb). **Dates** : français inchangé (« 1er mars ») ; sinon `intl` (mois arabes du Machrek, ex. أغسطس ; en Tunisie on dirait plutôt أوت : à voir à la relecture).
- **Arabe** standard simple : الخزنة (coffre), جدار الحماية (pare-feu), مفتاح الاسترداد (clé de récupération), صلاحيات الجذر (root). Durées abrégées « د » (minutes) et « ث » (secondes).
- **Non traduit** (noms propres ou techniques) : Sentinel, noms des marques et des apps (`known_brands.json`, `known_apps.dart`, ex. « La Poste Tunisienne »), sigles Wi-Fi (WEP, WPA, WPA3, OWE), noms et attributions des listes de blocage (textes de licence), nom du fichier d'export (`sentinel-coffre-AAAA-MM-JJ.sentinel`). L'entrée de la page Licences devient « Phishing.Database, AdGuard, AdAway, ShadowWhisperer » (cette page système n'est pas traduite).
- **Mot à taper pour supprimer le coffre** : traduit (SUPPRIMER, DELETE, حذف).
- **Politique de confidentialité** : « langue » ajoutée à « Vos choix » (nouveau fichier `language.json`).
- **Police** : Readex Pro contient l'alphabet arabe et la table de liaison des lettres (GSUB « arab »). `test/l10n_keys_test.dart` vérifie que chaque caractère des 3 fichiers ARB existe dans la police.
- **Relecture humaine** : attribut `@@x-relecture` dans chaque ARB, commentaire en tête de `values-en` et `values-ar`.
- **Tests ajoutés** : `l10n_keys_test.dart` (mêmes clés et mêmes valeurs à insérer dans les 3 langues, police), `l10n_screens_test.dart` (accueil et Messages en arabe de droite à gauche, et en anglais), `language_test.dart` (choix dans Réglages, fichier), `StringsResourcesTest.kt` (mêmes clés Android dans les 3 langues, manifeste sans texte en dur).

Non vérifié : l'interface n'a pas été lancée sur un téléphone (règle : pas de `flutter run`). Le rendu arabe réel (textes longs, retours à la ligne) et les notifications en arabe sont à regarder à la main. Le réglage Android 13 « Langue de l'application » n'est pas branché (`locales_config`) : le choix se fait dans Sentinel.
