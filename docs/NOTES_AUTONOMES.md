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
