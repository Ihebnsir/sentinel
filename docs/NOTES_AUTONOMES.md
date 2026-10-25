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
