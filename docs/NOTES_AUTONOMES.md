# Journal des décisions

Décisions prises pendant le développement, datées, avec leur raison. C'est un **historique** : les sections anciennes décrivent des fonctions retirées depuis (onglet Messages, modèle anti-arnaque, signalement, retirés en 1.1.0). L'état actuel est décrit dans le [README](../README.md), le [CHANGELOG](../CHANGELOG.md) et [SECURITY_DESIGN.md](SECURITY_DESIGN.md).

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

## Accessibilité : TalkBack, zones tactiles, contraste, police à 200 % (2026-10-26)

Détail de ce qui a été vérifié et corrigé : [ACCESSIBILITE.md](ACCESSIBILITE.md). Choix faits sans demander :

- **Ocre du thème clair foncé** : #E0A526 → #8A6100 (2,0:1 → 5,2:1), partout, y compris l'arche d'un score de 45 à 69. Ça règle l'écart noté au thème sombre. Plutôt qu'une deuxième couleur « ocre pour le texte » : une seule couleur, rien à oublier dans les écrans. Sur l'arche ocre, le chiffre redevient blanc (choix automatique de `textOn`).
- **Gris du thème clair** : `discret` 45 % → 64 % (4,8:1) et `secondaire` 64 % → 70 % (5,8:1), pour garder deux niveaux de gris distincts. Les gris codés en dur (`encre` à 30–50 %) passent aux couleurs du thème. L'onglet inactif prend `secondaire`.
- **Bouton Réglages de l'accueil** : retrait de la forme compacte (40 dp → 48 dp). La roue dentée passe de 50 % d'encre à `secondaire`.
- **Phrase de l'arche** : nouvelle clé `scoreSemantics` (« Score de sécurité : {score} sur 100 », en / ar traduits). C'est le score final qui est lu, pas le chiffre animé.
- **Deux petits widgets partagés** plutôt que de répéter le même code : `ActionsRow` (rangée « Annuler … Valider » qui passe sur deux lignes, basée sur `OverflowBar`) et `LoadingBar` (barre de chargement nommée « Chargement en cours », nouvelle clé `commonLoading`, et annoncée).
- **Interrupteurs et case à cocher** : `MergeSemantics` autour de la ligne (texte + interrupteur). La ligne entière n'est pas devenue cliquable : seule la lecture change, pas le comportement.
- **Verdict annoncé** (*live region*) et marqué comme titre ; barre de force du mot de passe muette (la phrase en dessous suffit) ; icônes d'apps ignorées (nom écrit à côté).
- **Test** : vraie police Readex Pro chargée dans `test/accessibility_test.dart` (glyphes carrés de la police de test trop larges à 200 %), écran de 360 dp, très haut pour que toute la liste soit construite. `isSemantics` plutôt que `containsSemantics` (déprécié dans cette version de Flutter).
- **SEN-13 non touché** : `VaultProtection.kt` inchangé, aucun libellé ne contient de secret.
- **Mise en forme** : `dart format` appliqué en entier seulement aux fichiers qui étaient déjà au format ; ailleurs, seuls les blocs modifiés sont indentés à la main.

Non vérifié : pas d'essai avec TalkBack sur un téléphone (règle : pas de `flutter run`). Feuilles du bas, boîtes de dialogue et écrans d'Android hors du test automatique. Voir « Limites » dans ACCESSIBILITE.md.

## Tuile Paramètres rapides « Pare-feu Sentinel » (2026-10-27)

Choix faits sans demander :

- **Logique pure à part** : `FirewallTilePolicy` (`firewall/FirewallTilePolicy.kt`) décide quoi faire d'un appui (démarrer, arrêter, ouvrir l'app) et quoi afficher, sans Android. Testée par `FirewallTilePolicyTest` (8 tests, dont « l'affichage annonce toujours ce que fera l'appui » sur les 8 combinaisons).
- **Ordre des règles** : pare-feu actif → l'appui coupe, toujours (même avec un DNS privé strict ou une autorisation retirée : couper ne doit jamais échouer). Sinon, autorisation VPN manquante → ouvrir l'app (seule l'app peut afficher la demande d'Android). Sinon, DNS privé strict (SEN-11) → ouvrir l'app (démarrer filtrerait du vide). Sinon → démarrer.
- **« Autorisation VPN »** = `VpnService.prepare()` renvoie null. Il renvoie aussi une demande quand un autre VPN a pris la place : la tuile ouvre alors l'app, qui refait la demande.
- **Petite ligne sous le nom** (Android 10+) : « Actif », « Inactif », « Autorisation à donner » ou « DNS privé strict ». Elle dit pourquoi l'app va s'ouvrir. Textes en français, anglais et arabe (`tile_*` dans les trois `strings.xml`), dans la langue choisie dans Réglages (`AppLanguage.localized`), comme la notification du VPN.
- **Écran verrouillé** : `unlockAndRun` avant tout appui. Sinon, quelqu'un qui tient le téléphone verrouillé pourrait couper la protection.
- **Synchronisation** : tuile en mode normal (pas « active »), donc relue à chaque ouverture du panneau. En plus, `SentinelVpnService` appelle `FirewallTileService.refresh()` au démarrage et à l'arrêt (y compris un autre VPN qui prend la place). Si le panneau est ouvert, la tuile se met à jour tout de suite. Sinon : `requestListeningState`.
- **Android 14+** : `startActivityAndCollapse(PendingIntent)` (PendingIntent immuable). Avant 14 : la version avec Intent, seule disponible.
- **Démarrage refusé par Android** (règles des services au premier plan lancés en arrière-plan, Android 12+) : l'exception est attrapée et la tuile ouvre l'écran du pare-feu, au lieu d'échouer en silence. Je ne suis pas sûr qu'un appui sur une tuile compte toujours comme une action de l'utilisateur chez tous les fabricants : d'où ce repli.
- **Ouvrir l'écran du pare-feu** : Intent explicite vers `MainActivity`, action `com.iheb.sentinel.action.OPEN_FIREWALL` (constante dans `IncomingText.kt`), sans intent-filter : la liste des actions de `MainActivity` vérifiée par `ManifestTest` ne change pas. `MainActivity` est exportée, donc une autre app peut envoyer cette action. Elle n'ouvre qu'un écran, sans données, et ne démarre rien : sans risque.
- **Côté Dart** : canal existant `com.iheb.sentinel/share` (`getInitialOpenFirewall` au lancement, `onOpenFirewall` app ouverte), plutôt qu'un nouveau canal. `ShareService.firewallRequests` compte les demandes. `MainShell` revient à l'accueil, referme les écrans ouverts et pousse `FirewallScreen` (une seule fois, même après deux appuis). Au premier lancement, la présentation passe d'abord, puis l'écran du pare-feu s'ouvre.
- **Manifeste** : service exporté protégé par `BIND_QUICK_SETTINGS_TILE` (seul le panneau d'Android s'y connecte), icône `@drawable/ic_stat_arch`, nom `@string/tile_label`. `ManifestTest` vérifie la permission, l'action `QS_TILE` et l'icône.
- **Petite correction en passant** : `ShareService.start()` s'arrête si l'écran est fermé pendant l'attente (sinon la deuxième question à Android touchait un objet fermé).

