# Audit P3a : corrections

| | |
|---|---|
| Base | commit `2f1c2a2` (« corrections », travail en cours) + finitions de cette session |
| Constats traités | SEN-02, 03, 05, 06, 12, 13, 14, 16, 17 (corrigés) ; SEN-07, 15 (acceptés) |
| Hors périmètre | SEN-01, 04, 08, 10, 11 : P3b |
| APK retesté | release, SHA-256 `ad4bfeab22df77f0b8fca6efff28b3267723b8120fbae05d624309ed1522c3c8` |
| Émulateur | `Sentinel_Audit_Root` (Android 17, Google APIs, root), voir P2 pour la méthode |

## 1. Résumé

| ID | Statut | Changement en une phrase | Test automatique | Retest émulateur |
|---|---|---|---|---|
| SEN-02 | **Corrigé** | Police Readex Pro embarquée, `google_fonts` retiré | `font_assets_test.dart` (5) | 0 connexion de Sentinel au premier lancement ; écran identique au pixel près |
| SEN-03 | **Corrigé** | Android ≤ 9 : avertissement avant la 1re copie, effacement à 10 s | `clipboard_guard_test.dart` (6), `VaultPolicyTest` | non testable (pas d'image ≤ 9) |
| SEN-05 | **Corrigé** | `debugLog(() => …)` muet hors debug ; plus aucun texte de debug dans le binaire | `no_release_logs_test.dart` (2), `KotlinLogsTest` | aucune ligne `flutter` de l'app ; `strings` du binaire |
| SEN-06 | **Corrigé** | Alertes via `AlertRelayActivity` non exportée + boîte en mémoire ; `CHECK_ALERT` supprimée | `IncomingTextTest` (6), `ManifestTest` (3) | intents forgés : aucune analyse ; partage intact |
| SEN-07 | **Accepté** | — | — | — |
| SEN-12 | **Corrigé** | Étape 0 de normalisation (Dart = Python), nouveau signal « caractères invisibles » | `hidden_characters_test.dart` (14), parité 38 cas | exemple P2 : 96 % = 96 % |
| SEN-13 | **Corrigé** (Android 14+) | Coffre marqué `accessibilityDataSensitive` avec FLAG_SECURE | `VaultPolicyTest` (règle de version) | TalkBack/uiautomator lisent toujours (voulu) |
| SEN-14 | **Corrigé** | Rapports AES-256-GCM (Keystore), expiration revérifiée à chaque lecture, réveil après redémarrage | `AppReportStoreTest` (12), `report_expiry_test.dart` (2) | fichier chiffré sur disque, relu par l'app |
| SEN-15 | **Accepté** | — | — | — |
| SEN-16 | **Corrigé** | « Bonjour » sans prénom | `home_greeting_test.dart` (2) | capture d'écran |
| SEN-17 | **Corrigé** | Alerte Wi-Fi en `MaterialBanner` en haut, fermeture à 10 s | `wifi_alert_test.dart` (4) | bandeau en haut, « Enregistrer » libre |

Contrôles finaux : `flutter analyze` sans problème ; `flutter test` **430 réussis** ; `./gradlew testDebugUnitTest` **101 tests, 0 échec** (1 ignoré : le benchmark de `DomainSetTest`, ignoré exprès avant P3a) ; `flutter build apk --release` réussi.

## 2. Détail par constat

### SEN-02 · Police téléchargée chez Google — Corrigé

**Changement**
- `pubspec.yaml` : `google_fonts` retiré ; famille `ReadexPro` déclarée avec `assets/fonts/ReadexPro-Regular.ttf`.
- `assets/fonts/ReadexPro-Regular.ttf` : **exactement** le fichier que servait `fonts.gstatic.com` (SHA-256 `d01db080…3f4c`, vérifié avec la taille indiquée par `google_fonts` 9.0.0).
- Licence : `assets/fonts/ReadexPro-OFL.txt` (commit `7ca5a530` de `google/fonts`), enregistrée dans `LicenseRegistry` (`lib/main.dart`).
- `lib/theme/app_theme.dart` : `fontFamily: 'ReadexPro'` au lieu de `GoogleFonts.readexProTextTheme()`.
- README (EN et FR) : la phrase sur le réseau est corrigée. Elle était fausse même sans la police : le pare-feu (Quad9) et la mise à jour des listes (GitHub) utilisent aussi le réseau, après accord.

**Pourquoi un seul fichier ?** `google_fonts` mettait chaque style dans une famille à une seule graisse (`ReadexPro_regular`). Les textes en `w500`/`w600` étaient donc du **gras simulé** à partir du Regular ; d'ailleurs, en P2, le cache de l'app ne contenait que `ReadexPro_regular_….ttf`. Un premier essai avec les 5 graisses réelles donnait un titre plus large (69 871 pixels différents). Garder le seul Regular reproduit l'ancien rendu à l'identique. Les vraies graisses pourront être ajoutées plus tard si on accepte ce changement visuel.

**Preuves**
- Binaire : `strings libapp.so` → 0 occurrence de `fonts.gstatic.com` et de `google_fonts`.
- Émulateur, installation propre + 90 s sans action, iptables par UID : **0 connexion de Sentinel** (P2 : 1 connexion TLS `fonts.gstatic.com`). Les seuls flux du pcap (`update.googleapis.com`, `edgedl.me.gvt1.com`) viennent du système. Aucun fichier de police dans `files/`.
- Rendu : comparaison pixel par pixel avec la capture de P2 → 9 983 pixels différents, **tous** dans la barre d'état (heure, y 0-119) et la salutation (y 200-279, voir SEN-16). Le reste de l'écran est identique.

### SEN-03 · Presse-papiers lisible par toutes les apps (Android ≤ 9) — Corrigé

**Changement**
- `VaultPolicy.kt` : `isClipboardShared(sdkInt) = sdkInt < 29` ; canal `isClipboardShared` dans `VaultProtection.kt`.
- `ClipboardGuard` (`vault_platform.dart`) : délai 10 s si partagé, 30 s sinon ; `needsWarning()` / `acceptWarning()` (une fois par ouverture de l'app) ; `copy()` renvoie le délai réel.
- `lib/widgets/vault_copy.dart` : dialogue « Sur cette version d'Android, toutes les applications peuvent lire ce que vous copiez. » avec « Annuler » / « Copier quand même ». Utilisé par la clé de récupération et les mots de passe ; le message de confirmation affiche le vrai délai.
- minSdk reste 24. Android 10+ : comportement inchangé.

**Preuves** : `clipboard_guard_test.dart` (avertissement une seule fois, effacement à 10 s pile, pas d'effacement de ce que l'utilisateur a copié ensuite, « Annuler » ne copie rien, Android 10+ sans dialogue avec effacement à 30 s) ; `VaultPolicyTest` (API 24 et 28 partagés, 29 et 37 non). Pas de retest émulateur : il n'existe pas d'image Android ≤ 9 dans l'environnement.

### SEN-05 · Logs en release — Corrigé

**Changement**
- `lib/utils/debug_log.dart` : `debugLog(String Function() message)`, qui n'appelle `debugPrint` que si `kDebugMode`. Le texte est passé sous forme de fonction : en release, il n'est jamais construit, et le compilateur ne garde même pas les chaînes.
- Les 14 appels (`debugPrint` et `if (kDebugMode) debugPrint`) passent par `debugLog`.
- `analysis_options.yaml` : `avoid_print: true` explicite. Comme cette règle ne voit pas `debugPrint`, `test/no_release_logs_test.dart` interdit `print`, `debugPrint`, `dart:developer`, `stdout`/`stderr` partout dans `lib/` sauf dans `debug_log.dart`.
- Kotlin : seuls deux `Log.w` existent, sans donnée de l'utilisateur (exception au démarrage du moteur ; code d'erreur fixe). `KotlinLogsTest` échoue si un nouveau `Log` apparaît sans relecture.

**Preuves**
- Binaire release : 0 occurrence de « Pare-feu : », « Argon2id : », « Coffre : », « Indicateurs de stalkerware illisibles », « Action ». Une première version avec `debugLog(String)` les laissait dans le binaire (sans les écrire) : d'où la version avec fonction.
- Émulateur : sur toute la session (premier lancement, intents, coffre, pare-feu, analyse, réseau coupé), `logcat -s flutter` ne contient que la ligne du moteur « Using the Impeller rendering backend ».

### SEN-06 · Action interne CHECK_ALERT accessible aux autres apps — Corrigé

**Choix : activité relais non exportée**, plutôt qu'un jeton en mémoire. Un jeton serait perdu si Android tue l'app entre la notification et l'appui, alors que les extras d'un `PendingIntent` immuable survivent. Et une activité `exported="false"` ne peut être lancée que par Sentinel.

**Changement**
- `AlertRelayActivity` (`exported="false"`, `Theme.NoDisplay`, hors récents) : reçoit le texte de la notification, le dépose dans `alertInbox` (mémoire du processus, lu une seule fois), puis ouvre `MainActivity` avec `ACTION_OPEN_ALERT` **sans texte**.
- `ScamAlertNotifier` vise le relais. `ACTION_CHECK_ALERT` est supprimée.
- `MainActivity` → `incomingText()` (`IncomingText.kt`, fonction pure) : `SEND`/`PROCESS_TEXT` inchangés ; `OPEN_ALERT` lit **uniquement** `alertInbox` et ignore tout texte joint ; toute autre action donne `null`.

**Preuves**
- JUnit : `IncomingTextTest` (CHECK_ALERT ignorée, OPEN_ALERT forgé ignoré, alerte lue une fois, partage intact, troncature à 5 000) ; `ManifestTest` (relais non exporté ; `MainActivity` limitée à MAIN, SEND, PROCESS_TEXT ; aucun composant exporté sans permission système, en dehors des exceptions justifiées).
- Émulateur, en tant qu'app ordinaire (uid 2000) :

  | Intent | Résultat |
  |---|---|
  | `CHECK_ALERT` + texte forgé | app ouverte, **aucune analyse** (P2 : « Rien de suspect » affiché) |
  | `OPEN_ALERT` + texte forgé | **aucune analyse** |
  | `AlertRelayActivity` | `SecurityException … not exported from uid 10236` |
  | relais lancé en root (= tap sur la notification) | analyse affichée : « Arnaque probable, 85 % » |
  | `SEND` | « Rien de suspect, 24 % » (partage intact) |
  | `PROCESS_TEXT` | « Rien de suspect, 6 % » (sélection intacte) |

### SEN-07 · Modèle anti-arnaque lisible — Accepté

Le modèle doit tourner hors ligne sur le téléphone, donc il est dans l'APK, et il est public sur GitHub (MIT). Le chiffrer ou l'obfusquer ne retarderait qu'un attaquant déjà en possession du code. Les défenses qui ne dépendent pas du modèle restent en place : analyse des liens (marques imitées, adresses IP, raccourcisseurs) et, depuis SEN-12, détection des caractères invisibles. Mesure de suivi : réentraîner avec de vrais messages (`ml/data/messages_perso.csv`) pour que le modèle change régulièrement.

### SEN-12 · Caractères invisibles et inversion de texte — Corrigé

**Changement**
- Étape 0 du prétraitement, identique en Dart (`normalizeMessage`, `phishing_model.dart`) et en Python (`normalize_text`, `ml/train.py`, passée à `TfidfVectorizer(preprocessor=…)`). Le texte qui suit un U+202E (RLO), jusqu'au U+202C (PDF) ou à la fin du paragraphe, est **remis à l'endroit**. Sont ensuite retirés : U+00AD, U+061C, U+180E, U+200B-200F, U+202A-202E, U+2060-2064, U+2066-2069, U+FEFF. Spécification complète dans `ml/README.md`.
- Pourquoi remettre à l'endroit : retirer seulement les caractères laissait le domaine écrit à l'envers, donc invisible pour l'analyse des liens.
- Signal : `hasDeceptiveCharacters()` (U+200B, U+202A-202E, U+2060-2064, U+2066-2069, U+FEFF) ajoute la raison « Caractères invisibles ou d'inversion de texte (technique d'arnaque) », placée en premier, et le verdict est au minimum « Suspect ». Sont exclus du signal (mais retirés du texte) : U+200C/U+200D (emojis composés), U+200E/U+200F/U+061C (claviers arabes), U+00AD/U+180E (texte copié du web), pour éviter les fausses alertes.
- Les liens sont analysés sur le texte normalisé.
- Modèle réentraîné (format 2) : **vocabulaire, IDF, coefficients, intercept et métriques identiques** à l'ancien, car aucun message d'entraînement ne contenait ces caractères. Seules la version et la description du prétraitement changent.
- Fixture de parité : 38 cas (8 nouveaux), avec pour chacun le texte normalisé attendu (`normalise`).

