# Rapport d'audit de sécurité — Sentinel

| | |
|---|---|
| Application | Sentinel 1.0.0 (`com.iheb.sentinel`), Flutter / Android |
| Période | 21 au 24 octobre 2026 |
| Référentiel | OWASP MASVS v2, méthodologie MASTG |
| Auditeur | audit mené pour le propriétaire de l'application, sur son propre code |
| Rapports détaillés | [P1 statique](P1_statique.md) · [P2 dynamique](P2_dynamique.md) · [P3a corrections](P3a_corrections.md) · [P3b corrections](P3b_corrections.md) |

## 1. Résumé (non technique)

Sentinel protège le téléphone de son utilisateur : coffre de mots de passe, détection des SMS d'arnaque, analyse des applications, pare-feu DNS. L'audit a cherché si l'application elle-même pouvait **trahir** cet utilisateur : fuite de mots de passe, envoi de données à son insu, porte d'entrée pour une autre app, ou protection qui ne protège pas.

**Ce qui était déjà solide.** Le coffre est réellement chiffré (Argon2id et AES-GCM). Aucun mot de passe n'apparaît en clair, ni dans les fichiers ni dans les journaux. L'écran du coffre est noir dans les captures et dans les apps récentes. Le coffre se verrouille quand l'écran s'éteint, et la vérification des fuites n'envoie que 5 caractères d'une empreinte.

**Ce qui a été trouvé : 17 constats**, dont un de sévérité élevée et quatre moyens :
- les versions publiables étaient signées avec une clé de test (élevée) ;
- au premier lancement, l'app contactait Google pour télécharger une police, sans accord ;
- avec le pare-feu, les noms des sites visités partaient en clair sur le réseau ;
- avec un « DNS privé » réglé en mode strict, activer le pare-feu coupait tous les sites ;
- sur Android 9 et avant, un mot de passe copié depuis le coffre était lisible par toutes les apps.

S'y ajoutent des points plus faibles : un message piégé par des caractères invisibles trompait l'analyse, une autre app pouvait faire afficher « Rien de suspect », les rapports d'analyse restaient en clair sur le disque, etc.

**Où on en est.**
- **14 constats sont corrigés**, chacun avec un test automatique, et revérifiés sur un téléphone de test (émulateur rooté) quand c'était pertinent.
- **3 sont acceptés en connaissance de cause** : le modèle anti-arnaque est lisible (l'app est open source), pas d'épinglage de certificat, et le constat SEN-09, qui était déjà conforme.
- **Une seule action reste à faire, par le propriétaire lui-même** : créer la clé de publication (la procédure est prête) et vérifier la signature de la première version.

Le pare-feu chiffre désormais toutes ses requêtes, et l'app ne contacte plus rien sans accord.

**Ce qu'il reste à savoir.** Aucune application n'est sûre à 100 %. Les principaux risques restants (section 6) dépendent surtout du téléphone : un Android trop ancien ou un logiciel espion à qui l'on a donné l'accessibilité ou le root.

## 2. Périmètre

- **Inclus** : l'APK Android release (ce que reçoit un utilisateur), son code Dart et Kotlin, ses assets (modèle d'IA, listes de blocage), ses dépendances, son trafic réseau, son stockage, ses composants Android exposés, et l'interface du coffre.
- **Exclus** : iOS, Windows et le web (non distribués) ; les serveurs tiers (Have I Been Pwned, Quad9, GitHub) ; la chaîne d'outils Flutter elle-même ; un test d'intrusion sur un appareil physique.

## 3. Méthodologie

Trois phases, selon OWASP MASVS v2 / MASTG :

1. **Analyse statique (P1)** : décompilation de l'APK release, lecture du manifeste et des composants exportés, recherche de secrets, de journaux et de code de debug, dépendances comparées aux bases de vulnérabilités, analyse automatique MobSF puis tri manuel de ses alertes (10 faux positifs écartés).
2. **Analyse dynamique (P2)** : APK release sur un émulateur rooté. Capture réseau dès le premier lancement, chaque connexion étant attribuée à l'app par son UID ; interception HTTPS de la vérification HIBP ; journaux pendant un scénario complet ; attaques des composants exportés depuis une app ordinaire ; inspection du stockage en root ; protections d'écran.
3. **Corrections (P3a, P3b)** : pour chaque constat, une correction, un test automatique (Dart ou JUnit) et un nouveau test sur l'émulateur quand c'est pertinent. Aucun constat n'est déclaré corrigé sans preuve.

