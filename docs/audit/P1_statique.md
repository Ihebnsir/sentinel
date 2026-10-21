# Audit P1 : analyse statique de l'APK release

| | |
|---|---|
| Application | Sentinel 1.0.0 (versionCode 1), `com.iheb.sentinel` |
| Cible | `build/app/outputs/flutter-apk/app-release.apk`, 57,2 Mo, SHA-256 `e717b6b8c9e36f417254bfa216a92151addabe6e1a282bcb5197797f2600ea53` |
| Commit audité | `b46ce0f` (arbre propre) |
| Date | 21-22/10/2026 |
| Référentiels | OWASP MASVS v2, méthodologie MASTG (tests statiques) |
| Périmètre | APK release tel que reçu par un utilisateur. Rien n'a été corrigé : ce document constate. |

## 1. Résumé

L'APK est **bien construit côté plateforme** : pas de `debuggable`, sauvegarde désactivée, trafic en clair interdit, tous les composants exportés sont protégés par une permission système, aucune dépendance vulnérable connue, aucun secret en dur, aucun traqueur.

Les vrais problèmes sont ailleurs :

| ID | Titre | MASVS | Sévérité |
|---|---|---|---|
| SEN-01 | APK release signé avec la clé de debug | MASVS-RESILIENCE-2 | **Élevée** |
| SEN-02 | Police téléchargée chez Google au lancement, sans accord (contredit le README) | MASVS-PRIVACY-1 / PRIVACY-3 | **Moyenne** |
| SEN-03 | Installable sur Android 7.0 (minSdk 24) : presse-papiers lisible par toutes les apps | MASVS-CODE-1 | **Moyenne** |
| SEN-04 | Code Dart non obfusqué : noms de classes et de méthodes lisibles | MASVS-RESILIENCE-3 | Faible |
| SEN-05 | `debugPrint` conservés en release (logcat), dont des noms de packages | MASVS-STORAGE-2 | Faible |
| SEN-06 | Action interne `CHECK_ALERT` accessible aux autres apps | MASVS-PLATFORM-1 | Faible |
| SEN-07 | Modèle anti-arnaque lisible en clair : aide à le contourner | MASVS-RESILIENCE-3 | Info |
| SEN-08 | Bibliothèques AndroidX / coroutines anciennes (sans CVE connue) | MASVS-CODE-3 | Info |
| SEN-09 | `assert` / code de debug : rien d'oublié dans le binaire | MASVS-CODE-4 | Info (conforme) |

Score MobSF : **53/100** (2 « high », 7 « warning »). Après tri manuel : 1 seul « high » est réel (SEN-01), l'autre est reclassé en Moyenne (SEN-03), et **10 alertes sont des faux positifs** (section 5).

## 2. Méthode et outils

