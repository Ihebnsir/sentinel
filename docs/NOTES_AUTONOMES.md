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

## Couverture de tests de la logique (2026-10-26)

Choix faits sans demander :

- **Périmètre mesuré** : `lib/services`, `lib/models`, `lib/utils` (demandé). Les écrans et widgets ne sont pas comptés. Mesure en lignes (fichier `coverage/lcov.info` de `flutter test --coverage`, déjà ignoré par Git).
- **Avant / après** : 81,7 % → 94,9 % (1 987 lignes). Les moins couverts au départ : `permission_labels.dart` (0 %), `share_service.dart` (0 %), `vault_biometrics.dart` (5 %), `protection_service.dart` (19 %), `apps_scanner_service.dart` (35 %), `device_security_service.dart` (36 %), `wifi_status.dart` (57 %), `vault_item.dart` (58 %), `firewall_service.dart` (60 %).
- **Tests ajoutés** (pas de test qui appelle du code sans rien vérifier) :
  - `firewall_service_test.dart`, `platform_services_test.dart`, `android_vault_biometrics_test.dart`, `share_service_test.dart` : un faux canal joue Android (`setMockMethodCallHandler`). Vérifient les arguments envoyés, la réponse vide, l'absence de code natif, et chaque code d'erreur Kotlin (ex. `NOT_RUNNING` → pare-feu coupé, `INVALIDEE`/`ABSENTE` → empreinte invalidée). Biométrie : une réponse mal formée (iv absent ou de mauvaise taille) est refusée. Rapports : seuls les rapports lisibles de moins de 24 h sont gardés. Texte partagé : vide ou arrivé après la fermeture, ignoré.
  - `permission_labels_test.dart` : lit la liste des permissions dans le source et vérifie, dans les 3 langues, un libellé non vide et **différent** pour chacune (détecte une clé recopiée) ; préfixe absent, autre app, casse : null.
  - `vault_item_test.dart` : JSON aller-retour, dates en UTC, champs facultatifs absents, JSON abîmé qui échoue (pas d'élément à moitié rempli), `copyWith`, `toString` sans secret ; générateur tout décoché.
  - `pwned_passwords_test.dart` : réseau coupé pendant la vérification (erreur gardée, rien retenu) ; coffre verrouillé pendant la vérification (erreur et résultat ignorés).
  - `wifi_risk_test.dart` : valeurs d'un mauvais type dans la Map Android ; libellés distincts dans les 3 langues.
- **Laissé de côté** : `vault_platform.dart` (53 %), `wifi_service.dart` (73 %), `language_store.dart` (80 %) : le reste est surtout du passage de canal déjà du même modèle que ceux testés ; le total dépasse largement 85 %.
- **Script de résumé** : `tools/coverage/coverage_summary.dart`, en Dart (déjà installé en CI, rien à ajouter), plutôt que `lcov`/`genhtml` ou un service comme Codecov/Coveralls. Il affiche un tableau Markdown du moins au plus couvert, l'ajoute au résumé GitHub (`GITHUB_STEP_SUMMARY`) et sort en erreur sous `--min`.
- **CI** : `flutter test` devient `flutter test --coverage`, puis l'étape « Coverage (logic, min 85 %) ». Seuil à 85 % (demandé) et non au chiffre actuel, pour ne pas bloquer un petit ajout de code non testé. Pas d'envoi du fichier lcov en artefact (évite d'ajouter une action de plus à épingler).
- **README** (anglais et français) : nombre de tests mis à jour (545 tests, 40 fichiers ; l'ancien chiffre 447/29 datait d'avant la traduction), paragraphe « Couverture » avec la commande locale. Le pourcentage du README est écrit à la main : à remettre à jour de temps en temps.

## Scanner de QR code anti-hameçonnage (« quishing ») (2026-10-26)

Choix faits sans demander :

- **Bibliothèque** : [zxing-android-embedded](https://github.com/journeyapps/zxing-android-embedded) 4.3.0 (JourneyApps, Apache 2.0) côté Kotlin, avec ZXing core 3.5.3 (Apache 2.0, dernière version, au lieu du 3.4.1 tiré par défaut). Décodage ZXing classique (pas d'IA) : aucun modèle à télécharger, aucun accès réseau. Vérifié dans l'AAR : le manifeste n'ajoute que `CAMERA` et des `uses-feature` non obligatoires.
  - **Écarté : `mobile_scanner` / ML Kit.** Le modèle peut être inclus dans l'app, mais d'après les conditions de Google ML Kit (developers.google.com/ml-kit/terms), les API « peuvent contacter les serveurs de Google » et « envoient des statistiques d'utilisation ». C'est contraire à la promesse « aucun échange réseau hors des 3 fonctions facultatives ». De plus, ML Kit n'est pas open source.
  - **Écarté : `flutter_zxing`.** Il compile zxing-cpp avec le NDK (build plus lourd) pour le même décodeur.
  - **Limite** : zxing-android-embedded n'a plus de nouvelle version depuis 2021 (stable, en maintenance). Le décodeur ZXing core est à jour.
- **Écran de scan** : celui de la bibliothèque (`CaptureActivity`), non exporté. Il suit le sens du téléphone (`fullSensor`, au lieu du paysage par défaut) ; pas de bip ; aucune image enregistrée (`setBarcodeImageEnabled(false)`) ; QR codes seulement. La phrase sous le viseur vient des fichiers de langues de Sentinel.
- **Permission caméra** : demandée seulement au moment du scan. Avant la demande d'Android, Sentinel explique pourquoi (« seulement pendant le scan, l'image n'est ni enregistrée ni envoyée ») ; « Annuler » n'appelle pas Android. En cas de refus définitif (« Ne plus demander »), un message s'affiche avec un bouton « Réglages » qui ouvre la page Android de Sentinel. Caméra non obligatoire à l'installation (`required="false"`).
- **Lecture des formats** (`lib/services/qr/qr_content.dart`, pur Dart) :
  - lien http/https seul ;
  - types dangereux (`javascript:`, `vbscript:`, `data:`, `file:`, `content:`, `intent:`, `android-app:`, `jar:`) ;
  - `WIFI:` (champs dans n'importe quel ordre, caractères protégés par `\`) ;
  - `tel:`, `sms:`/`smsto:`/`mmsto:` ;
  - paiements : crypto (`bitcoin:`, `ethereum:`…), UPI, virement SEPA (EPC, « BCD »), QR EMVCo des banques (TLV, devise ISO 4217 traduite pour TND, EUR, USD, MAD, DZD, GBP, INR) ;
  - tout le reste (texte, `mailto:`, lien suivi d'un texte) est du texte analysé comme un message.

  Un format abîmé ne lève jamais d'exception : il devient du texte.
- **Wi-Fi** : « T:WPA » devient « WPA2 ou WPA » (le QR ne les distingue pas), SAE devient WPA3, EAP entreprise, nopass ou rien devient réseau ouvert. Le niveau et les conseils viennent de `assessWifi` (`wifi_risk.dart`, mêmes textes que l'accueil). Réseau ouvert ou WEP : avertissement en plus. Pas de verdict « arnaque » (c'est un risque réseau, pas une escroquerie), pas de bouton « se connecter » (il faudrait d'autres permissions). Le nom du réseau n'est pas envoyé à l'IA.
- **Décisions** (`qr_safety.dart`, pur Dart, testé) :
  - le verdict est le pire entre l'analyseur existant (`analyzeMessage` : IA + règles des liens) et les règles propres aux QR codes ;
  - lien dangereux et code USSD (`*` ou `#` dans un numéro, ex. effacement ou renvoi d'appel) : « Arnaque probable » ;
  - SMS vers un numéro court (6 chiffres ou moins, souvent surtaxé) : au moins « Suspect » ;
  - paiement : avertissement « faux QR collés sur les vrais », sans changer le verdict ;
  - numéro ou Wi-Fi sans problème : pas de verdict affiché (rien à juger).
- **Actions**, toujours après une boîte de confirmation qui dit exactement ce qui va se passer :
  - lien : « Ouvrir le lien » si rien de suspect, sinon « Ouvrir quand même » ;
  - « Appeler ce numéro » ouvre le composeur, sans appeler ;
  - « Préparer le SMS » ouvre l'app SMS avec le texte, sans envoyer ;
  - « Ouvrir dans une app de paiement », seulement pour les paiements sous forme de lien (crypto, UPI). SEPA et EMVCo : affichage seul, à payer depuis l'app de la banque.

  Bouton visible mais désactivé si « Arnaque probable », avec « Bloqué par Sentinel ». Si l'IA ne se charge pas, aucune action n'est proposée.
- **Double vérification Kotlin** (`QrActions.kt`, testé par `QrActionsTest`) : seulement http/https (catégorie BROWSABLE), numéros sans `*`/`#`, et schémas de paiement connus. Le reste est refusé (`NOT_ALLOWED`). L'arobase dans un lien reste permis côté Kotlin : l'analyseur Dart la signale déjà (Suspect) et l'utilisateur a confirmé.
- **Canal** : `com.iheb.sentinel/qr` (classe `QrScanner.kt`), codes de demande 5 et 6 (1 à 4 déjà pris). Le contenu scanné n'est jamais journalisé.
- **Interface** : ligne « Scanner un QR code » entre deux traits fins, sous la protection automatique, dans l'onglet Messages. Résultat sur un écran à part (`qr_result_screen.dart`) : type, contenu brut sélectionnable dans un cadre fin, détails, niveau Wi-Fi ou verdict, action. Le bloc verdict de l'onglet Messages est devenu un widget partagé (`widgets/verdict_section.dart`), même rendu.
- **Textes** : 48 clés `qr…` en français, anglais et arabe (à relire, comme les autres traductions), plus « Caméra » dans la politique de confidentialité (autorisations) et « QR codes scannés » dans « Ce que Sentinel n'enregistre jamais ». Aucun retour à la ligne dans les textes (la police n'a pas de caractère U+000A, vérifié par `l10n_keys_test`).
- **Licence** : entrée « ZXing » ajoutée à la page Licences (code Kotlin, absent des licences Dart) et section « Données tierces » des README.
- **Tests** : `qr_content_test.dart` (tous les formats et cas abîmés), `qr_safety_test.dart` (verdicts et actions), `qr_screens_test.dart` (rien ne s'ouvre sans confirmation, bouton désactivé, Wi-Fi ouvert, USSD, échec de l'IA, arabe de droite à gauche, explication avant la caméra, refus définitif), `QrActionsTest.kt`. Couverture de la logique : 95,4 %.

Non vérifié : l'interface n'a pas été lancée sur un téléphone (règle : pas de `flutter run`). À tester à la main : le scan réel, la demande de caméra et son refus définitif, la rotation de l'écran de scan, l'ouverture des apps (navigateur, composeur, SMS, portefeuille), un QR de paiement réel d'une banque tunisienne (EMVCo supposé).

## Thème sombre « nuit » (2026-10-26)

Choix faits sans demander :

- **Tokens de couleur** : `AppColors` est maintenant une `ThemeExtension` avec deux palettes, `AppColors.light` (couleurs d'origine) et `AppColors.dark`. Les écrans lisent `context.colors.x` ; il ne reste aucune couleur en dur dans `lib/` hors de `lib/theme/` (vérifié par recherche de `Colors.`/`Color(0x`, sauf `Colors.transparent`). Les noms restent ceux d'avant (`chaux` = fond, `encre` = texte) pour garder un diff lisible. Nouveaux tokens :
  - `secondaire` (texte atténué, remplace `encre` à 60 %) ;
  - `discret` (remplace `encre` à 45 %) ;
  - `surCouleur` (texte sur un fond plein).
- **Palette nuit** (fond = celui de l'icône, #0E1A33). Contraste sur le fond :

  | Rôle | Couleur | Contraste |
  |---|---|---|
  | Texte (`encre`) | #E8EEF7 | 14,8:1 |
  | Bleu | #6EA8FF | 7,2:1 |
  | Vert (`zitouna`) | #8CC063 | 8,1:1 |
  | Ocre | #F2B84B | 9,7:1 |
  | Rouge (`rommen`) | #FF7A88 | 6,9:1 |
  | Texte secondaire (70 %) | | 7,8:1 |
  | Texte discret (58 %) | | 5,7:1 |
  | Lignes fines (`ligne`) | #25365C | 1,45:1 (décoratif) |

  Sur le bleu plein (boutons), le texte est bleu nuit, pas blanc (blanc sur #6EA8FF : 2,4:1).
- **Texte sur couleur pleine** : `textOn(fond)` choisit `surCouleur` ou `encre` selon le meilleur contraste WCAG. Il sert à l'arche du score (chiffre sur la partie remplie) et au bandeau d'alerte Wi-Fi. Effet aussi en clair : le chiffre sur l'arche ocre (score 45 à 69) passe de blanc (2,2:1) à encre (7,3:1).
- **Thème clair, une seule retouche** : `secondaire` passe de 60 % à 64 % d'encre (4,2:1 → 4,76:1, niveau AA). Le thème clair reçoit aussi les thèmes globaux :
  - boutons pleins bleu `#1F5FA8` (avant : bleu généré par Material, très proche) ;
  - séparateurs `ligne` ;
  - fond des boîtes de dialogue et des feuilles du bas en `chaux` (déjà le cas pour presque toutes).
- **Écarts restants du thème clair, signalés et non corrigés** (changer l'ambre de la marque dépasse la demande) :
  - ocre en texte (« Suspect », « Modéré », force « moyen ») : 2,0:1 ;
  - texte `discret` : 2,7:1 ;
  - piste : un ocre texte #8A6100 (5,2:1) et un discret à 64 %.
- **Choix du thème** : `ThemeStore`/`ThemeController` (`lib/services/theme_store.dart`), même modèle que la langue : fichier `theme.json`, lu avant le premier écran ; un fichier abîmé ou absent donne « Comme le téléphone ». Ligne « Apparence » dans Réglages, sous Langue : Comme le téléphone / Clair / Sombre. Changement immédiat, sans relancer. « thème » ajouté à « Vos choix » dans la politique de confidentialité.
- **Barre d'état** : icônes claires en sombre, foncées en clair (`AnnotatedRegion` autour de l'app), y compris sur les onglets sans AppBar. L'écran de lancement Android était déjà en bleu nuit (`values-night`, flutter_native_splash).
- **Conversion** : script (remplacement de `AppColors.x` et retrait des `const` englobants), puis reprise à la main des cas sans `context` :
  - fonctions de couleur d'état : `verdictColor`, `wifiLevelColor`, `RiskLevelText.colorFor`, `ScoreArch.colorFor` et la force du mot de passe reçoivent la palette ;
  - séparateurs `const Divider` sans couleur (`dividerTheme`) ;
  - `_muted(context)`.

  `dart format` appliqué seulement aux blocs modifiés dans les fichiers qui n'étaient pas déjà au format.
- **Tests** :
  - `theme_test.dart` : calcul WCAG (valeurs de référence 21:1 et #777 = 4,48:1), paires principales des deux palettes, texte sur couleurs pleines, chiffre de l'arche, fichier du thème, choix dans Réglages appliqué tout de suite ;
  - `dark_screens_test.dart` : accueil (arche), alerte Wi-Fi, Messages avec verdict, QR code, rapport d'analyse, détail d'une app, pare-feu, Réglages, politique, présentation, création du coffre, mot de passe du coffre. Sur chaque écran : fond nuit, et chaque texte affiché est vérifié (aucune couleur du thème clair, contraste d'au moins 3:1 sur le fond, sauf texte posé sur une couleur pleine) ;
  - les tests utilisent une largeur de 800 dp : à 360 dp, la police de test (glyphes carrés) déborde alors que Readex Pro tient.

Non vérifié : l'app n'a pas été lancée sur un téléphone (règle : pas de `flutter run`). À regarder à la main en sombre : rendu réel de Readex Pro, page des licences (écran système de Flutter), sélecteur de fichiers et fenêtre d'empreinte (écrans d'Android), notifications.