**Outils et versions** (téléchargements vérifiés par somme de contrôle ou empreinte d'image) :

| Outil | Version | Usage |
|---|---|---|
| Flutter / Dart | 3.47.7 / 3.13.5 | build, tests, analyse |
| MobSF (Docker) | 4.5.3, digest `sha256:5113fbad…` | analyse statique automatique |
| jadx / apktool | 1.5.6 / 3.0.3 (SHA-256 vérifiés) | décompilation, manifeste |
| apksigner | build-tools 36.0.0 | signature |
| OSV.dev | API `querybatch` | vulnérabilités connues (Pub, Maven) |
| Android Emulator | 37.2.12 | environnement dynamique |
| Image système | Android 17 Google APIs x86_64 r08 (SHA-1 vérifié) | émulateur rooté |
| tcpdump / iptables | ceux de l'image `userdebug` | capture et attribution par UID |
| TShark | 4.6.3 | analyse des captures |
| mitmproxy (Docker) | 12.2.3, digest `sha256:00b77b5d…` | interception HTTPS (HIBP) |
| Gitleaks | 8.30.1 (SHA-256 vérifié) | secrets dans l'historique Git |
| Python / scikit-learn | 3.14.8 / 1.9.1 | réentraînement et parité du modèle |

## 4. Environnement

- Poste Windows 11 ; Docker Desktop 29.8.1 pour MobSF et mitmproxy (ports liés à `127.0.0.1` seulement, conteneurs supprimés après usage).
- Émulateur `Sentinel_Audit_Root` créé pour l'audit : Android 17 (API 37), Google APIs **sans** Play Store, build `userdebug` (`adb root`). Le Pixel 8 de développement n'a pas été modifié. L'émulateur est conservé, éteint.
- Outils, captures, journaux et copies du stockage dans `.audit_work/` (exclu de Git, jamais publié).

## 5. Constats

Sévérité selon l'impact pour l'utilisateur et la facilité d'exploitation (définitions dans [P1](P1_statique.md)).

| ID | Constat | MASVS | Sévérité | Statut final | Preuve |
|---|---|---|---|---|---|
| SEN-01 | APK release signé avec la clé de debug | RESILIENCE-2 | **Élevée** | **Corrigé**, vérification `apksigner` à faire avec la clé | [P3b](P3b_corrections.md#sen-01--signature), [RELEASE](../RELEASE.md) |
| SEN-02 | Police téléchargée chez Google au lancement, sans accord | PRIVACY-1/3 | Moyenne | **Corrigé** | [P3a](P3a_corrections.md#sen-02--police-téléchargée-chez-google--corrigé) |
| SEN-03 | Presse-papiers lisible par toutes les apps (Android ≤ 9) | CODE-1 | Moyenne | **Corrigé** | [P3a](P3a_corrections.md#sen-03--presse-papiers-lisible-par-toutes-les-apps-android--9--corrigé) |
| SEN-04 | Code Dart non obfusqué | RESILIENCE-3 | Faible | **Corrigé** | [P3b](P3b_corrections.md#sen-04--obfuscation) |
| SEN-05 | `debugPrint` conservés en release | STORAGE-2 | Faible | **Corrigé** | [P3a](P3a_corrections.md#sen-05--logs-en-release--corrigé) |
| SEN-06 | Action interne `CHECK_ALERT` accessible aux autres apps | PLATFORM-1 | Faible | **Corrigé** | [P3a](P3a_corrections.md#sen-06--action-interne-check_alert-accessible-aux-autres-apps--corrigé) |
| SEN-07 | Modèle anti-arnaque lisible en clair | RESILIENCE-3 | Info | **Accepté** | [P3a](P3a_corrections.md#sen-07--modèle-anti-arnaque-lisible--accepté) |
| SEN-08 | Bibliothèques AndroidX / coroutines anciennes | CODE-3 | Info | **Corrigé** | [P3b](P3b_corrections.md#sen-08--dépendances) |
| SEN-09 | Code de debug oublié | CODE-4 | Info | **Accepté** (conforme, rien à corriger) | [P1](P1_statique.md#sen-09--code-de-debug-oublié) |
| SEN-10 | DNS envoyé en clair à Quad9, sans information | NETWORK-1, PRIVACY-3 | Moyenne | **Corrigé** | [P3b](P3b_corrections.md#sen-10--dns-amont-chiffré) |
| SEN-11 | Pare-feu + DNS privé strict : plus aucun site | NETWORK-1 | Moyenne | **Corrigé** | [P3b](P3b_corrections.md#sen-11--dns-privé-strict) |
| SEN-12 | Analyse contournée par des caractères d'inversion / invisibles | CODE-4 | Faible | **Corrigé** | [P3a](P3a_corrections.md#sen-12--caractères-invisibles-et-inversion-de-texte--corrigé) |
| SEN-13 | Clé de récupération lisible par l'accessibilité | PLATFORM-3 | Faible | **Corrigé** (Android 14+) | [P3a](P3a_corrections.md#sen-13--clé-de-récupération-lisible-par-laccessibilité--corrigé-android-14) |
| SEN-14 | Rapports d'analyse en clair, suppression en retard | STORAGE-1 | Info | **Corrigé** | [P3a](P3a_corrections.md#sen-14--rapports-danalyse-en-clair-suppression-en-retard--corrigé) |
| SEN-15 | Pas d'épinglage de certificat | NETWORK-2 | Info | **Accepté** | [P3a](P3a_corrections.md#sen-15--pas-dépinglage-de-certificat--accepté) |
| SEN-16 | Prénom du développeur écrit en dur | hors MASVS | Info | **Corrigé** | [P3a](P3a_corrections.md#sen-16---bonjour-iheb---corrigé) |
| SEN-17 | Bandeau Wi-Fi qui cache des boutons | hors MASVS | Info | **Corrigé** | [P3a](P3a_corrections.md#sen-17--bandeau-wi-fi-qui-cache-des-boutons--corrigé) |

Bilan : **13 corrigés et vérifiés, 1 corrigé en attente de la vérification finale (SEN-01), 3 acceptés, 0 restant** (17 constats). Pendant les corrections, 10 faux positifs de MobSF ont été écartés (P1, §5), et 20 faux positifs de Gitleaks issus du rapport MobSF ont été documentés (P3a, §3).

**Indicateurs finaux** : `flutter analyze` sans problème ; **436** tests Flutter et **125** tests JUnit réussis ; **0** vulnérabilité connue dans les 70 paquets Pub et les 67 composants Android (OSV.dev, 24/10/2026) ; **0** requête DNS en clair vers Quad9 sans accord de l'utilisateur (capture réseau).

## 6. Risques résiduels

| Risque | Pourquoi il reste | Atténuation |
|---|---|---|
| Android 7 à 9 sans correctifs de sécurité | `minSdk` 24 gardé pour ne pas exclure d'utilisateurs | avertissement avant copie et effacement en 10 s (SEN-03) ; le score de l'accueil signale un correctif ancien |
| Logiciel espion avec accessibilité, avant Android 14 | aucune API pour cacher une vue sans exclure les lecteurs d'écran | choix assumé : TalkBack doit fonctionner partout ; l'analyse des apps signale les logiciels espions connus |
| Téléphone rooté ou extraction judiciaire | root permet de lire la mémoire d'un processus | coffre chiffré par mot de passe, rapports chiffrés (Keystore), aucun secret en clair sur le disque |
| Quad9 voit les requêtes | c'est le résolveur choisi | chiffré sur le réseau ; politique de confidentialité de Quad9 ; listes appliquées sur le téléphone |
| DNS-over-HTTPS indisponible avant Android 10 | ALPN `h2` requis par Quad9 | DNS-over-TLS reste disponible ; jamais de clair sans accord |
| Applications avec leur propre DNS chiffré | elles contournent le DNS du système | documenté (SECURITY_DESIGN, limite 23) |
| Rapport expiré sur le disque jusqu'à environ 1 h (Android 14+) | alarme exacte refusée par défaut | fichier chiffré, jamais relu ni affiché après 24 h |
| Contournement du modèle anti-arnaque | modèle public, détection statistique | règles indépendantes (liens, marques imitées, caractères cachés) |
| Perte de la clé de publication | dépend du propriétaire | procédure de sauvegarde et Play App Signing ([RELEASE](../RELEASE.md)) |

## 7. Recommandations

**Avant de publier**
1. Créer la clé de publication et la sauvegarder hors ligne ([RELEASE §1](../RELEASE.md)), construire avec `tools/release/build_release.ps1`, vérifier avec `apksigner` ([§4](../RELEASE.md)), puis publier l'empreinte SHA-256 du certificat.
2. Avec Google Play : activer Play App Signing et déclarer l'usage de `QUERY_ALL_PACKAGES`.

**Dans la CI**
3. Garder le scan Gitleaks bloquant (il est de nouveau propre) et ajouter `osv-scanner` sur `pubspec.lock` et sur le classpath Gradle.
4. Ajouter `test/no_release_logs_test.dart`, `ManifestTest` et `KotlinLogsTest` à la liste des tests obligatoires : ils empêchent le retour de SEN-05 et SEN-06.

**À moyen terme**
5. Envisager `minSdk` 29 (Android 10) quand la part d'Android 9 et antérieurs sera négligeable : presse-papiers privé et DoH disponibles partout.
6. Signer `manifest.json` des listes de blocage avec une clé de l'auteur (protection même contre une autorité de certification compromise, sans épinglage).
7. Réentraîner le modèle anti-arnaque avec de vrais messages, régulièrement (`ml/`).
8. Compléter les tests impossibles dans cet environnement : appareil Android 9 réel (SEN-03), et service d'accessibilité non reconnu comme outil (SEN-13, drapeau `FLAG_NOT_ACCESSIBILITY_TOOL`).
9. Refaire un audit statique et dynamique (P1 + P2) à chaque version majeure, ou après tout changement du pare-feu, du coffre ou des permissions.