Non vérifié : la tuile n'a pas été essayée sur un téléphone (règle : pas de `flutter run`). À tester à la main : ajout de la tuile dans le panneau, appui écran verrouillé, démarrage depuis la tuile sur Android 12, 13, 14 et 15 (repli vers l'app si Android refuse), mise à jour quand on coupe depuis la notification.

## Arabe : mots latins isolés, et réveil du serveur de signalement (2026-11-15)

Choix faits sans demander :

**1. Mots latins dans les phrases arabes**

- **Isolement Unicode dans `app_ar.arb`** : chaque morceau latin écrit en dur (Sentinel, DNS, Wi-Fi, `.sentinel`, `raw.githubusercontent.com`, `http`/`https`…) est entouré de LRI…PDI (toujours de gauche à droite). Chaque valeur insérée qui peut être latine (`{host}`, `{brand}`, `{word}`, `{app}`, `{domain}`, `{url}`, `{number}`, `{title}`…) est entourée de FSI…PDI (le sens suit sa première lettre : un nom d'app en arabe reste correct). `.{tld}` est isolé avec son point : « .xyz » ne devient plus « xyz. ». 170 textes changés par un petit script, pas à la main. Le fichier écrit les caractères en `\u2066`/`\u2068`/`\u2069`, jamais tels quels.
- **Pourquoi les guillemets se mélangeaient** : entre deux mots latins, « », « » et la virgule arabe « ، » sont neutres et prenaient le sens latin. Isoler le mot *dans* ses guillemets suffit.
- **Français et anglais inchangés** : pas de problème d'ordre en gauche-à-droite pour des mots latins ; moins de risque de casser les tests et les recherches de texte.
- **Pluriels (`plural`) non touchés** : aucun ne contient de mot latin.
- **Écrans** : nouveau `lib/utils/bidi.dart` (`bidiIsolate`, `ltrIsolate`, `directionOf`, `pageStart`). Liste de titres du coffre (« Utilisé aussi pour : ») : chaque titre isolé avant d'être joint par « ، ». Domaines seuls (rapport d'analyse, liste blanche, sources) : `textDirection: ltr` mais alignés au début de la page (à droite en arabe). Contenu brut du QR et valeurs (numéro « +216… ») : sens selon la première lettre, sans caractère caché (la copie du texte reste fidèle).
- **Contrôles de sens venus d'ailleurs** retirés par `bidiIsolate` (un PDI glissé dans un nom fermerait l'isolement trop tôt).
- **Notifications Android** (`values-ar/strings.xml`) : `%1$s` / `%2$s` (domaine bloqué, marque, app analysée) isolés aussi.
- **Fichiers générés** : `l10n.yaml` ajoute un `header` qui permet ces caractères dans `app_localizations_*.dart` (lint `text_direction_code_point_in_literal`) ; le lint reste actif partout ailleurs (SEN-12).
- **Tests** : `test/arabic_bidi_test.dart` mesure la position de chaque caractère à l'écran (« .xyz », « payez », « code », « appelez », « poste-tn-livraison.xyz », « (http بدلًا من https) », titres latins, « +216 »), plus un garde-fou : aucun mot latin hors isolement dans `app_ar.arb`. Vérifié que les anciens textes échouaient pour « .xyz » et les mots entre guillemets. Pour « (http…) » et le domaine seul, le moteur de test affichait déjà l'ancien texte dans le bon ordre (largeurs 250 à 700 dp) : je n'ai pas reproduit le défaut vu sur le téléphone, l'isolement le prévient quand même.

**2. Serveur endormi (Render gratuit)**

