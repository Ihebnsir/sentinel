# Journal des modifications

Toutes les modifications notables de Sentinel sont notées ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le projet utilise le [versionnage sémantique](https://semver.org/lang/fr/).

## [Non publié]

## [1.0.1] - 2026-11-18

L'APK 1.0.0 téléchargé depuis GitHub était bloqué par Google Play Protect (« Appli bloquée pour protéger votre appareil », sans bouton pour passer outre). La 1.0.1 corrige ce blocage.

### Modifié
- Deux variantes Android, même code et même clé de signature : **standard** (APK GitHub, `com.iheb.sentinel.standard`) et **complete** (future version Google Play, `com.iheb.sentinel`). Voir [docs/RELEASE.md](docs/RELEASE.md).
- Variante standard : sans le lecteur de notifications de la protection automatique, ni permission SMS ou d'accessibilité, que la protection renforcée contre la fraude de Play Protect bloque hors du Play Store. Dans l'onglet Messages, une courte explication (fr/ar/en) remplace l'interrupteur ; l'analyse par partage, sélection de texte ou copier-coller ne change pas.
- APK publié sous le nom `sentinel-<version>-<variante>.apk` ; `tools/release/build_release.ps1` prend `-Flavor` (standard par défaut).
- Build release : `--extra-gen-snapshot-options=--strip`. `libapp.so` ne contient plus d'informations DWARF avec les noms Dart en clair (avertissement « unobfuscated DWARF ») ; les symboles restent dans `build/symbols`.

### Ajouté
- Vérification Gradle `checkPlayProtectStandard*` : le build standard échoue si son manifeste fusionné déclare un lecteur de notifications, un service d'accessibilité ou une permission SMS.

### Note
- La 1.0.1 standard ne remplace pas la 1.0.0 (autre nom de paquet) : exporter une sauvegarde du coffre si besoin, puis désinstaller la 1.0.0.

## [1.0.0] - 2026-11-16

Première version publique. L'app tourne entièrement sur le téléphone, sans compte ni statistiques d'usage.

### Ajouté

#### Audit du téléphone et des applications
- Score de sécurité sur 100 à partir de 7 vérifications (verrouillage de l'écran, root, âge du correctif de sécurité, biométrie forte, options pour les développeurs, débogage USB, chiffrement), chacune avec un lien vers le bon écran des Réglages.
- Analyse des applications installées : score de risque de 0 à 100 avec des règles expliquées (service d'accessibilité, source d'installation, administrateur de l'appareil, SMS, notifications, superposition, micro, localisation en arrière-plan, `targetSdk` ancien…).
- Applications falsifiées : lecture du certificat de signature, imitation du nom d'une app connue, mods de WhatsApp, signatures de test, icône cachée.
- Logiciels espions (stalkerware) : liste publique Stalkerware Indicators d'Echap (CC BY 4.0), même déguisés en app système ; conseils de sécurité affichés **avant** toute désinstallation.
- « Accès sensibles » : quelles apps ont utilisé la caméra, le micro ou la localisation, la nuit ou en arrière-plan.

#### Messages et arnaques
- Détection des arnaques sur le téléphone : modèle (n-grammes de caractères + régression logistique) combiné à des règles sur les liens (imitation de marques, adresse IP, punycode, raccourcisseurs, extensions suspectes…), avec les raisons du verdict.
- Vérification par copier-coller, partage depuis une autre app ou sélection de texte (« Vérifier avec Sentinel »).
- Protection automatique (facultative) : lecture des notifications des SMS, WhatsApp, Messenger, Telegram et Viber, et alerte « arnaque probable » au texte neutre sur l'écran verrouillé.
- Scanner de QR codes anti-hameçonnage (quishing) : rien ne s'ouvre sans confirmation, liens `javascript:`/`intent:` et codes USSD bloqués.
- Signalement volontaire d'un message, un par un : texte anonymisé sur le téléphone, affiché et modifiable avant l'envoi, en HTTPS seulement, 5 par heure au maximum.
- Serveur de signalement (dossier `backend/`) : API FastAPI, anonymisation identique à celle de l'app, limite de débit, journaux sans adresse IP, PostgreSQL avec TLS vérifié, rôles à moindre privilège, déploiement sur Render.
- Outil de réentraînement du modèle (`ml/retrain.py`) avec une porte de qualité : un modèle moins bon n'est jamais exporté.

#### Réseau
- Contrôle du Wi-Fi : type de chiffrement, portail captif, DNS privé, sans la permission de localisation.
- Pare-feu DNS local (VpnService) : environ 582 000 domaines bloqués (logiciels malveillants, traqueurs, publicité), analyse par app, détection des imitations de marques.
- Requêtes DNS autorisées envoyées chiffrées à Quad9 (DNS over TLS, repli DNS over HTTPS) ; DNS en clair seulement avec l'accord explicite de l'utilisateur.
- Mises à jour des listes de blocage, désactivées par défaut, vérifiées avant d'être utilisées.
- Tuile « Pare-feu Sentinel » dans les Paramètres rapides.

#### Coffre-fort et mots de passe
- Coffre chiffré (Argon2id + AES-256-GCM) pour les mots de passe et les notes, déverrouillé par mot de passe maître, clé de récupération ou empreinte (Keystore Android).
- Documents chiffrés dans le coffre : photo (appareil photo), image ou PDF.
- Sauvegarde chiffrée (fichier `.sentinel`) pour changer de téléphone, export et import.
- Santé des mots de passe : fuites (Have I Been Pwned, k-anonymat), mots de passe réutilisés ou faibles ; générateur de mots de passe.
- Protection à l'écran : pas de capture sur le coffre, verrouillage automatique, presse-papiers effacé après 30 s.

#### Application
- Bilan de la semaine : compteurs gardés sur le téléphone, écran dédié et notification facultative.
- Présentation au premier lancement, écran Réglages / À propos.
- Interface en français, arabe (de droite à gauche) et anglais.
- Thème sombre « nuit » et choix Clair / Sombre / Système.
- Accessibilité : TalkBack, zones tactiles de 48 dp, contraste AA, police à 200 %.
- Icône et écran de démarrage Sentinel.

### Sécurité
- Audit OWASP MASVS v2 (analyse statique et dynamique, 18 constats) : 15 corrigés et vérifiés, 3 acceptés et documentés. Voir [docs/audit/RAPPORT_AUDIT.md](docs/audit/RAPPORT_AUDIT.md).
- APK release signé avec une clé de publication gardée hors du dépôt (SEN-01) et obfusqué (SEN-04). Empreinte du certificat dans le README (« Vérifier un APK »).
- Sauvegarde Android désactivée pour les données de l'app.
- CI : tests, couverture minimale de 85 %, Gitleaks, Dependabot, et pour le serveur : pytest, ruff, bandit, pip-audit et image Docker non-root.

[Non publié]: https://github.com/Ihebnsir/sentinel/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/Ihebnsir/sentinel/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Ihebnsir/sentinel/releases/tag/v1.0.0