Tous les outils sont dans `.audit_work/`, exclu de git par `.git/info/exclude` (aucun fichier suivi n'a été modifié).

| Outil | Version | Intégrité vérifiée |
|---|---|---|
| Flutter | 3.47.7 (Dart 3.13.5, moteur `deb287481e`) | — |
| MobSF (Docker) | `opensecurity/mobile-security-framework-mobsf:v4.5.3`, publiée le 21/09/2026 (30 jours avant l'audit, donc plus de 2 semaines) | lancée par digest `sha256:5113fbad0727445dda01afdccafea5e107bfa8632ead8a169492f5caa8aa1b7c` |
| jadx | 1.5.6 (10/07/2026) | SHA-256 `545ea2be…a230e8974`, identique à celui publié par GitHub |
| apktool | 3.0.3 (20/07/2026) | SHA-256 `dbf930b0…1b5f9423`, identique à celui publié par GitHub |
| apksigner | build-tools 36.0.0 | — |
| OSV.dev | API `querybatch` | 70 packages Pub + 49 artefacts Maven |

Étapes :

1. `flutter build apk --release` (sans option ajoutée, comme le ferait le développeur).
2. MobSF en conteneur, port lié à `127.0.0.1` seulement. Clé d'API lue dans les logs de démarrage (`REST API Key`). Appels `api/v1/upload`, `scan`, `report_json`, `download_pdf`, `scorecard`. Analyse : 85 s. Conteneur arrêté et supprimé ensuite (`--rm`).
3. `apktool d` (manifest et ressources décodés), `jadx` (Java décompilé), `strings` sur `libapp.so` (code Dart compilé), table R8 `build/app/outputs/mapping/release/mapping.txt`.
4. `./gradlew :app:dependencies --configuration releaseRuntimeClasspath` et `pubspec.lock`, interrogés sur OSV.dev.

Rapports MobSF dans `docs/audit/mobsf/` :

| Fichier | SHA-256 |
|---|---|
| `mobsf_report.json` | `2367a950fdba8d1cd6250afcf71163d4decd420762fcdf327a13828e02b65f39` |
| `mobsf_report.pdf` | `081e1770e65c9eec30f633e0219be870cf011d1bb49010c225111855d72e89ff` |
| `mobsf_scorecard.json` | `40c451022877461498cabdaba41e3dbb9a34f01f3cb50e2eaef71318be96efb5` |

> Les « captures » MobSF ci-dessous sont des extraits du rapport JSON (les mêmes alertes figurent dans le PDF, sections *Certificate analysis*, *Manifest analysis* et *Code analysis*).

## 3. Build release : signature, obfuscation, minification

| Point | Constat | Preuve |
|---|---|---|
| Signature | **Clé de debug** (`CN=Android Debug`) → SEN-01 | `apksigner verify --print-certs` ; `android/app/build.gradle.kts` : `signingConfig = signingConfigs.getByName("debug")` |
| Schémas de signature | v2 seul (v1 absent). Suffisant : minSdk 24 = Android 7.0, qui lit v2 | `Verified using v2 scheme: true` |
| `--obfuscate` / `--split-debug-info` | **Absents** → noms Dart lisibles (SEN-04) | commande de build ; `strings libapp.so` |
| R8 (Kotlin/Java) | **Actif** (défaut Flutter en release) : classes renommées (`InstalledAppsScanner → vb`), code mort retiré | `mapping.txt` (42 845 lignes) ; APKiD : `compiler: r8` |
| Réduction des ressources | **Active** : `res/AE.png`, `res/3o.png`… | listing de l'APK |
| Binaires natifs | NX, PIE, stack canary, fonctions fortifiées, symboles retirés | MobSF *binary_analysis* |
| `debuggable` | Absent du manifest final (donc `false`) | manifest décodé |

## 4. Constats

### SEN-01 · APK release signé avec la clé de debug

- **MASVS** : MASVS-RESILIENCE-2 (MASTG-TEST-0038, signature correcte de l'app)
- **Sévérité : Élevée.** Ce n'est pas exploitable à distance aujourd'hui, mais c'est bloquant pour toute diffusion et presque impossible à corriger après coup : Android n'accepte une mise à jour que si elle est signée par la même clé. Si cet APK est distribué, toutes les versions futures restent liées à une clé non protégée.
- **Preuve**

  ```
  $ apksigner verify --print-certs app-release.apk
  Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
  Signer #1 certificate SHA-256 digest: c87e20d9c7b4950a046217f028739d630d38a11d76bbbbb725cd7b2b682ef6d9
  ```

  Même empreinte que `~/.android/debug.keystore` (`C8:7E:20:D9:…:F6:D9`), dont le mot de passe est public (`android`).

  `android/app/build.gradle.kts` :
  ```kotlin
  release {
      // TODO: Add your own signing config for the release build.
      signingConfig = signingConfigs.getByName("debug")
  }
  ```

  MobSF : `HIGH | certificate | Application signed with debug certificate`.
- **Impact pour l'utilisateur**
  - La clé est un simple fichier sur le PC du développeur, sans vrai mot de passe. Quiconque le copie (malware sur le PC, sauvegarde volée) peut publier une « mise à jour » de Sentinel qu'Android installera par-dessus la vraie, avec toutes ses autorisations (lecture des notifications, VPN, liste des apps).
  - Google Play refuse les APK signés en debug.
  - Ironie : le scanner de Sentinel signale lui-même les apps signées « Android Debug » comme suspectes (`InstalledAppsScanner.isTestKey()`). Il s'exclut de son analyse, mais un autre outil de sécurité classerait Sentinel comme douteux.
- **Recommandation** : créer une clé de publication dédiée (`keytool -genkeypair`, RSA 4096 ou EC P-256), la garder hors du dépôt (déjà prévu par `android/.gitignore` : `key.properties`, `*.jks`), la charger via `key.properties` dans `signingConfigs.release`, et en faire une sauvegarde chiffrée hors ligne. Pour Google Play, activer Play App Signing.

### SEN-02 · Police téléchargée chez Google au lancement, sans accord

- **MASVS** : MASVS-PRIVACY-1 (minimiser les données) et MASVS-PRIVACY-3 (transparence)
- **Sévérité : Moyenne.** Pas de fuite de contenu, mais une connexion réseau vers un tiers à chaque première ouverture, avant tout consentement, alors que la documentation promet le contraire. Pour une app de confidentialité, la promesse fait partie de la sécurité.
- **Preuve**
  - `lib/theme/app_theme.dart:19` : `textTheme: GoogleFonts.readexProTextTheme()`.
  - `google_fonts` 9.0.0 : `bool allowRuntimeFetching = true;` (`google_fonts_config.dart:13`) et `String get url => 'https://fonts.gstatic.com/s/a/$expectedFileHash.ttf'`.
  - Aucune police Readex Pro dans l'APK : `assets/flutter_assets/fonts/` ne contient que `MaterialIcons-Regular.otf` (`FontManifest.json` le confirme).
  - Chaîne présente dans le binaire : `https://fonts.gstatic.com/s/a/` (`strings libapp.so`) ; MobSF la liste dans *domains*.
  - `README.md:22` : « *The only network call is an optional, opt-in breach check* ». Le commentaire du manifest dit aussi « Internet, toujours après accord ».
- **Impact pour l'utilisateur** : Google reçoit l'adresse IP, l'heure et l'empreinte du fichier demandé (qui identifie l'app Sentinel) à la première ouverture, puis à chaque fois que le cache est vidé. Sans réseau, l'app retombe sur la police système : pas de panne. Point positif : le fichier téléchargé est vérifié par son SHA-256 (pas d'injection possible).
- **Recommandation** : embarquer les fichiers Readex Pro dans `assets/` (licence OFL) et mettre `GoogleFonts.config.allowRuntimeFetching = false` dans `main()`, ou déclarer la police dans `pubspec.yaml` et retirer `google_fonts`. Mettre à jour le README (il oublie aussi le pare-feu DNS vers Quad9 et la mise à jour des listes). À confirmer en dynamique (P2) par une capture réseau au premier lancement.

### SEN-03 · Installable sur Android 7.0 (minSdk 24)

- **MASVS** : MASVS-CODE-1 (l'app exige une plateforme à jour)
- **Sévérité : Moyenne** (MobSF : « high », reclassé). Le risque vient du système, pas du code de Sentinel, mais il touche directement le coffre de mots de passe.
- **Preuve** : `apktool.yml` → `minSdkVersion: 24`. MobSF : `HIGH | manifest | App can be installed on a vulnerable unpatched Android version 7.0, [minSdk=24]`.
- **Impact pour l'utilisateur**
  - Android 7 à 9 ne reçoivent plus de correctifs de sécurité.
  - Avant Android 10, **n'importe quelle app en arrière-plan peut lire le presse-papiers**. Quand l'utilisateur copie un mot de passe du coffre, il reste lisible 30 s (`vault_platform.dart:63`) par toutes les apps. Le marquage « sensible » (`EXTRA_IS_SENSITIVE`) n'existe qu'à partir d'Android 13.
  - Avant Android 11, la clé biométrique ne peut pas exiger « biométrie forte uniquement » de la même façon (`VaultBiometric.kt`, branche `setUserAuthenticationValidityDurationSeconds(-1)`).
- **Recommandation** : passer à `minSdk = 29` (Android 10) au minimum, ou garder 24 et, sous Android 10, désactiver le bouton « Copier » du coffre (ou afficher un avertissement clair). L'audit de l'appareil lit déjà `SECURITY_PATCH` : il peut signaler un Android hors support.

### SEN-04 · Code Dart non obfusqué

- **MASVS** : MASVS-RESILIENCE-3 (rendre l'analyse statique plus difficile)
- **Sévérité : Faible.** Sentinel est open source (MIT, dépôt GitHub public) : un attaquant a déjà le code. L'obfuscation n'apporterait presque rien ici, mais elle reste une bonne pratique pour une app de sécurité.
- **Preuve** : `strings lib/arm64-v8a/libapp.so` révèle 71 chemins `package:sentinel/...` et les noms internes :
  ```
  package:sentinel/services/vault/vault_crypto.dart
  package:sentinel/services/vault/vault_biometrics.dart
  VaultSession  PwnedPasswordsClient  PhishingModel  FirewallService
  deriveKey  unlockWithBiometrics  breachCount  splitHash  sha1Hex
  _ChangePasswordScreenState@193277749  _copyPassword@662486438
  ```
  Côté Kotlin, R8 a renommé les classes (`com.iheb.sentinel.InstalledAppsScanner -> vb`) ; seules celles déclarées dans le manifest gardent leur nom (obligatoire).
- **Impact pour l'utilisateur** : un attaquant qui veut modifier l'app (version piégée repackagée) trouve en quelques minutes les fonctions du coffre à détourner. Cela ne change rien à la solidité du chiffrement.
- **Recommandation** : `flutter build apk --release --obfuscate --split-debug-info=build/symbols`, et conserver `build/symbols` (hors git, déjà couvert par `app.*.symbols`) pour lire les plantages.

### SEN-05 · `debugPrint` conservés en release

- **MASVS** : MASVS-STORAGE-2 (pas de fuite de données sensibles, ici dans les logs)
- **Sévérité : Faible.** Les logs Android ne sont plus lisibles par les autres apps depuis Android 4.1 ; il faut un accès ADB, un rapport de bug ou un outil de diagnostic du fabricant.
- **Preuve** : `debugPrint` n'est **pas** supprimé en release (seuls les appels sous `if (kDebugMode)` le sont : « Argon2id : … ms » et « Coffre : écriture reportée » sont bien absents du binaire). 12 appels non conditionnels restent, par exemple :
  ```dart
  // lib/services/apps_scanner_service.dart:52
  debugPrint('Action « $method » impossible : ${e.message}');
  // lib/services/firewall_service.dart:371
  debugPrint('Pare-feu : $method a échoué (${e.message})');
  ```
  Chaînes retrouvées dans `libapp.so` : `Pare-feu : mise `, `Indicateurs de stalkerware illisibles : `. Si l'écran de désinstallation est introuvable (rare, ROM modifiée), le message `e.message` de l'`ActivityNotFoundException` contient l'Intent complet, donc **le nom du package** (`dat=package:com.xxx`) de l'app que l'utilisateur voulait désinstaller.
- **Impact pour l'utilisateur** : cas réaliste et grave pour la personne concernée : un conjoint violent avec un accès ADB au téléphone pourrait voir dans les logs que la victime a tenté de désinstaller le stalkerware. Aucun mot de passe ni texte de message n'est journalisé (vérifié).
- **Recommandation** : envelopper ces appels dans `if (kDebugMode)` (ou une petite fonction `logDebug`) et ne jamais journaliser `e.message` d'une exception d'Intent.

### SEN-06 · Action interne `CHECK_ALERT` accessible aux autres apps

- **MASVS** : MASVS-PLATFORM-1 (les mécanismes IPC sont utilisés de façon sûre)
- **Sévérité : Faible.** Pas de fichier, pas d'URI, pas de commande : seulement du texte, limité à 5 000 caractères (`MessageTexts.kt`). Le même effet est déjà possible par le bouton « Partager ».
- **Preuve** : `MainActivity` est exportée (obligatoire pour le lanceur, `SEND` et `PROCESS_TEXT`). Elle traite aussi `com.iheb.sentinel.action.CHECK_ALERT`, prévue pour les notifications de Sentinel, mais aucune vérification de l'appelant n'est faite :
  ```kotlin
  Intent.ACTION_SEND, ACTION_CHECK_ALERT -> intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
  ```
  Une autre app peut envoyer un Intent explicite `component=com.iheb.sentinel/.MainActivity`, `action=CHECK_ALERT`.
- **Impact pour l'utilisateur** : une app malveillante peut ouvrir Sentinel sur l'onglet Messages avec un texte de son choix. Combiné à SEN-07 (texte construit pour passer sous le seuil), elle afficherait « rien de suspect » sur un message d'arnaque, dans l'interface de confiance de Sentinel. Aujourd'hui, Dart ne sait pas d'où vient le texte, donc rien n'est affiché comme « alerte de Sentinel » : l'impact reste limité.
- **Recommandation** : faire pointer la notification vers une activité (ou un `activity-alias`) **non exportée**, ou accepter `CHECK_ALERT` seulement avec un jeton aléatoire stocké en mémoire. Ne jamais présenter un texte reçu par Intent comme une alerte de Sentinel. Test dynamique en P2 avec `adb shell am start`.

### SEN-07 · Modèle anti-arnaque lisible en clair

- **MASVS** : MASVS-RESILIENCE-3 (et choix de conception)
- **Sévérité : Info.** C'est le prix normal d'une détection 100 % sur l'appareil, et le modèle est de toute façon public sur GitHub.
- **Preuve** : `assets/flutter_assets/assets/models/phishing_model.json` (404 Ko) contient le vocabulaire (8 000 n-grammes), les poids `coef`, l'`intercept` et le seuil `0.5` d'une régression logistique TF-IDF.
- **Impact pour l'utilisateur** : un escroc peut calculer hors ligne quels mots font baisser le score et écrire des SMS qui passent sous le seuil.
- **Recommandation** : rien à cacher, mais à documenter dans `SECURITY_DESIGN.md` (limites). Garder des règles indépendantes du modèle (liens raccourcis, marques imitées, déjà présentes) et réentraîner régulièrement.

Les autres assets ne révèlent rien de sensible : listes de blocage publiques avec licences (`LICENSES.txt`), IOC stalkerware (CC BY 4.0), marques connues. **Aucune fixture de test ni donnée personnelle** : `assets/branding/`, `ml/`, `test/` et `tools/` ne sont pas embarqués.

### SEN-08 · Bibliothèques AndroidX / coroutines anciennes

- **MASVS** : MASVS-CODE-3 (composants sans vulnérabilité connue)
- **Sévérité : Info.**
- **Preuve** : OSV.dev ne connaît **aucune vulnérabilité** pour les 70 packages Pub (`pubspec.lock`) ni pour les 49 artefacts Maven du `releaseRuntimeClasspath`. Plusieurs sont toutefois anciens, tirés par le moteur Flutter : `kotlinx-coroutines 1.7.1`, `androidx.lifecycle 2.7.0`, `androidx.core 1.13.1`, `kotlin-stdlib-jdk7/jdk8 1.8.20`.
- **Recommandation** : surveiller (Dependabot ou `osv-scanner` en CI sur `pubspec.lock` et le classpath Gradle).

### SEN-09 · Code de debug oublié

- **MASVS** : MASVS-CODE-4
- **Sévérité : Info (conforme).** Aucun écran de test, URL interne, mot de passe de test ou point d'entrée caché trouvé dans jadx ni dans `libapp.so`. Les seules URLs sont publiques : `api.pwnedpasswords.com`, `fonts.gstatic.com` (SEN-02), `stopstalkerware.org`, les dépôts GitHub des listes, et Quad9 (`9.9.9.9`, `149.112.112.112`). `DebugProbesKt.bin` est un fichier standard de kotlinx-coroutines, inactif.

## 5. Faux positifs MobSF

| # | Alerte MobSF | Pourquoi ce n'est pas une faille |
|---|---|---|
| FP-01 | *Service `SentinelNotificationListener` protégé par une permission… à vérifier* (warning) | `BIND_NOTIFICATION_LISTENER_SERVICE` a le niveau `signature` du système : seul Android peut s'y connecter, et seulement après accord de l'utilisateur dans les réglages. `exported="true"` est imposé par Android. |
| FP-02 | *Service `SentinelVpnService`… à vérifier* (warning) | Même raison avec `BIND_VPN_SERVICE` (signature). Cette permission bloque aussi `startService` par une autre app. Export imposé pour un VpnService (VPN permanent). |
| FP-03 | *Receiver `ProfileInstallReceiver`… à vérifier* (warning) | Composant AndroidX ajouté automatiquement. `android.permission.DUMP` est `signature|privileged|development` : seuls le système et `adb shell` l'ont. |
| FP-04 | *SHA-1 is a weak hash* (warning, `vb.java:96`) | `vb` = `InstalledAppsScanner`. SHA-1 sert d'**identifiant** de certificat, pour comparer avec la liste stalkerware d'Echap qui est publiée en SHA-1 ; SHA-256 est calculé à côté. Aucune décision de confiance ne repose sur une collision. (Côté Dart, SHA-1 est aussi imposé par le protocole Pwned Passwords.) |
| FP-05 | *Insecure Random Number Generator* (warning) | Les fichiers signalés sont `kotlin.random.*` (bibliothèque standard) et un lambda fusionné par R8 contenant le délai aléatoire de `ProfileInstaller`. Les secrets utilisent `Random.secure()` (Dart) et le Keystore Android. |
| FP-06 | *IP Address disclosure* (warning) | `10.111.222.1` / `.2` : adresses privées de l'interface VPN locale ; `0.0.0.0`, `127.0.0.1` : valeurs ignorées par `ListParser`. Ni serveur interne ni infrastructure privée. |
| FP-07 | *This app may contain hardcoded secrets* (warning) | Toutes les valeurs ont été tracées : tables de conversion hexadécimale, alphabet de la clé de secours (`23456789ABCDEFGHJKLMNPQRSTUVWXYZ`), commit du moteur Flutter (`deb287481e…`), empreintes SHA-256 des fichiers de police de `google_fonts` (`54840850…`, `5fdd397f…` dans `part_r.dart`), constantes de `libflutter.so`. Aucune clé ni mot de passe. |
| FP-08 | *The App logs information* (info) | Fichiers signalés : moteur Flutter, AndroidX, ExifInterface, et un `Log.w("SentinelAnalyzer", "Moteur Flutter impossible à démarrer", e)` sans donnée utilisateur. Le vrai problème de logs est côté Dart (SEN-05), que MobSF ne voit pas. |
| FP-09 | *Copies data to clipboard* (info) | Champs de texte Flutter (`InputConnectionAdaptor`), et copie volontaire d'un mot de passe du coffre, marquée « sensible » et effacée après 30 s. Le risque résiduel sous Android < 10 est traité en SEN-03. |
| FP-10 | APKiD *Resources Confusion*, *anti_vm: Build.TAGS*, « root detection » attribuée à `a1`, et la liste *emails* | Noms de ressources raccourcis par R8 (`res/AE.png`) ; `Build.TAGS` = la vérification « test-keys » de l'audit de l'appareil de Sentinel ; `a1` = `relinker`, mauvaise attribution ; les « e-mails » sont des symboles Dart (`_list@0150898.of`). |

**Permissions (hotspot MobSF : 1 permission critique)** : toutes sont justifiées.

| Permission | Niveau | Justification |
|---|---|---|
| `QUERY_ALL_PACKAGES` | normal (restreinte par Google Play) | Indispensable au scanner d'apps (stalkerware, fausses apps). Autorisée par Play pour les apps de sécurité, après déclaration. |
| `POST_NOTIFICATIONS` | dangereuse | Alertes « Arnaque probable », demandée seulement à l'activation. C'est le hotspot MobSF. |
| `REQUEST_DELETE_PACKAGES` | normal | Ouvre l'écran système de désinstallation ; l'utilisateur confirme toujours. |
| `INTERNET`, `ACCESS_NETWORK_STATE` | normal | HIBP, Quad9, listes, état du Wi-Fi (sans localisation). |
| `FOREGROUND_SERVICE(_SYSTEM_EXEMPTED)` | normal | Pare-feu VPN au premier plan. |
| `SCHEDULE_EXACT_ALARM` | normal / spéciale | Fin d'analyse d'app à l'heure exacte. |
| `USE_BIOMETRIC` | normal | Déverrouillage du coffre. |
| `…DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | signature | Générée par AndroidX ; protège les receivers dynamiques. |

## 6. Composants exportés (manifest final décodé)

| Composant | Type | Exporté | Intent-filters | Protection | Verdict |
|---|---|---|---|---|---|
| `.MainActivity` | activité | oui | `MAIN/LAUNCHER` ; `SEND` `text/plain` ; `PROCESS_TEXT` `text/plain` ; + action `CHECK_ALERT` traitée sans filtre | **aucune** (normal pour une activité de lancement) | Surface réelle : texte seulement, limité à 5 000 caractères. Voir SEN-06. `taskAffinity=""` protège du détournement de tâche (StrandHogg). |
| `.SentinelNotificationListener` | service | oui | `NotificationListenerService` | `BIND_NOTIFICATION_LISTENER_SERVICE` (système) | OK (FP-01) |
| `.firewall.SentinelVpnService` | service | oui | `android.net.VpnService` | `BIND_VPN_SERVICE` (système) | OK (FP-02) |
| `.firewall.ReportCleanupReceiver` | receiver | **non** | — | — | OK, déclenché seulement par un PendingIntent explicite et immuable |
| `androidx.profileinstaller.ProfileInstallReceiver` | receiver | oui | 4 actions `profileinstaller` | `DUMP` (système / adb) | OK (FP-03) |
| `androidx.startup.InitializationProvider` | provider | **non** | — | — | OK |

Aucun `ContentProvider` exporté, aucun `FileProvider`, aucun lien profond (`BROWSABLE`).

## 7. Contrôles conformes

- **MASVS-STORAGE** : `allowBackup="false"` + `dataExtractionRules` qui excluent tout (cloud et transfert d'appareil) ; préférences en `MODE_PRIVATE`.
- **MASVS-NETWORK** : pas de `usesCleartextTraffic` ni de `networkSecurityConfig` ; avec targetSdk 36, le HTTP en clair est refusé et les certificats ajoutés par l'utilisateur ne sont pas acceptés. Vérification « HTTPS obligatoire » dans le code (`BlocklistUpdater`, `openWebPage`).
- **MASVS-PLATFORM** : tous les `PendingIntent` sont `FLAG_IMMUTABLE` et explicites ; `FLAG_SECURE` sur le coffre ; notifications neutres sur l'écran verrouillé.
- **MASVS-CRYPTO** : clé Keystore AES-256-GCM liée à la biométrie forte, invalidée si une empreinte est ajoutée ; `Random.secure()` partout pour les secrets.
- **MASVS-CODE** : 0 vulnérabilité connue (OSV) ; binaires natifs durcis.
- **MASVS-PRIVACY** : 0 traqueur (MobSF / Exodus) ; aucune donnée personnelle dans les assets.

## 8. Reproduire

```bash
flutter build apk --release
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
docker run -d --rm --name sentinel-mobsf -p 127.0.0.1:8000:8000 \
  opensecurity/mobile-security-framework-mobsf@sha256:5113fbad0727445dda01afdccafea5e107bfa8632ead8a169492f5caa8aa1b7c
docker logs sentinel-mobsf | grep "REST API Key"
# upload → scan → report_json / download_pdf (en-tête Authorization: <clé>)
java -jar apktool_3.0.3.jar d -o apktool_out app-release.apk
jadx -d jadx_out app-release.apk
strings -n 6 apktool_out/lib/arm64-v8a/libapp.so | grep "package:sentinel/"
docker stop sentinel-mobsf
```

## 9. Suite (P2, dynamique)

À confirmer sur un téléphone ou un émulateur : SEN-02 (capture réseau au premier lancement), SEN-05 (`adb logcat -s flutter` pendant une désinstallation ratée), SEN-06 (`adb shell am start -n com.iheb.sentinel/.MainActivity -a com.iheb.sentinel.action.CHECK_ALERT --es android.intent.extra.TEXT "..."`), stockage réel du coffre sur un appareil rooté.