- **Délai d'envoi : 60 s** (au lieu de 10 s), constante `ReportClient.defaultTimeout`.
- **Message après 4 s** (`defaultSlowAfter`) : « Réveil du serveur, patientez… (jusqu'à une minute) », visible sous la barre et annoncé par TalkBack. 4 s : une réponse normale arrive en moins d'une seconde, un réveil prend 30 à 60 s.
- **« Réessayer »** : le bouton « Envoyer » change de nom après une erreur de réseau, de délai ou du serveur (`ReportException.canRetry`). Pas de deuxième bouton qui ferait la même chose. Après « trop de signalements » ou « refusé », il garde son nom : réessayer tel quel ne servirait à rien.
- **Pas de renvoi automatique** : une requête par appui ; le bouton est désactivé pendant l'envoi (pas de double appui). Si un envoi a abouti côté serveur après le délai, le serveur ignore le doublon. Le compteur local (5 par heure) ne compte que les succès.
- **Message de délai** réécrit : « Le serveur ne répond pas, même après une minute. Réessayez dans un moment. »
- **Tests** : client (60 s par défaut, une seule requête après un délai dépassé, `onSlow` appelé une fois si lent, jamais si la réponse ou l'échec est rapide, `canRetry`) et écran (message après quelques secondes puis succès à 40 s, erreur à 60 s puis « Réessayer » qui renvoie, aucun renvoi pendant 3 min, textes en arabe et en anglais).

Non vérifié : pas essayé sur un téléphone (règle : pas de `flutter run`). À regarder : rendu des phrases arabes avec Readex Pro sur l'appareil, notifications en arabe, premier signalement après une longue pause du serveur.

## Accès sensibles : caméra, micro, localisation (2026-11-15)

### Ce que dit la doc Android (vérifié sur developer.android.com)

- **Aucune API publique ne donne l'historique caméra / micro / localisation des autres apps.** La page `AppOpsManager` le dit : « The tracked data can only be read by system components ». `getHistoricalOps` / `getPackagesForOps` sont des API système (`GET_APP_OPS_STATS`, réservée au système). `isOpActive` et `startWatchingActive` (Android 11) exigent `WATCH_APPOPS` pour les autres apps (réservée au système) ; sans elle, seulement Sentinel. `setOnOpNotedCallback` : seulement les accès de Sentinel elle-même. `unsafeCheckOpNoThrow` : l'état d'une autorisation, pas son usage.
- **Le tableau de bord de confidentialité (Android 12+)** a bien cet historique (frise caméra / micro / localisation), mais il est lu par le système seul. Une app peut seulement l'ouvrir, et encore : l'action `REVIEW_PERMISSION_USAGE` n'est pas garantie par la doc publique.
- **`UsageStatsManager`** (autorisation spéciale « Accès aux données d'utilisation », `PACKAGE_USAGE_STATS`, pas une permission dangereuse, accordée par l'utilisateur dans les réglages) donne les moments où chaque app était ouverte (`ACTIVITY_RESUMED / PAUSED / STOPPED`, Android 10+ ; `MOVE_TO_FOREGROUND / BACKGROUND` avant, mêmes valeurs) et, à partir d'Android 10, ses services au premier plan (`FOREGROUND_SERVICE_START / STOP`). **Aucun événement caméra / micro / localisation**, et le service ne dit pas son type.
- Temps réel (`CameraManager.AvailabilityCallback`, `AudioManager.getActiveRecordingConfigurations`) : dit « caméra / micro occupés » sans dire par qui, et n'existe que si Sentinel tourne en permanence et tient son propre journal. Écarté : la consigne interdit de stocker plus que ce que fournit Android.

### Ce qui est fait (choix)

- **Approche honnête** : on croise les autorisations accordées (PackageManager : `CAMERA`, `RECORD_AUDIO`, localisation fine / approximative, `ACCESS_BACKGROUND_LOCATION`) avec les moments d'activité (UsageStatsManager, 7 jours). L'écran parle de « moments où l'app pouvait s'en servir », jamais d'accès prouvés, et le dit en clair (texte `accessLimit`, sur l'explication, la liste et le détail). Lien vers le tableau de bord d'Android pour l'historique exact.
- **Par version d'Android** : 7 à 9 (minSdk 24) : seulement les moments où l'app était ouverte ; localisation accordée = aussi en arrière-plan (pas de distinction avant Android 10). 10+ : aussi l'arrière-plan (services au premier plan) et la localisation « toujours ». 12+ : lien direct vers le tableau de bord (sinon Réglages › Confidentialité, sinon Réglages). Android garde ces événements quelques jours seulement selon les téléphones : dit à l'écran (`accessRetention`).
- **Autorisation demandée seulement à l'ouverture de la fonction**, après une page d'explication (ce qui est lu, pourquoi, tout reste sur le téléphone, la limite d'Android). Rien n'est demandé tant que l'utilisateur n'appuie pas sur « Ouvrir les réglages ». Au retour dans l'app, nouvelle vérification ; si l'interrupteur n'est pas activé, une phrase le dit. Lien « Retirer l'accès » en bas de la liste.
- **Place : onglet Applications**, une ligne « Accès sensibles » sous le titre, visible avant et après l'analyse. Raison : c'est une question sur les apps, et le détail renvoie à l'analyse d'app existante ; l'accueil est réservé au score et aux actions qui rapportent des points (cette fonction n'en donne pas).
- **Liste** : icône, nom, accès autorisés (« Caméra · Micro »), dernière activité, « N fois en 24 h · N fois en 7 jours », repères « La nuit (0 h – 6 h) », « En arrière-plan », « Localisation autorisée en permanence ». Deux sections : « À regarder » (inhabituelles) puis « Autres applications ». Apps système cachées par défaut (même interrupteur que l'onglet). Apps sans activité sur 7 jours masquées, sauf localisation « toujours » (elle peut servir sans aucun événement visible).
- **Détail** : comptes 24 h / 7 jours, raisons, tous les moments (date, heures, ouverte / arrière-plan, nuit). Boutons « Gérer les autorisations » (page Infos sur l'appli d'Android, comme l'analyse d'app) et « Voir l'analyse de l'app » (nouvelle méthode Kotlin `scanApp` : une seule app au lieu de tout rescanner, puis `calculateAppRisk` et l'écran de détail existant).
- **« Inhabituel » (Dart pur, `lib/services/sensitive_access.dart`)** : activité entre 0 h et 6 h (heure du téléphone), ou activité en arrière-plan alors que caméra ou micro est autorisé (Android 11+ exige un service au premier plan pour s'en servir hors écran). L'arrière-plan avec la localisation seule (GPS, sport) n'est pas inhabituel, il est seulement signalé. Tri : plus de raisons d'abord, puis activité la plus récente, puis nom. Moments séparés de moins d'une minute fusionnés (changements d'écran dans l'app).
- **Rien n'est stocké** : Kotlin lit à chaque ouverture et renvoie les faits bruts (heures et codes d'événements en `LongArray` / `IntArray`) ; Dart calcule en mémoire. Aucun fichier, aucune préférence, rien d'envoyé.
- **Code** : `SensitiveAccessReader.kt` (lecture), `UsageEventCodes` (traduction des événements, testée en JUnit avec les vraies constantes Android), `AppIcons.kt` (icône PNG partagée avec le scanner d'apps), `AppIcon.bytes` côté Flutter. `ManifestTest` vérifie que `PACKAGE_USAGE_STATS` est déclarée et qu'aucune permission micro / localisation / téléphone / contacts n'a été ajoutée.
- **Textes** : 38 clés `access…` en fr / en / ar (Sentinel isolé en arabe, pluriels arabes complets pour « مرة »). « Gérer les autorisations » réutilise `detailManagePermissions`.
- **Tests** : `test/sensitive_access_test.dart` (nuit, fusion, pause + arrêt, app déjà ouverte au début, service hors écran, services imbriqués, désordre, coupure à 7 jours, comptes, raisons, tri, lecture de la Map), `test/sensitive_access_screen_test.dart` (rien demandé avant le bouton, inhabituelles en premier, détail, arabe), `UsageEventCodesTest.kt`.

Non vérifié : pas essayé sur un téléphone (règle : pas de `flutter run`). À regarder : page « Accès aux données d'utilisation » ouverte directement sur Sentinel selon les fabricants (sinon la liste), action du tableau de bord sur Samsung / Xiaomi, quantité d'événements réellement gardée par Android selon les téléphones, et déclaration Play Console pour `PACKAGE_USAGE_STATS` si l'app est publiée.

## Documents chiffrés dans le coffre (2026-11-15)

Choix faits sans demander :

- **Nouveau type d'élément `document`** (`VaultItemType.document`) : titre, note, `mime` et `taille` dans la liste chiffrée habituelle ; le contenu est dans un fichier à part. Types acceptés, vérifiés sur les premiers octets (on ne croit pas le sélecteur) : JPEG, PNG, WebP, PDF. Limite : **10 Mo** après recompression.
- **Un fichier chiffré par document** : `vault_docs/<id>.bin` dans le dossier privé de l'app (le même que `vault.json`). Format : `SDOC` + version (1) + nonce de 12 octets + chiffré AES-256-GCM + tag. Clé = DEK du coffre, **AAD = id du document** (un fichier échangé avec un autre ne se déchiffre plus), nonce aléatoire neuf à chaque écriture. Écriture atomique (`.tmp` puis renommage) : le temporaire est déjà chiffré. Chiffrement dans un isolate (un PDF de 10 Mo ne fige pas l'écran). Code : `lib/services/vault/vault_documents.dart`, `encryptDocument` / `decryptDocument` dans `vault_crypto.dart`.
- **Id sûr** (`isSafeDocumentId` : lettres, chiffres, `_`, `-`, 64 max) : l'id devient un nom de fichier et peut venir d'une sauvegarde importée, donc jamais de `../`.
- **Ordre des écritures** : ajout = fichier chiffré puis élément (en cas d'échec, le fichier est effacé) ; suppression = élément retiré puis fichier effacé. Un fichier resté orphelin (app tuée au milieu) est effacé à la prochaine ouverture du coffre. Supprimer ou recréer le coffre efface tout le dossier `vault_docs`.
- **Photo** : appareil photo d'Android (`ACTION_IMAGE_CAPTURE`) plutôt qu'une caméra intégrée (CameraX = nouvelle dépendance). Limite connue : l'appareil photo doit écrire dans un fichier ; il écrit dans `cache/vault_capture/photo.jpg` (FileProvider limité à ce dossier), que Sentinel lit puis **efface aussitôt**, et ce dossier est vidé à chaque démarrage (photo restée après un arrêt brutal). Certaines apps photo gardent aussi leur propre copie dans la galerie : hors de notre contrôle. La caméra est déjà déclarée dans le manifeste (QR) : Android exige alors l'autorisation, demandée au moment de la photo.
- **Image ou PDF existant** : sélecteur d'Android (`ACTION_OPEN_DOCUMENT`, types `image/*` et `application/pdf`), **aucune permission de stockage** ; lu directement en mémoire (40 Mo lus au plus avant recompression).
- **Recompression** (Kotlin, `VaultMedia.kt` + `VaultMediaPolicy.kt`) : une image de plus de 2 Mo, de plus de 2560 px ou d'un autre format (HEIC…) est réduite à 2560 px de côté, tournée selon l'EXIF, posée sur fond blanc et réenregistrée en JPEG (qualité 85, puis 70, puis 55 si besoin). Effet voulu : les métadonnées (position GPS…) disparaissent. Une image légère est gardée telle quelle. Les PDF ne sont jamais modifiés (refusés au-delà de 10 Mo).
- **Affichage** : seulement coffre ouvert, déchiffré en mémoire, FLAG_SECURE (déjà posé par l'onglet Coffre, reposé par l'écran). Image : `Image.memory`, zoom plein écran. PDF : `PdfRenderer` d'Android sur un **fichier anonyme en mémoire** (`memfd`, Android 11+), page par page en PNG. Avant Android 11, PdfRenderer exigerait un vrai fichier : on affiche « Aperçu impossible » (le partage reste possible). Même message pour un PDF protégé par mot de passe. En quittant l'écran : images retirées du cache de Flutter, octets remis à zéro, PDF fermé. L'écran se ferme au verrouillage.
- **Partage** : bouton « Partager » + avertissement (le document sort du coffre sans chiffrement). Pas de fichier temporaire : un `ContentProvider` non exporté (`VaultShareProvider.kt`) sert les octets **depuis la mémoire** à travers un tube, à la seule app choisie (permission d'URI accordée par Android). URI avec jeton aléatoire, nom neutre `sentinel-document.pdf` / `.jpg` (jamais le titre). Les octets sont effacés au verrouillage du coffre. Limite : une app qui lit le document tard (après verrouillage) ne le trouve plus.
- **Verrouillage pendant la photo / le sélecteur** (plus de 30 s dehors) : le coffre se verrouille comme avant et le fichier pris est oublié (remis à zéro), rien n'est enregistré.
- **Sauvegarde `.sentinel` version 2** : même en-tête (format, version, kdf) ; nouveau champ `documents` = liste `{id, nonce, chiffre}`, chaque document chiffré avec la clé d'export, AAD = en-tête + octet 0 + id. Le contenu de `data` (la liste des éléments) ne change pas. Les fichiers **version 1 restent lus** (sans documents) ; un export est toujours écrit en version 2 (une ancienne version de Sentinel répond alors « faite par une version plus récente »). Import : chaque document de la liste doit avoir son contenu intact, sinon fichier refusé (« illisible »). Restauration : documents rechiffrés avec la nouvelle DEK avant l'écriture du coffre. Taille maximale d'une sauvegarde portée de 16 à **128 Mo** (une dizaine de documents de 10 Mo, base64 compris). Tout passe en mémoire : sur un petit téléphone, une très grosse sauvegarde peut manquer de mémoire.
- **Windows** : pas de sélecteur ni d'appareil photo, le type « Document » n'est pas proposé.
- **Arabe** : « PDF » et « Sentinel » isolés (`⁦…⁩`), comme l'exige `arabic_bidi_test.dart`.
- **Tests ajoutés** : `test/vault_documents_test.dart` (type détecté, aller-retour, nonces neufs, octet / tag / nonce / en-tête modifiés, fichier tronqué ou échangé, mauvaise clé, id dangereux, lecture refusée coffre verrouillé, trop gros / mauvais type, suppression, renommage, orphelins, suppression du coffre, export v2 / import, sauvegarde altérée ou incomplète, ancien export v1, restauration sur un « autre téléphone », aucun fichier en clair ni temporaire restant) ; `VaultMediaPolicyTest.kt` (règles de recompression, PDF, nom de partage, fournisseurs non exportés, aucune permission de stockage).

Non vérifié : l'interface n'a pas été lancée sur un téléphone (règle : pas de `flutter run`). À essayer à la main : photo avec plusieurs apps d'appareil photo (Samsung, Xiaomi, Pixel), rotation des photos, aperçu des PDF (multi-pages, Android 10 et 11+), partage vers WhatsApp / Gmail / Drive (certaines apps veulent un fichier « seekable » et pourraient refuser un tube), et une sauvegarde lourde sur un téléphone d'entrée de gamme.

## Bilan de la semaine (2026-11-16)

### Ce que dit la doc Android (vérifié sur developer.android.com)

- WorkManager est recommandé pour le travail persistant ; dernière version stable 2.12.0 (23/09/2026), minSdk 24, compileSdk 33+. Il s'appuie sur JobScheduler (API 23+).
- `JobInfo.Builder.setPersisted(true)` garde la tâche après un redémarrage et exige `RECEIVE_BOOT_COMPLETED` (déjà déclarée). Période minimale 15 min ; garder un `jobId` fixe entre les mises à jour.

### Choix faits sans demander

- **JobScheduler directement, pas WorkManager** : c'est ce que WorkManager utilise en dessous sur notre minSdk (24). Aucune nouvelle dépendance (WorkManager tire Room/SQLite, initialiseur au démarrage…), cohérent avec la politique « peu de dépendances » de l'app. Tâche **quotidienne** (`setPeriodic(1 jour, flex 6 h)`, persistée), pas hebdomadaire : plus robuste au mode Doze ; elle décide seule si c'est le moment.
- **La tâche n'existe que si elle a du travail** : notification activée, ou des semaines enregistrées à effacer. Sinon elle s'annule. Pas de service permanent.
- **Stockage côté Kotlin** (`weekly/WeeklyStatsStore.kt`, SharedPreferences privées, déjà exclues des sauvegardes) : le pare-feu et la protection automatique comptent sans moteur Flutter. Dart envoie ses compteurs par le canal `com.iheb.sentinel/weekly`.
- **Liste fermée de clés** (`WeeklyLedger.COUNTERS` / `GAUGES`) : toute autre clé est refusée, côté canal comme à la lecture du fichier. Impossible d'y glisser un domaine, un texte ou un nom de Wi-Fi.
- **Ce qui est compté** :
  - requêtes bloquées par catégorie (malware, imitations, traqueurs, pubs) : catégorie seulement, écritures groupées toutes les 30 s (et à l'arrêt du VPN) ; on peut perdre jusqu'à 30 s de compteurs si Android tue l'app ;
  - messages analysés : analyse manuelle (onglet Messages) + protection automatique ; le scan de QR code n'est pas compté ;
  - alertes d'arnaque : verdict « Arnaque probable » (manuel ou automatique), même si Android bloque l'affichage de la notification ;
  - score : premier et dernier score calculés dans la semaine (à chaque audit de l'accueil) ;
  - apps à risque : dernière valeur vue (apps « modéré » ou « élevé » au dernier scan de l'onglet Applications) ;
  - mots de passe : dernières valeurs vues (faibles, réutilisés, trouvés dans des fuites) quand le coffre est ouvert. « – » si pas mesuré cette semaine.
- **Semaine** = du lundi au dimanche, heure locale. **Effacement** : on garde la semaine en cours + les 7 précédentes (8 semaines) ; les semaines plus anciennes, vides ou « du futur » (horloge changée) sont supprimées à chaque lecture/écriture et par la tâche quotidienne.
- **Notification** désactivée par défaut, réglage « Notification du bilan » dans Réglages (demande l'autorisation Android 13+ au moment d'activer ; refus → reste désactivée). Envoyée le lundi à partir de 9 h, une fois par semaine, seulement si la semaine passée a des données ; pas d'envoi immédiat pour la semaine en cours au moment d'activer. Texte neutre, sans aucun chiffre (« Votre bilan de la semaine est prêt »), même version sur l'écran verrouillé ; canal à importance basse (sans son). Le tap ouvre simplement Sentinel (accueil), pas directement l'écran Bilan : plus simple, rien à transmettre.
- **Écran** : entrée « Bilan de la semaine » en bas de l'accueil (Android seulement), arche du score de fin de semaine, évolution du score, tableau sobre à deux colonnes (cette semaine / semaine d'avant) avec traits fins, note de confidentialité.

### Tests

- Kotlin (`WeeklyLedgerTest`, 10 tests) : début de semaine (fuseau, avant 1970), addition des compteurs, refus des clés inconnues, score début/fin, jauges, effacement après 8 semaines, JSON, décision de notification.
- Dart (`test/weekly_report_test.dart`) : lecture des données, clés envoyées au canal, écran (fr/ar, arche vide, hors Android), réglage (activation, refus, ligne masquée).

Non vérifié : pas essayé sur un téléphone (règle : pas de `flutter run`). À regarder : déclenchement réel de la tâche quotidienne (Doze, fabricants agressifs type Xiaomi), notification du lundi, compteurs du pare-feu après une longue session VPN. La politique de confidentialité in-app ne mentionne pas encore ce bilan local : à ajouter si souhaité.

## Réentraînement sûr de l'IA anti-arnaque (2026-11-16)

### Choix faits sans demander

- **`ml/retrain.py` réutilise `train.py`** : même recette (TF-IDF char_wb 2-5 + régression logistique, C par validation croisée). `train.py` a seulement été découpé en fonctions (`build_export`, `write_model`, `write_parity`) ; vérifié : modèle et fixtures identiques octet pour octet hors `version`/`date`.
- **Test réel figé** = `ml/data/test_reel_fige.csv`, 30 % des messages réels (stratifié par label, `random_state=42`, une seule copie par forme « canonique »). Créé seulement à partir de 20 messages réels dont 4 de chaque label ; avant, la porte de qualité se rabat sur le test synthétique (dit dans le rapport). Jamais réécrit ensuite ; on le supprime à la main pour le refaire. Il est écrit même en mode `--essai` (il ne touche pas au modèle).
- **Pas de fuite** : sont exclus de l'entraînement les messages du test figé, leurs copies « canoniques » (nettoyage SEN-12, minuscules, chiffres → 0, espaces réduits) et leurs quasi-copies (similarité cosinus ≥ 0,9 sur n-grammes 3-5). Le test synthétique = même découpage 80/20 que `train.py` sur le seed seul, donc identique à celui du modèle livré tant que `messages_perso.csv` est vide.
- **Modèle livré** évalué depuis son JSON avec `reference_predict()` (le calcul exact de l'app), avec son propre seuil.
- **Porte de qualité** (comparaison en nombres, pas en pourcentages) : arnaques détectées ≥ modèle livré ; fausses alertes sur normaux ≤ modèle livré (test réel figé, sinon synthétique, critère par critère) ; garde-fou ajouté : F1 synthétique sans baisse de plus de 0,05. Pas de modèle livré → le candidat est accepté.
- **Après export** : si l'écart de la spécification Python dépasse 1e-12 ou si `flutter test test/phishing_parity_test.dart` échoue (ou flutter introuvable), les anciens fichiers sont remis et le rapport le dit.
- **Empoisonnement** (sur réels + test figé) : quasi-doublons à labels opposés → signalés et **écartés de l'entraînement** (pas seulement signalés : plus sûr) ; groupes de quasi-copies ≥ 3 et ≥ 10 % ; domaines dans ≥ 3 messages et ≥ 15 % ; sources > 50 % (seulement s'il y a au moins 2 valeurs de `source` : aujourd'hui `review.py` écrit toujours « reel »).
- **Rapport** `ml/reports/AAAA-MM-JJ.md` (suffixe `-2`, `-3` si plusieurs le même jour), CRLF, avec lexique. Il cite des extraits de messages réels (déjà anonymisés dans le CSV versionné) pour les contradictions.
- `pytest==9.2.0` dans `ml/requirements-dev.txt` (installé dans `ml/.venv`).

### Vérifié

- 16 tests pytest (`ml/tests/`, données factices aléatoires à graine fixe, aucune base) : jeu figé créé une fois, jamais dans l'entraînement, contradictions / domaines / sources, porte de qualité, pipeline complet (premier export puis données empoisonnées refusées sans rien toucher), mode `--essai`, échec flutter → restauration.
- Lancement complet réel sur les CSV locaux (perso vide) : candidat accepté, export, `flutter test` parité OK (52 tests) ; puis modèle et fixtures **remis** à la version livrée (le candidat était identique hors version). Le rapport commité est celui du mode `--essai`.

Limite : un candidat identique au modèle livré est quand même réexporté (nouvelle `version`). Aucune connexion à Neon : les données réelles arrivent toujours par `backend/tools/review.py export`.

## Refonte du design 1.1.0 (2026-11-19)

### Blocage : émulateur indisponible

- L'émulateur Pixel 8 refuse de démarrer : « x86_64 emulation currently requires hardware acceleration », la virtualisation du poste est réservée à un autre outil, et aucun téléphone n'était branché. La configuration du poste n'a pas été modifiée.
- **Contournement** plutôt qu'arrêt : les écrans sont rendus par le moteur de Flutter dans un test (`test/design/screens_capture_test.dart`), au format exact du Pixel 8 (1080 × 2400, densité 2,625), avec les vraies polices et un faux Android aux données fictives. Les captures « avant », « après » et celles du README en sortent.
- Conséquences : la barre d'état (10:00, batterie pleine) est **dessinée** par le banc de capture, au lieu du mode démo Android. Le passage réel sur téléphone reste à faire à la main (voir la fin de cette section).
- Lancer le banc : `$env:SENTINEL_CAPTURE="C:\dossier"; flutter test test/design/screens_capture_test.dart` (options dans l'en-tête du fichier). Sans cette variable, ses tests sont ignorés.

### Choix faits sans demander

- Pour pouvoir capturer les onglets avec la vraie barre de navigation : `MainShell` accepte `initialIndex` et `vaultBuilder`, `VaultScreen` accepte `session` et `breaches` (même modèle que `LinksScreen`, « remplacés dans les tests »). Comportement inchangé dans l'app.
- `VaultScreen` ne relit plus une session déjà chargée (`status != chargement`) : sans effet dans l'app (session toujours neuve), utile pour les tests.
- **Jetons** : la marge de page passe de 28 à 24 dp et les paddings de ligne de 10/12/14 à 16 dp (échelle 4-8-12-16-24-32, plus 48 pour les grands vides). Tailles de texte ramenées à 9 (14 → 15, 17 → 18, 22 → 24). Remplacement fait par script, puis vérifié écran par écran sur les captures.
- **dart format** : appliqué seulement aux nouveaux fichiers ; les fichiers existants n'ont pas été reformatés en entier (certaines lignes avec `AppSpace.page` dépassent 80 colonnes, sans effet sur l'analyse).
- **Statuts** : `StatusLevel` (danger / avertissement / ok / neutre) donne couleur + icône Material (`gpp_bad`, `error_outline`, `verified_user`, `remove_circle_outline`). Niveau de risque des apps, Wi-Fi et santé des mots de passe passent en badge ; verdicts des liens et du QR Wi-Fi en `VerdictHeader` (petite arche teintée + icône + mot).
- **Accueil** : score → « Pour gagner des points » (triées par points décroissants) → « Vos protections » (Wi-Fi, pare-feu, bilan). Une seule clé ajoutée : `homeProtections` (fr « Vos protections », en « Your protections », ar « حماياتك »). « Rien à corriger » s'accompagne d'un petit brin de jasmin.
- **Animations** : arche en fondu (350 ms) puis remplissage (1,2 s au lieu de 1,4 s) ; fondu de 250 ms entre onglets ; transition douce entre écrans (fondu + 3 % de glissement). Toutes coupées par « Supprimer les animations » (`MediaQuery.disableAnimations`).
- **Dessins** : porte bleue (coffre vide, coffre verrouillé), fenêtre en moucharabieh avec brin de jasmin (applications), jasmin (rien à corriger). `CustomPainter`, couleurs du thème uniquement, ignorés par TalkBack.
- **Icône monochrome Android 13+** : déjà présente (`ic_launcher_monochrome`, générée par `tools/branding/make_icon.py`) et déclarée dans `mipmap-anydpi-v26/ic_launcher.xml` ; vérifiée visuellement, rien changé.
- **Bouton « Vérifier »** : reste actif-visible pendant la vérification avec un petit cercle (`PrimaryButton.busy`) au lieu de simplement se griser.
- **Tests golden** : `test/goldens/` (accueil, liens, coffre × français clair, français sombre, arabe clair), images de 412 × 914 dp. Rendues sous Windows : sur un autre système, de petites différences de rendu des polices peuvent les faire échouer (régénérer avec `--update-goldens`).
- **Garde-fous** (`test/design_system_test.dart`) : un test lit les sources des écrans et refuse toute taille de texte, marge, couleur, rayon ou durée d'animation en dur ; FLAG_SECURE du coffre vérifié (activé / retiré selon l'onglet) ; 4 onglets en arabe à 200 % sans débordement, clair et sombre.
- **README** : section « Preview » (anglais) et « Aperçu » (français), 7 captures en 1080 × 2400. Le coffre y est montré grâce au rendu Flutter (sur un vrai téléphone, FLAG_SECURE donne une image noire).

À faire à la main sur un vrai téléphone ou un émulateur accéléré : parcourir les écrans (transitions, arche animée, « Supprimer les animations » dans Accessibilité), et éventuellement refaire les captures du README avec le mode démo Android (`adb shell settings put global sysui_demo_allowed 1`) si l'on préfère une vraie barre d'état.

## Scanner QR 1.2.0 : image, messageries, applis, contacts, Wi-Fi (2026-11-23)

Choix faits sans demander :

- **Bibliothèque de décodage** : la même que la caméra, ZXing core 3.5.3 (Apache 2.0), déjà dans `build.gradle.kts`. Aucune nouvelle bibliothèque, ni Dart ni Android (`androidx.activity` 1.13.0 était déjà tiré par Flutter ; il est maintenant déclaré pour le sélecteur de photos). Lecteurs combinés : `QRCodeMultiReader` + `GenericMultipleBarcodeReader(QRCodeReader)`, deux binariseurs, image inversée en second essai, `TRY_HARDER`. Au plus 10 QR codes gardés.
- **Sélecteur de photos** : doc officielle vérifiée (developer.android.com/training/data-storage/shared/photopicker). `ActivityResultContracts.PickVisualMedia` (images seulement) utilisé sans `registerForActivityResult` (`FlutterActivity` n'est pas une `ComponentActivity`) : `createIntent` + `startActivityForResult` + `parseResult`, code de requête 10. Android 11+ (mises à jour système) : sélecteur de photos ; Android 4.4 à 10 : module Google Play s'il est installé (service `ModuleDependencies` du snippet officiel, désactivé et non exporté) ; sinon `ACTION_OPEN_DOCUMENT`. Aucune permission dans les trois cas.
- **Image partagée** (`ACTION_SEND image/*`) : `<data android:mimeType="image/*"/>` ajouté au filtre SEND existant (aucune nouvelle action). Seules les adresses `content://` sont acceptées, et jamais une adresse de Sentinel elle-même (`com.iheb.sentinel.*`) : une autre app ne peut pas faire lire à Sentinel ses propres fichiers privés (documents du coffre). Si une image est partagée avec un texte, l'image l'emporte.
- **Mémoire** : image réduite pour que son grand côté tienne en 2048 px (second essai à 3072 px si rien n'est trouvé dans une grande photo), refus au-delà de 100 mégapixels, `OutOfMemoryError` → « Image trop grande ». Le bitmap est recyclé aussitôt ; seuls les textes décodés passent à Dart.
- **Images de test** : les tests unitaires Android compilent contre `android.jar`, sans `java.awt` ni `ImageIO`. J'ai écrit un petit lecteur/écrivain PNG en Kotlin pur (`TestImages.kt`, zlib + CRC32) et un générateur (`QrFixtures.kt`, ignoré par défaut). Images commitées dans `android/app/src/test/resources/qr/`. Pour les refaire, dans `android/` : `$env:SENTINEL_REGEN_QR_FIXTURES="1"; ./gradlew testDebugUnitTest --tests com.iheb.sentinel.QrFixtures`. Dart ne sait pas décoder un QR sans bibliothèque : le décodage d'images est testé côté Kotlin, l'affichage côté Dart avec un faux canal.
- **Architecture** : l'analyseur existant (`qr_content.dart` / `qr_safety.dart`) est étendu plutôt que remplacé (tests 1.1.0 conservés). Nouveaux fichiers purs : `qr_messaging.dart`, `qr_apps.dart`, `qr_cards.dart`, `phone_numbers.dart`, `scam_words.dart`, `wifi_share.dart`. `QrFinding` = avertissement + détail (marque, indicatif, mots trouvés) ; `QrKind` donne les 10 familles demandées (plus téléphone, SMS, paiement et lien dangereux, déjà là).
- **Verdicts choisis** :
  - Message pré-rempli avec mots d'arnaque → « Suspect ». Lien dans le message → vérifié comme dans l'onglet Liens (faux site → « Dangereux »).
  - Indicatifs, vus de Tunisie : +216 → rien ; pays proches ou de la diaspora (Maghreb, Égypte, Europe de l'Ouest, USA/Canada, Turquie, Golfe) → simple information « numéro étranger » ; autre pays → « Suspect » (« pays inattendu ») ; satellites et réseaux internationaux (+870, +881, +882, +883, +888, +979, +808) → « Suspect » (surtaxe). Liste dans `phone_numbers.dart`, facile à ajuster. Indicatif mis en évidence par un badge (vert Tunisie, gris étranger courant, ocre inattendu ou spécial).
  - Invitation dans un groupe → information (le verdict ne change pas).
  - Play Store : paquet officiel → information « Paquet officiel de WhatsApp » ; préfixe d'un éditeur officiel (`com.facebook.lite`, `com.google…`, `org.telegram…`) → jamais accusé ; version modifiée connue (`known_apps.dart`) → « Dangereux » ; imitation (nom d'appli connue dans le paquet, une lettre en plus ou en moins, sosies vv/rn/0/1) → « Suspect » sur une boutique contrôlée (Play, fabricant), « Dangereux » ailleurs. Noms trop génériques (« messenger ») ignorés pour éviter les fausses alertes. Paquets des banques tunisiennes encore inconnus (TODO de `known_apps.dart`) : pas d'accusation.
  - `.apk` direct (extension `.apk/.xapk/.apks/.apkm` ou `application/vnd.android.package-archive` dans l'adresse) → « Dangereux », bouton désactivé. `intent://` → « Dangereux » (déjà refusé avant). Sites d'APK (APKPure, APKMirror, Uptodown, Aptoide, APKCombo, F-Droid…) → « Suspect » ; boutiques des fabricants (Galaxy Store, AppGallery, GetApps, Amazon) → information.
  - vCard / MECARD : nom ou organisation qui cite une marque de `known_brands.json` ou une appli connue → « Suspect » ; « service client », « support », « banque », « خدمة الحرفاء »… sans marque → « Suspect ». Une vraie fiche de conseiller bancaire est donc signalée aussi : c'est voulu, le message dit de vérifier le numéro sur le site officiel.
  - Cryptomonnaie : avertissement propre et verdict « Suspect » (avant : simple information « paiement »). Test 1.1.0 adapté.
- **Actions** : seuls les liens `https` (messagerie, Play Store, boutiques) peuvent être ouverts, après confirmation, par le canal `openLink` existant (Kotlin n'accepte toujours que `http(s)`). `viber://`, `tg://`, `whatsapp://`, `market://`, `mailto:`, `geo:` sont expliqués, jamais ouverts (aucune nouvelle surface côté Kotlin).
- **Mots d'arnaque** : liste courte et testée (français, anglais, arabe, derja en lettres arabes et latines), normalisation (minuscules, accents, voyelles arabes, أ/إ/آ → ا, ة → ه, ى → ي), préfixes arabes و/ف/ال. « QR code » et « code postal » ne déclenchent rien. Les mots affichés sont les formes normalisées (sans accent).
- **Conseil « quishing »** : 4 phrases, compteur en mémoire seulement (rien d'enregistré), uniquement après un scan à la caméra (pas pour une image).
- **Partager mon Wi-Fi** : QR créé par ZXing côté Kotlin (méthode `encodeQr`, même bibliothèque, pas de paquet Dart `qr`), dessiné par un `CustomPainter`, toujours sombre sur clair (palette claire même en thème sombre : les appareils photo lisent mal un QR inversé). `FLAG_SECURE` via `VaultPlatform.setSecure` (le coffre n'est jamais visible en même temps). Vérification : WPA de 8 à 63 caractères (ou 64 hexadécimaux), WEP de 5 ou 13 caractères (ou 10 ou 26 hexadécimaux). Champs sans suggestions ni apprentissage du clavier ; mot de passe masqué par défaut et jamais réaffiché sur l'écran du QR. Accès : nouvelle ligne de l'onglet Liens.
- **Composant commun modifié** : `StatusBadge` laisse son libellé passer à la ligne (`Flexible`) au lieu de déborder. Sans effet sur les captures golden.
- **Correction trouvée en route** : un texte mal encodé (`%E0%A4`) levait une `FormatException` non attrapée dans `qr_content.dart` ; il reste maintenant tel quel.
- **Garde-fou permissions** : `checkPlayProtect*` écrit aussi la liste des permissions du manifeste fusionné dans son rapport ; `ManifestTest` exige exactement la liste attendue (toute nouvelle permission, même venant d'une bibliothèque, fait échouer `testDebugUnitTest`). Test Dart équivalent sur le manifeste écrit à la main.
- **Textes** : 90 clés ajoutées dans les 3 langues ; mots latins de l'arabe isolés (LRI…PDI) comme le reste du fichier. À relire par un humain (arabe surtout : « خدمة الحرفاء », « ملغّمة »).
- **Commits** : un par grande partie. Les étapes intermédiaires ne compilent pas forcément seules (les textes et l'analyseur vont ensemble) ; le dernier commit est vérifié en entier.

Non vérifié : l'interface n'a pas été lancée (règle : pas de `flutter run`). Le sélecteur de photos, le partage d'une image depuis WhatsApp et l'affichage du QR Wi-Fi sont à tester à la main sur un émulateur ou un téléphone.

## Vitrine du dépôt pour la 1.2.0 (2026-11-23)

Choix faits sans demander :

- **Test réel et démo animée non faits** : aucun téléphone n'était connecté (`adb devices` vide) et aucun émulateur n'est utilisable sur ce poste. Le parcours sur appareil (sélecteur de photos, partage d'une image depuis WhatsApp, capture noire de « Partager mon Wi-Fi », arabe sombre) reste à faire à la main avant ou juste après la publication. Pas de GIF dans le README plutôt qu'un lien vide.
- **Captures** : les 7 captures de `docs/screenshots/` datent de la 1.1.0 (après le retrait de l'onglet Messages) ; aucune ne montre cet onglet, aucune ne contient de vraie donnée (applications et entrées du coffre fictives, adresses `exemple.tn`). Une seule ajoutée : `qr-apk.png` (résultat d'un QR code menant à un `.apk`), rendue par le même banc Flutter que les autres (`test/design/screens_capture_test.dart`, scène `qr-apk`), barre d'état dessinée (10:00, batterie pleine). Les captures de `docs/design/avant` et `apres` sont aussi postérieures au retrait de Messages.
- **README** refait en page de lancement (anglais principal, français identique) : promesse, badges (CI, dernière version via shields.io, licence, Android 7+, langues), gros bouton de téléchargement vers `releases/latest`, galerie de 7 captures, 6 fonctionnalités, vie privée en 3 points, sécurité (audit MASVS v2 : 18 constats, 15 corrigés, 3 acceptés ; empreinte du certificat ; SECURITY.md), schéma Mermaid, 5 décisions techniques, tests, « Expériences » (backend et ml, non utilisés), une phrase sur l'aide de Claude Code. Les anciennes listes détaillées (cryptographie du coffre, règles, couverture) restent dans `docs/SECURITY_DESIGN.md` et `docs/ARCHITECTURE.md`. Aucun lien interne cassé (vérifié par script, ancres comprises) ; aucune autre page ne pointait vers une ancre supprimée du README.
- **Image d'aperçu social** : `tools/branding/make_social_preview.py` (Pillow du venv `tools/.venv`), 1280 × 640, fond nuit de l'icône, arches en filigrane, nom, promesse en anglais, captures accueil et liens. Pas de texte arabe dans l'image : Pillow de ce venv n'a pas libraqm et n'aurait pas lié les lettres.
- **Notes de version** `docs/releases/v1.2.0.md` : français puis anglais, « remplace les versions précédentes », captures en liens `blob/v1.2.0/…?raw=true` (valides une fois le tag poussé), `À_REMPLIR` pour le SHA-256 de l'APK. CHANGELOG daté du 23/11/2026, liens de comparaison mis à jour.
- **Ménage** : ce journal porte maintenant un en-tête qui dit qu'il s'agit d'un historique ; `docs/DEPLOIEMENT.md` est marqué « expérience » et sa section « Et l'app ? » ne décrit plus l'option `-ApiUrl` retirée en 1.1.0 ; `docs/ARCHITECTURE.md` décrit le scanner 1.2.0. Les rapports d'audit et les anciennes notes de version gardent leurs mentions de Messages : ce sont des documents datés.
- **Gitleaks** : 8.21.2 téléchargé à part (somme de contrôle officielle vérifiée), historique complet scanné (85 commits). 3 alertes, toutes de faux secrets de tests (mot de passe Neon inventé, clé d'empreinte de test, clé de récupération inventée), ajoutées à `.gitleaksignore` avec leur explication ; nouveau scan : aucune fuite. Les autres alertes du dossier de travail sont dans des dossiers ignorés par git (`.venv`, `.audit_work`).
- **Petit défaut vu, non corrigé** (pas un bug, la consigne interdit de toucher au code sans bug réel) : sur un `.apk` direct, l'écran affiche « Dangereux » et aussi « Absent des listes de sites dangereux de Sentinel » (raison du vérificateur de liens). C'est exact mais peut surprendre ; à revoir dans une version suivante.
- `docs/releases/v1.1.0.md` avait une modification locale non commitée antérieure à ce travail (SHA-256 rempli, y compris dans le commentaire d'en-tête) : laissée telle quelle, hors commits.