**Preuves**
- `train.py` : implémentation de référence (sans scikit-learn, uniquement d'après le JSON) = scikit-learn, écart 7,8e-16.
- `phishing_parity_test.dart` : pour les 38 cas, Dart retrouve **le même texte normalisé** que Python et la même probabilité (tolérance 1e-9) ; les listes de caractères Dart et JSON sont identiques.
- Exemple de P2 rejoué (`hidden_characters_test.dart`, modèle réel) : texte propre **96 %**, même domaine inversé par RLO **96 %** (P2 : 74 %), même verdict « Arnaque probable », mêmes raisons plus la raison « caractères ». Note : le texte réellement envoyé en P2 contenait une coquille (`silob` → « bolis ») ; le test utilise le domaine exact.

### SEN-13 · Clé de récupération lisible par l'accessibilité — Corrigé (Android 14+)

**API vérifiée** dans les sources officielles d'Android (`android-37.0/android/view/View.java`) : `View.setAccessibilityDataSensitive(int)` avec `ACCESSIBILITY_DATA_SENSITIVE_YES` (API 34). Seuls les services dont `isAccessibilityTool` est vrai (TalkBack, Switch Access…) peuvent alors lire la vue. `ViewGroup.calculateAccessibilityDataSensitive()` propage le réglage aux enfants, et `AccessibilityInteractionController` vérifie la vue hôte avant d'interroger son `AccessibilityNodeProvider`. Les nœuds virtuels de Flutter sont donc couverts.

**Changement** : `VaultProtection.setSecure()` active et désactive, en même temps que FLAG_SECURE, la sensibilité de la vue racine de la fenêtre (Android 14+), pendant tout l'affichage du coffre : clé de récupération et mots de passe révélés.

**Avant Android 14** : aucune API équivalente. Les seules options seraient de masquer la clé à l'accessibilité (`ExcludeSemantics`), ce qui **exclurait les utilisateurs aveugles**, ou de la masquer pour tout le monde. Choix : ne rien masquer avant Android 14, pour que TalkBack fonctionne partout. Le risque reste limité au cas d'un logiciel espion à qui l'utilisateur a accordé l'accessibilité (ce que l'analyse des apps de Sentinel signale).

**Preuves** : retest émulateur, la clé reste lisible par uiautomator. C'est **voulu** : `UiAutomation` se déclare outil d'accessibilité par défaut (`UiAutomationConnection.java` : `info.setAccessibilityTool(true)`), comme TalkBack. Vérifier qu'un service **non** reconnu est bien bloqué demanderait une app de test dédiée (drapeau caché `FLAG_NOT_ACCESSIBILITY_TOOL`) ; non fait. Le code de version est couvert par la compilation (lint `NewApi` vérifié au build release).

### SEN-14 · Rapports d'analyse en clair, suppression en retard — Corrigé

**Changement**
- `ReportCipher` / `AesGcmReportCipher` : AES-256-GCM, format `[version][IV 12 o][chiffré + tag]`, données associées = **nom du fichier** (renommer un rapport pour repousser son expiration le rend illisible).
- `ReportKeystore` : clé AES-256 dans l'Android Keystore, inextractible, sans authentification de l'utilisateur.
- `AppReportStore.list()` : purge, puis **revérifie l'expiration de chaque fichier au moment de le lire** ; tout fichier illisible (modifié, renommé, ancien format en clair) est supprimé.
- Réveil : alarme exacte si Android l'autorise (`canScheduleExactAlarms`, et toujours avant Android 12), sinon inexacte. `BootReceiver` (BOOT_COMPLETED, MY_PACKAGE_REPLACED, diffusions protégées réservées au système) reprogramme le nettoyage, car Android efface les alarmes à ces moments. Ajout de `RECEIVE_BOOT_COMPLETED`.
- Dart : `AppReportScreen` se ferme à l'heure exacte d'expiration (minuteur), en plus du filtre existant à la réception.

**Limite connue** : sur Android 14+, la permission d'alarme exacte est refusée par défaut. Le fichier chiffré peut alors rester jusqu'à environ 1 h après l'expiration, mais il n'est **jamais relu ni affiché**.

**Preuves**
- `AppReportStoreTest` (vrai AES-GCM sur la JVM) : aucun domaine en clair sur le disque ; fichier modifié rejeté et supprimé ; fichier renommé rejeté ; ancien rapport en clair supprimé ; jamais relu après 24 h, même sans passage du nettoyage ; clé différente → illisible.
- `report_expiry_test.dart` : écran encore ouvert à 23 h 59 min 59 s, fermé à 24 h pile ; fermé tout de suite s'il est déjà expiré.
- Émulateur (vrai Keystore) : analyse de Chrome de 2 min → fichier de 544 octets, version 1, IV aléatoire, aucun nom de domaine ni champ JSON lisible ; l'app l'affiche correctement (« Chrome, 4 domaines, 24 octobre 2026 à 8 h 44 »). Un faux rapport au nom valide, placé à la main, est supprimé dès la lecture suivante.

### SEN-15 · Pas d'épinglage de certificat — Accepté

L'interception de P2 n'a été possible qu'avec **root**, en ajoutant une autorité de certification au magasin **système**. Les CA installées par l'utilisateur sont déjà refusées (targetSdk 36). Les serveurs contactés (Cloudflare pour HIBP, GitHub pour les listes) changent de certificats sans prévenir : un épinglage risquerait de casser la vérification des fuites et les mises à jour pour tout le monde. Ce que révèle HIBP est minimal par conception (5 caractères d'empreinte). Les listes sont contrôlées (taille, format, cohérence) et les domaines protégés ne peuvent pas être bloqués. Piste pour plus tard : signer `manifest.json` des listes avec une clé de l'auteur, ce qui protège même contre une CA compromise, sans épinglage.

### SEN-16 · « Bonjour, Iheb » — Corrigé

`homeGreeting = 'Bonjour'` (`home_screen.dart`) ; aucun prénom n'est stocké. `home_greeting_test.dart` vérifie la constante et l'absence du prénom dans `lib/`. Retest : capture d'écran (« Bonjour »).

### SEN-17 · Bandeau Wi-Fi qui cache des boutons — Corrigé

**Cause** : une `SnackBar` avec action a `persist = true` par défaut (`material_ui`, `snack_bar.dart`) : elle ne disparaissait jamais et restait en bas, sur les boutons.

**Changement** : `showWifiAlert()` (`lib/widgets/wifi_alert.dart`) affiche un `MaterialBanner` **en haut**. Le `Scaffold` décale alors le contenu vers le bas (`contentTop += materialBannerSize.height`), donc rien n'est recouvert. Actions « Fermer » et « Détails » ; fermeture automatique après 10 s.

**Preuves**
- `wifi_alert_test.dart` sur les **vrais écrans** du coffre (« Créer mon coffre », « Annuler », « Enregistrer ») : aucun chevauchement, et l'appui atteint bien le bouton. Le même test avec l'ancienne SnackBar échoue (bouton recouvert, appui intercepté).
- Émulateur, écran « Nouveau : mot de passe », Wi-Fi coupé puis rallumé : bandeau à y 279-552, titre décalé (y 344 → 573), « Enregistrer » à y 2232-2358, sans chevauchement ; bandeau fermé seul après 10 s.

## 3. Autre correction : scan de secrets (CI)

Le workflow « Secrets scan » (Gitleaks 8.30.1) échouait sur `main` depuis `311e66a` (rapports P1). Gitleaks a été relancé en local (même version, somme SHA-256 vérifiée) : les 20 alertes viennent de `docs/audit/mobsf/mobsf_report.json` et désignent des paires de chaînes extraites du moteur Flutter par MobSF (`TRUST_TOKEN`, `CAMELLIA-256-CFB1`, symboles C++). Ce sont des faux positifs, ajoutés à `.gitleaksignore` (une empreinte). Rescan local : « no leaks found ».
