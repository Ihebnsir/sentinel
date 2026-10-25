<p align="center">
  <img src="assets/branding/icon_full.png" alt="Icône de Sentinel" width="112">
</p>

<h1 align="center">Sentinel</h1>

<p align="center">
  Application de sécurité Android qui audite le téléphone, note les applications installées, détecte les messages d'arnaque sur l'appareil et protège les secrets dans un coffre chiffré.
</p>

<p align="center">
  <a href="https://github.com/Ihebnsir/sentinel/actions/workflows/ci.yml"><img src="https://github.com/Ihebnsir/sentinel/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-MIT-blue.svg" alt="Licence : MIT"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <b>Français</b>
</p>

---

L'interface de l'application est en français. Tout se passe sur le téléphone. Rien ne passe par le réseau sans votre accord : les seuls appels réseau viennent de trois fonctions facultatives, la vérification des fuites auprès de Have I Been Pwned (5 caractères hexadécimaux d'une empreinte SHA-1, k-anonymity), le pare-feu DNS (transmet les requêtes DNS à Quad9, chiffrées en DNS-over-TLS ou HTTPS) et la mise à jour des listes de blocage (téléchargées depuis GitHub).

## Captures d'écran

> **TODO :** ajouter les captures dans `docs/screenshots/` (voir [docs/screenshots/README.md](docs/screenshots/README.md)), puis décommenter le tableau ci-dessous.

<!--
| Accueil | Applications | Messages | Coffre |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/home.png" width="200"> | <img src="docs/screenshots/apps.png" width="200"> | <img src="docs/screenshots/messages.png" width="200"> | <img src="docs/screenshots/vault.png" width="200"> |
-->

## Fonctionnalités

- **Audit du téléphone.** Score de sécurité sur 100 calculé à partir de 7 vérifications : verrouillage d'écran, indices de root, âge du correctif de sécurité (< 90 jours), biométrie forte, options pour les développeurs, débogage USB et chiffrement du stockage. Les vérifications échouées ouvrent l'écran de réglages Android correspondant (sauf le root, qui ne se corrige pas depuis les réglages).
- **Analyse des applications.** Liste les applications installées et leur donne un score de risque de 0 à 100 avec des règles explicables : service d'accessibilité, source d'installation, administrateur de l'appareil, accès aux SMS, lecture des notifications, superposition, micro, localisation en arrière-plan, `targetSdk` ancien, etc. Les applications système préinstallées ne sont signalées que pour l'accessibilité ou l'administration de l'appareil.
- **Fausses applications et logiciels espions.** Lit le certificat de signature de chaque application (SHA-256/SHA-1, sujet) et vérifie si son icône a été cachée. Signale les applications qui prennent le nom d'une application connue (WhatsApp, Facebook, Instagram, TikTok…) avec un autre package, les packages officiels signés par quelqu'un d'autre (une fois les empreintes de référence remplies), les versions modifiées de WhatsApp (GB WhatsApp, FM WhatsApp…), les signatures de test et les stalkerwares connus de la liste publique [Stalkerware Indicators](https://github.com/AssoEchap/stalkerware-indicators), même déguisés en application système. En cas de logiciel espion possible, Sentinel affiche des conseils de sécurité **avant** de proposer la désinstallation, et n'envoie jamais de notification à ce sujet.
- **Détection des arnaques.** On colle un message, on le partage depuis une autre application, ou on sélectionne du texte puis « Vérifier avec Sentinel ». Un modèle embarqué (TF-IDF sur n-grammes de caractères + régression logistique) est combiné à des règles sur les liens : usurpation de marque, adresse IP, punycode, `@` dans l'URL, raccourcisseurs, extensions suspectes, trop de sous-domaines, `http` sans chiffrement. Le verdict est accompagné de ses raisons.
- **Protection automatique (facultative).** Un service d'écoute des notifications lit les messages reçus dans les applications SMS, WhatsApp, WhatsApp Business, Messenger, Telegram et Viber. Ils sont analysés par le même modèle Dart, dans un moteur Flutter sans écran (headless), et une alerte « Arnaque probable » s'affiche quand le verdict est une arnaque.
- **Analyse du Wi-Fi.** Affiche le type de chiffrement (ouvert, WEP, WPA2, WPA3, OWE, entreprise), la présence d'un portail captif et l'état du DNS privé, sans permission de localisation et sans lire le nom du réseau.
- **Coffre chiffré.** Range des mots de passe et des notes secrètes, chiffrés avec Argon2id + AES-256-GCM. On l'ouvre avec le mot de passe maître, une clé de récupération ou l'empreinte digitale (Android Keystore). Une sauvegarde chiffrée (fichier `.sentinel`) permet de le transférer sur un nouveau téléphone.
- **Outils mots de passe.** Générateur aléatoire (12 à 64 caractères), estimation de la force et bilan de santé des mots de passe : fuites (Have I Been Pwned), réutilisés et faibles.

## Points forts en sécurité

- **Respect de la vie privée dès la conception.** Pas de compte, pas de statistiques d'usage, pas de serveur. Le texte des messages n'est jamais journalisé ni enregistré. Kotlin ne garde que des valeurs `hashCode()` pour ignorer les doublons.
- **Appels réseau sur accord uniquement.** Aucun appel réseau au démarrage (la police est embarquée). La vérification des fuites demande un consentement explicite. Elle utilise l'API « range » de Pwned Passwords (k-anonymity) : seuls les 5 premiers caractères hexadécimaux de l'empreinte SHA-1 quittent le téléphone, et l'en-tête `Add-Padding: true` masque la taille de la réponse. Les résultats restent en mémoire et sont effacés au verrouillage du coffre.
- **Cryptographie du coffre.** Une clé de données (DEK) aléatoire de 256 bits chiffre les éléments en AES-256-GCM, avec un nonce neuf de 12 octets à chaque écriture. La DEK est enveloppée par une clé de chiffrement de clé (KEK) pour chaque *emplacement de clé* (key slot) :
  - mot de passe : Argon2id, 46 Mio, 2 passes, parallélisme 1, sel aléatoire de 16 octets, calculé dans un isolate séparé ;
  - clé de récupération : 28 caractères parmi 32 symboles (140 bits), HKDF-SHA256 ;
  - empreinte : clé AES-256-GCM dans l'Android Keystore, `BIOMETRIC_STRONG` exigé à chaque opération, invalidée si une nouvelle empreinte est enregistrée.
- **En-tête authentifié.** Tout l'en-tête du fichier (emplacements, paramètres de dérivation, date de dernière ouverture par mot de passe) sert de données associées AES-GCM. Modifier un seul octet fait échouer le déchiffrement. Les paramètres de dérivation lus dans le fichier sont bornés : un fichier trafiqué ne peut pas exiger une mémoire ou un nombre de passes extrêmes.
- **Ouverture renforcée.** Délai croissant après un mauvais mot de passe (1 s, 2 s, 4 s… plafonné à 30 s). Le mot de passe maître est de nouveau exigé après 7 jours d'ouvertures par empreinte seule.
- **Protection à l'écran.** `FLAG_SECURE` sur l'onglet Coffre (pas de capture d'écran, aperçu masqué dans les applications récentes). Le coffre se verrouille quand l'écran s'éteint et après 30 s en arrière-plan. Les secrets copiés sont marqués sensibles (Android 13+) et effacés du presse-papiers après 30 s.
- **Alertes sûres.** Les alertes d'arnaque affichent un texte neutre sur l'écran verrouillé. Les domaines cités dans l'alerte sont neutralisés (`site[.]xyz`), et les actions automatiques « Ouvrir le lien » d'Android sont désactivées.
- **Écriture atomique.** Le coffre est écrit dans un fichier temporaire puis renommé : un plantage ne peut pas l'abîmer.
- **Pas de sauvegarde Android.** `allowBackup="false"`, complété par des `dataExtractionRules` sur Android 12+, empêche les données de l'application de partir dans les sauvegardes cloud ou lors d'un transfert vers un autre téléphone. Pour changer de téléphone, on exporte le coffre à la place (point suivant).
- **Export / import chiffré.** « Exporter une sauvegarde chiffrée » (réglages du coffre) écrit un fichier `.sentinel` versionné : Argon2id d'un mot de passe d'export distinct (mêmes règles de force que le mot de passe maître) + AES-256-GCM, avec l'en-tête en données associées. Il est enregistré et ouvert via le sélecteur de fichiers d'Android (Storage Access Framework) : aucune permission de stockage. « Restaurer une sauvegarde » (écran de création du coffre) demande le fichier, son mot de passe, puis un nouveau mot de passe maître, et crée un coffre neuf avec une nouvelle clé de récupération. Mauvais mot de passe ou fichier modifié : message clair, jamais de plantage.

Modèle de menaces complet et limites connues : [docs/SECURITY_DESIGN.md](docs/SECURITY_DESIGN.md) (en anglais).

## Architecture

Flutter (Dart) gère l'interface et toute la logique : calcul des scores, inférence ML, cryptographie. Kotlin accède aux API Android via des `MethodChannel` : état du téléphone, gestionnaire de paquets, Wi-Fi, Keystore et biométrie, écoute des notifications. Pour l'analyse en arrière-plan, Kotlin démarre un moteur Flutter sans écran qui exécute le même modèle Dart que l'interface.

Schémas et détails : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (en anglais).

## Technologies

| Domaine | Technologie |
|---|---|
| Application | Flutter 3.47.7, Dart 3.13.5 |
| Android | Kotlin, Java 17, Android Gradle Plugin 9.1.0, Gradle 9.3.1 |
| Cryptographie | [`cryptography`](https://pub.dev/packages/cryptography) (Argon2id, AES-GCM, HKDF), [`crypto`](https://pub.dev/packages/crypto) (SHA-1), Android Keystore |
| Réseau | [`http`](https://pub.dev/packages/http) (API Pwned Passwords uniquement) |
| Apprentissage automatique | Python 3.14, scikit-learn 1.9.1, pandas, numpy (entraînement seulement ; l'inférence est en Dart) |
| CI | GitHub Actions, Gitleaks, Dependabot |

## Tests

**447 tests** répartis dans 29 fichiers (`flutter test`). Ils couvrent :

- le coffre : vecteur de test Argon2id de la RFC 9106, chiffrement, emplacements de clé, migration v1 → v2, détection des modifications (chiffré, clé enveloppée, en-tête), session et verrouillage ;
- la sauvegarde chiffrée : aller-retour export/import, mauvais mot de passe, fichier altéré, version inconnue, fichier vide, restauration dans un coffre neuf ;
- la **parité exacte** entre le modèle Dart et scikit-learn sur 30 textes de référence (5 langues et cas limites Unicode, tolérance 1e-9) ;
- le client k-anonymity, avec un faux client HTTP ;
- les règles de risque des applications, du téléphone et du Wi-Fi ;
- le bilan de santé des mots de passe et le générateur.

Le réseau et la biométrie sont remplacés par des doublures de test : les tests tournent hors ligne.

## Démarrage

Prérequis : Flutter 3.47.7 (stable), Java 17, SDK Android. Android est la seule plateforme cible.

```bash
git clone https://github.com/Ihebnsir/sentinel.git
cd sentinel
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Les builds release utilisent encore la configuration de signature de debug. La signature release reste à faire (voir Feuille de route).

## Apprentissage automatique

Le classifieur d'arnaques est entraîné en Python (`ml/train.py`) et exporté dans `assets/models/phishing_model.json`. L'application réimplémente le prétraitement et la prédiction en Dart pur (`lib/services/phishing/phishing_model.dart`). La spécification exacte est dans [ml/README.md](ml/README.md).

Chaîne de traitement :

1. Fusion de `ml/data/messages_seed.csv` (400 messages synthétiques : 200 arnaques, 200 normaux) et de `ml/data/messages_perso.csv` (vrais messages ; vide pour l'instant), puis suppression des doublons.
2. Découpage stratifié 80 / 20 (`random_state=42`).
3. `TfidfVectorizer(analyzer="char_wb", ngram_range=(2, 5), sublinear_tf=True, min_df=2, max_features=8000)`.
4. `LogisticRegression(class_weight="balanced")`, avec `C` choisi par validation croisée à 5 plis sur le F1 (retenu : `C = 30`).
5. Export du modèle et des textes de parité. Une implémentation de référence sans scikit-learn revérifie la spécification.

Langues : français, arabe, derja tunisienne (alphabet latin et arabe), anglais.

Métriques sur le jeu de test, telles qu'écrites par `train.py` dans `metrics_test` du modèle livré (80 messages) :

| Précision | Rappel | F1 | Exactitude | Matrice de confusion `[[VN, FP], [FN, VP]]` |
|---:|---:|---:|---:|---|
| 0,952 | 1,000 | 0,976 | 0,975 | `[[38, 2], [0, 40]]` |

> **Avertissement honnête.** Les données sont synthétiques et écrites à la main, et ces chiffres sont **trop optimistes**. Ils ne montrent pas les performances réelles. Dans les données synthétiques, tous les liens d'arnaque utilisent `.xyz`/`.top` ou `bit.ly` : le modèle s'appuie donc beaucoup sur ces n-grammes. Dans l'application, les règles sur les liens et un seuil prudent (≥ 0,8 pour « Arnaque probable » avec le modèle seul) compensent en partie. Des métriques crédibles demandent de vrais messages variés.

## Feuille de route

Ces points viennent des limites connues relevées dans le code et la documentation. **TODO :** les relire et les classer.

- [ ] Collecter de vrais messages (anonymisés) et réentraîner pour obtenir des métriques crédibles.
- [ ] Vérifier à la main les domaines officiels de `lib/services/phishing/known_brands.dart` (TODO dans le code).
- [ ] Configurer la signature release (clés de debug actuellement).
- [ ] Conserver le compteur d'échecs d'ouverture après un redémarrage de l'application.
- [x] Export / import chiffré du coffre, pour le transférer sur un nouveau téléphone (la sauvegarde Android est volontairement désactivée).
- [ ] Ajouter les captures d'écran.
- [ ] Remplir les empreintes de certificat de référence dans `lib/services/apps/known_apps.dart` avec `tools/signatures/extract_cert.py`, ainsi que les packages des applications bancaires et postales tunisiennes (TODO dans le code).
- [ ] Ajouter des contacts d'aide tunisiens vérifiés à l'écran de conseils (TODO dans `spyware_advice_screen.dart`).

## Sécurité

Merci de signaler les vulnérabilités en privé. Voir [SECURITY.md](SECURITY.md).

L'application a été auditée selon l'OWASP MASVS v2 (analyse statique et dynamique, 17 constats et leurs corrections) : voir le [rapport d'audit](docs/audit/RAPPORT_AUDIT.md). La publication d'une version est décrite dans [docs/RELEASE.md](docs/RELEASE.md).

## Données tierces

`assets/data/stalkerware_ioc.json` est dérivé de [Stalkerware Indicators of Compromise](https://github.com/AssoEchap/stalkerware-indicators) par [Echap](https://echap.eu.org/) (Julien Voisin, Tek et contributeurs), sous licence [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/deed.fr). Modifications : seuls les noms d'applications, les noms de packages et les empreintes SHA-1 des certificats sont conservés, convertis en JSON par `tools/stalkerware/update_ioc.py` à un commit épinglé. La liste n'est pas exhaustive : aucune correspondance ne veut pas dire aucun stalkerware.

Les listes du pare-feu DNS (`assets/blocklists/`) sont générées par `tools/blocklists/update_lists.py` à des commits épinglés, converties en liste de domaines, fusionnées et dédoublonnées (les domaines protégés sont retirés) :

- [Phishing.Database](https://github.com/Phishing-Database/Phishing.Database), sous licence [MIT](https://github.com/Phishing-Database/Phishing.Database/blob/master/LICENSE). Copyright (c) 2018-2025 Mitchell Krog, Copyright (c) 2018-2025 Nissar Chababy, Copyright (c) 2018-2025 Phishing.Database Contributors.
- [BlockLists](https://github.com/ShadowWhisperer/BlockLists) par ShadowWhisperer, dans le domaine public ([The Unlicense](https://github.com/ShadowWhisperer/BlockLists/blob/master/LICENSE)).
- [AdGuard CNAME disguised trackers list](https://github.com/AdguardTeam/cname-trackers), sous licence [MIT](https://github.com/AdguardTeam/cname-trackers/blob/master/LICENSE). Copyright 2021 Adguard Software Ltd.
- [AdAway default blocklist](https://github.com/AdAway/adaway.github.io) par Kicelo, Dominik Schuermann et contributeurs, sous licence [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/deed.fr).

Détails, textes des licences MIT et sources écartées : [tools/blocklists/README.md](tools/blocklists/README.md).

## Licence

[MIT](LICENSE) © 2026 Iheb
