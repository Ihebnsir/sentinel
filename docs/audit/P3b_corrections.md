# Audit P3b : dernières corrections

| | |
|---|---|
| Base | P3a (`docs/audit/P3a_corrections.md`) |
| Constats traités | SEN-01, SEN-04, SEN-08, SEN-10, SEN-11 |
| Retest émulateur | `Sentinel_Audit_Root` (Android 17, root), APK **profile** obfusqué : même compilation AOT que la release ; signé avec la clé de debug, jamais distribué. La release attend la clé de publication. |
| Contrôles | `flutter analyze` sans problème ; `flutter test` **436 réussis** ; `./gradlew testDebugUnitTest` **125 tests, 0 échec** (1 ignoré : benchmark, ignoré exprès) ; `flutter build apk --debug` réussi |

## Résumé

| ID | Statut | Changement | Tests | Retest |
|---|---|---|---|---|
| SEN-01 | **Corrigé**, vérification `apksigner` en attente de la clé | Signature release lue dans `android/key.properties`, keystore hors du dépôt, build release bloqué sinon | build sans clé → échec ; keystore dans le dépôt → échec | `apksigner` dès que la clé existe (docs/RELEASE.md, §4) |
| SEN-04 | **Corrigé** | `tools/release/build_release.ps1` : `--obfuscate --split-debug-info=build/symbols`, symboles archivés hors du dépôt | script sans clé → refus | binaire : 1 chemin `package:sentinel/` (P1 : 71) |
| SEN-08 | **Corrigé** | AndroidX et coroutines relevés par contraintes Gradle | build + 125 JUnit + 436 Dart | OSV : 67 composants, 0 vulnérabilité |
| SEN-10 | **Corrigé** | DNS-over-TLS, repli DNS-over-HTTPS/2, jamais de clair sans accord, SERVFAIL et état visible | 24 JUnit (framing, choix, HTTP/2, vrai TLS) + 4 Dart | capture : 0 UDP 53 vers Quad9 |
| SEN-11 | **Corrigé** | Détection du DNS privé strict : activation bloquée avec explication, avertissement pendant | 2 Dart (dont l'écran réel) + 1 JUnit | strict → avertissement ; Automatique → disparu |

## SEN-10 · DNS amont chiffré

**Changement**
- `DnsFraming.kt` : longueur sur 2 octets (RFC 7858), lecture exacte, erreur si la connexion se coupe.
- `DnsTransports.kt` :
  - `TlsConnector` se connecte à **l'adresse IP** de Quad9 (`9.9.9.9`, puis `149.112.112.112`), donc sans résolution DNS. Le socket est lié puis **protégé par `protect()`** avant la connexion. SNI `dns.quad9.net`. Certificat vérifié par le magasin système, nom d'hôte vérifié deux fois (`endpointIdentificationAlgorithm = HTTPS` et `HostnameVerifier`). Délais : 3 s pour se connecter, 3 s pour lire.
  - `DotTransport` (port 853) et `DohTransport` (port 443) **réutilisent leurs connexions** (4 au plus au repos ; une connexion fermée par le serveur est remplacée une fois).
- `DohHttp.kt` : **HTTP/2** minimal (préface, SETTINGS, HEADERS HPACK littéraux sans Huffman, DATA, réponse aux PING et SETTINGS, erreur sur GOAWAY et RST_STREAM). Découverte pendant le retest : Quad9 répond `505 HTTP Version Not Supported` en HTTP/1.1, même annoncé par ALPN. Protocole validé contre le vrai Quad9 (`:status` indexé `0x88`, corps dans une trame DATA). ALPN `h2` : Android 10+ ; avant, seul le DoT est disponible.
- `UpstreamResolver.kt` : essaie DoT puis DoH ; un transport en panne passe en dernier pendant 5 min. Le transport **en clair n'est utilisé que si** `PlainDnsPermission` l'autorise pour le réseau courant. Sinon `resolve()` renvoie null et le service répond **SERVFAIL**.
- `UnderlyingNetworks.kt` : identifiant du réseau sous le VPN (sans permission de localisation). L'accord tombe si le réseau change, et n'est jamais enregistré sur le disque.
- Interface : section « Requêtes vers Quad9 » (Chiffré DoT / Chiffré DoH / injoignable / non chiffré autorisé). L'interrupteur « Autoriser le DNS non chiffré sur ce réseau » est **désactivé par défaut** et n'apparaît qu'en cas d'échec. La feuille d'activation dit désormais que les noms sont envoyés **chiffrés** à Quad9.

**Tests JUnit**
- `DnsFramingTest` (5) : gros-boutiste, lecture octet par octet, deux messages à la suite, connexion coupée, tailles refusées.
- `UpstreamResolverTest` (9) : DoT d'abord ; 853 bloqué → DoH ; certificat invalide → panne, sans clair ; tout en panne sans accord → jamais de clair (5 essais, 0 appel) ; clair seulement après accord et retour au chiffré ; réponse sans rapport avec la question refusée ; délai de reprise ; accord limité au réseau ; règle du DNS privé strict.
- `DohHttpTest` (7) : préface, HEADERS puis DATA, ACK des SETTINGS et PING, bourrage, flux étrangers ignorés, 500 / GOAWAY / RST / absence de corps refusés, Huffman refusé.
- `DotTransportTest` (3), **vrai TLS en local** (certificats créés par `keytool`) : certificat non approuvé refusé ; certificat approuvé mais pour un autre nom refusé ; bon certificat → échange réussi, une seule connexion pour deux requêtes, `protect()` appelé sur un socket déjà lié. Ce dernier point a été ajouté après un défaut trouvé à l'émulateur (protect() sur un socket non lié).

**Retest émulateur** (iptables par UID + tcpdump dans l'émulateur, `.audit_work/p3b/pcap/`)

| Situation | Affiché | Résolution | Réseau |
|---|---|---|---|
| Normal | « Chiffré (DNS-over-TLS) » | OK, traqueur bloqué | **0 UDP 53 vers Quad9** ; 2 connexions TLS 853, SNI `dns.quad9.net` |
| Port 853 bloqué | « Chiffré (DNS-over-HTTPS) » | OK | **0 UDP 53** ; 2 connexions TLS 443, SNI `dns.quad9.net`, ALPN `h2` |
| 853 et 443 bloqués | « Quad9 injoignable de façon chiffrée » + explication, interrupteur désactivé | échec | **0 UDP 53** ; réponses **SERVFAIL** dans le tunnel |
| Puis « Autoriser le DNS non chiffré » | « Non chiffré : autorisé sur ce réseau » | OK | UDP 53 vers 9.9.9.9 (accord explicite) |
| Ports débloqués, accord retiré | « Chiffré (DNS-over-TLS) » | OK | TLS 853 |

En P2, chaque nom visité partait en clair (`www.wikipedia.org`, `audit-visite-privee.example.com`…).

## SEN-11 · DNS privé strict

**Changement** : `UnderlyingNetworks.strictPrivateDnsServer()` lit `LinkProperties.getPrivateDnsServerName()` (Android 9+, non nul seulement en mode strict) sur les réseaux non-VPN.
- Avant l'activation : avertissement visible dans l'écran, et l'interrupteur ouvre un dialogue « DNS privé incompatible » avec « Ouvrir les réglages » ; le pare-feu **n'est pas activé**.
- Pendant : le même avertissement apparaît en haut de l'écran.

**Tests** : `dns_privacy_test.dart`, sur le **vrai** `FirewallScreen` avec canal simulé : avertissement affiché, dialogue, réglages ouverts, ni `prepare` ni `start` appelés. Plus `UpstreamResolverTest` (règle du nom de serveur).

**Retest émulateur** : DNS privé `dns.google` en strict → avertissement « Votre DNS privé est réglé sur « dns.google » (mode strict)… », l'interrupteur ouvre le dialogue, « Ouvrir les réglages » mène aux réglages réseau d'Android, `tun0` absent. Passage en Automatique → avertissement disparu, activation normale. Strict activé **pendant** le fonctionnement → avertissement affiché ; retour en Automatique → disparu.

## SEN-04 · Obfuscation

**Changement** : `tools/release/build_release.ps1` lance `flutter build apk --release --obfuscate --split-debug-info=build/symbols`, puis copie les symboles dans `%LOCALAPPDATA%\Sentinel\symbols\<version>-<commit>` (`build/` est ignoré par Git et effacé par `flutter clean`). Décodage d'une trace : `docs/RELEASE.md`, §5.

**Preuve** (build profile, mêmes options) : `strings libapp.so` → **1** chemin `package:sentinel/` (P1 : 71). Il reste `background/background_analyzer.dart`, voulu : point d'entrée appelé par Kotlin par son nom (`@pragma('vm:entry-point')`). `VaultSession`, `PwnedPasswordsClient`, `PhishingModel`, `deriveKey`, `unlockWithBiometrics`, `breachCount`, `normalizeMessage` : **0** occurrence (tous lisibles en P1). Symboles créés pour les 3 architectures et ignorés par Git (`git check-ignore`).

## SEN-08 · Dépendances

**Changement** (`android/app/build.gradle.kts`, contraintes Gradle ; versions stables publiées depuis plus de 2 semaines, vérifié le 24/10/2026 sur Google Maven et Maven Central) :

| Bibliothèque | Avant (P1) | Après | Publiée le |
|---|---|---|---|
| androidx.core | 1.13.1 | 1.18.0 | 11/03/2026 |
| androidx.lifecycle | 2.7.0 | 2.11.0 | 17/06/2026 |
| androidx.activity | 1.8.1 | 1.13.0 | 11/03/2026 |
| androidx.fragment | 1.7.1 | 1.9.1 | 23/09/2026 |
| androidx.window | 1.2.0 | 1.5.1 | 19/11/2025 |
| androidx.annotation | 1.8.1 | 1.11.0 | 23/09/2026 |
| androidx.profileinstaller | 1.3.1 | 1.4.1 | 02/10/2024 |
| androidx.startup | 1.1.1 | 1.2.0 | 18/09/2024 |
| androidx.exifinterface | 1.4.1 | 1.4.2 | 03/12/2025 |
| androidx.savedstate | 1.2.1 | 1.5.0 | 19/05/2026 |
| androidx.tracing | 1.2.0 | 2.0.3 | 23/09/2026 |
| kotlinx-coroutines (BOM) | 1.7.1 | 1.11.0 | 07/05/2026 |
| kotlin-stdlib-jdk7/jdk8 | 1.8.20 | 2.4.0 (alignés) | — |

`androidx.core` reste en **1.18.0** : la 1.19 exige `compileSdk` 37 (métadonnée AAR `minCompileSdk=37`), alors que Flutter fournit 36. Les autres versions acceptent 34 ou 36. OSV.dev sur l'arbre release résolu : **67 composants, 0 vulnérabilité connue**.

## SEN-01 · Signature

**Changement** (`android/app/build.gradle.kts`) :
- `signingConfigs.release` lit `storeFile` et `keyAlias` dans `android/key.properties` (ignoré par Git). Les mots de passe viennent de ce fichier **ou** des variables `SENTINEL_STORE_PASSWORD` / `SENTINEL_KEY_PASSWORD`, demandées sans affichage par le script et effacées ensuite.
- `buildTypes.release.signingConfig = release` : la ligne qui utilisait la clé de debug est supprimée.
- `checkReleaseSigning()` s'exécute au début de chaque build release (`preReleaseBuild`). Il arrête le build si `key.properties` manque, si `storeFile`, `keyAlias` ou un mot de passe manque, si le keystore est introuvable, ou s'il est **dans le dépôt**.
- `docs/RELEASE.md` : commande `keytool` à lancer soi-même, sauvegarde, construction, vérification `apksigner`, décodage des symboles.

**Preuves**
- `flutter build apk --release` sans clé : `Signature release impossible : android/key.properties est absent. Voir docs/RELEASE.md.` → **BUILD FAILED**.
- Avec un `key.properties` temporaire pointant vers un faux fichier dans le dépôt : `… le keystore doit être HORS du dépôt …` → **BUILD FAILED** (fichiers temporaires supprimés).
- `tools\release\build_release.ps1` sans clé : refus avant toute demande de mot de passe.
- `flutter build apk --debug` : réussi (le debug n'est pas concerné).
- **Reste à faire par le propriétaire** : créer la clé (docs/RELEASE.md, §1), construire, puis vérifier avec `apksigner` (§4).
