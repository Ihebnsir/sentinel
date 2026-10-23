# Audit P2 : analyse dynamique de l'APK release

| | |
|---|---|
| Application | Sentinel 1.0.0 (versionCode 1), `com.iheb.sentinel` |
| Cible | APK release de P1, SHA-256 `e717b6b8c9e36f417254bfa216a92151addabe6e1a282bcb5197797f2600ea53` (vérifié avant chaque installation) |
| Commit audité | `311e66a` (aucun fichier de l'app modifié) |
| Dates | 22-23/10/2026 |
| Référentiels | OWASP MASVS v2, MASTG (tests dynamiques) |
| Suite de | `docs/audit/P1_statique.md` (SEN-01 à SEN-09) |

## 1. Résumé

L'essentiel des protections tient **en conditions réelles** :
- le coffre est vraiment chiffré sur le disque ;
- aucun secret n'apparaît dans les logs ni dans les fichiers ;
- l'écran du coffre est noir en capture et dans les apps récentes ;
- le verrouillage à l'extinction et l'effacement du presse-papiers fonctionnent ;
- HIBP n'envoie que 5 caractères ;
- les services exportés refusent les autres apps ;
- les rapports d'analyse disparaissent après 24 h.

Statut des constats de P1 testés :

| ID | Statut | Preuve principale |
|---|---|---|
| SEN-02 (police Google) | **Confirmé** | Premier lancement : connexion TLS `fonts.gstatic.com` attribuée à l'UID de Sentinel ; fichier `ReadexPro_regular_<sha256>.ttf` dans `files/` |
| SEN-05 (`debugPrint` en release) | **Non reproduit** | Aucune ligne de Sentinel dans logcat sur tout le scénario ; le chemin d'erreur qui fuiterait un nom de package n'a pas pu être atteint sans altérer Android (voir §2.4) |
| SEN-06 (`CHECK_ALERT`) | **Confirmé** | Une app sans permission ouvre Sentinel avec un texte forgé, analysé automatiquement : « Rien de suspect » |

Nouveaux constats :

| ID | Titre | MASVS | Sévérité |
|---|---|---|---|
| SEN-10 | Requêtes DNS envoyées **en clair** à Quad9, sans que l'utilisateur en soit informé | MASVS-NETWORK-1 / PRIVACY-3 | **Moyenne** |
| SEN-11 | Pare-feu + DNS privé « strict » : **plus aucune résolution DNS**, sans avertissement | MASVS-NETWORK-1 | **Moyenne** |
| SEN-12 | Analyse anti-arnaque contournée par un caractère d'inversion de texte (U+202E) | MASVS-CODE-4 | Faible |
| SEN-13 | Clé de récupération et mots de passe affichés lisibles par les services d'accessibilité | MASVS-PLATFORM-3 | Faible |
| SEN-14 | Rapports d'analyse en clair sur le disque, suppression jusqu'à 1 h en retard | MASVS-STORAGE-1 | Info |
| SEN-15 | Pas d'épinglage de certificat (HIBP, listes) | MASVS-NETWORK-2 | Info |
| SEN-16 | Prénom du développeur écrit en dur (« Bonjour, Iheb ») | hors MASVS (qualité) | Info |
| SEN-17 | Le bandeau « Wi-Fi ouvert » recouvre et bloque des boutons importants | hors MASVS (ergonomie) | Info |

## 2. Environnement et méthode

### 2.1 Outils

| Élément | Version | Intégrité |
|---|---|---|
| Émulateur `Sentinel_Audit_Root` (créé pour l'audit ; le Pixel 8 n'a pas été touché, configuration vérifiée par MD5 avant et après) | Android 17 (API 37), image **Google APIs sans Play Store** `x86_64-37.0_r08`, build `userdebug`, correctif du 05/08/2026 | SHA-1 `a266cfbcf4d6c769b166c0af4d68eff0e4f4a5e3`, identique au catalogue officiel `sys-img2-4.xml` de Google |
| Android Emulator | 37.2.12 | SDK |
| `adb root` | uid 0, contexte `u:r:su:s0` | — |
| tcpdump | celui de l'image `userdebug` (`/system/bin/tcpdump`), capture **dans** l'émulateur, toutes interfaces (`wlan0`, `eth0`, `tun0`) | — |
| TShark | 4.6.3 (déjà installé) | — |
| mitmproxy (Docker) | `12.2.3`, publié le 12/05/2026 (la 12.3.0, publiée la veille, a été écartée car trop récente) | lancé par digest `sha256:00b77b5d8804c8ad18cb6caefbf9d5849e895e8986c5ce011f4ae30f4385962f` |
| iptables (dans l'émulateur) | règle `LOG` sur `--uid-owner 10234 --ctstate NEW` | attribue **chaque nouvelle connexion** à Sentinel, sans ambiguïté |

### 2.2 Attribution du trafic

Un émulateur Google APIs génère beaucoup de trafic à lui (services Google). Pour ne pas attribuer à Sentinel ce qui ne vient pas de lui :
- 2 min de capture au repos avant l'installation (`00_baseline.pcap`) ;
- une règle iptables qui journalise chaque **nouvelle** connexion de l'UID 10234 (Sentinel), avec destination et port ;
- un recoupement de chaque connexion journalisée avec le nom du serveur (SNI TLS) dans le pcap.

### 2.3 Interception HTTPS (HIBP uniquement)

Pour lire la requête HIBP déchiffrée : proxy mitmproxy en mode *reverse* vers `api.pwnedpasswords.com` uniquement, autorité de certification (CA) ajoutée **temporairement** (montage tmpfs, root) au magasin système de l'émulateur, et redirection de ce seul nom via `/system/etc/hosts` (montage bind). Tout a été retiré juste après : 145 certificats d'origine, aucune trace de la CA, fichier hosts d'origine, conteneur supprimé.

### 2.4 Incident pendant l'audit

Pour provoquer le cas d'erreur de SEN-05 (« écran de désinstallation introuvable »), j'ai désactivé en root le composant `UninstallerActivity` de l'installeur Android. **Android ne redémarre plus dans cet état** : `PackageManagerService` exige exactement un désinstalleur et entre en boucle de démarrage. Le fichier système concerné est protégé par fs-verity, et sa modification a été refusée par la politique de l'outil d'audit. Je ne l'ai donc pas contournée : l'émulateur d'audit a été réinitialisé (`-wipe-data`), l'APK réinstallé et le scénario minimal refait. Ce n'est **pas** un défaut de Sentinel ; cela explique seulement pourquoi SEN-05 n'a pas pu être reproduit.

### 2.5 Marqueurs

Des valeurs uniques ont été utilisées pour rechercher les fuites :
- mot de passe maître : `MaitreAudit#2026!xQ` ;
- entrée du coffre : `BanqueAudit` / `audit.utilisateur@example.org` / `ZebreSecret-4417-kW` / `https://banque.example.org` ;
- message analysé : `MARQUEUR7731…laposte-colis-suivi.example-arnaque.xyz` ;
- domaine « visité » : `audit-visite-privee.example.com` ;
- clés de récupération affichées.

Elles ont été cherchées en UTF-8 et en UTF-16, avec et sans séparateurs.

### 2.6 Fichiers de preuve (locaux, `.audit_work/p2/`, hors git)

| Fichier | SHA-256 |
|---|---|
| `pcap/00_baseline.pcap` | `acc530668c8bc60b2d229281130b1899bfc81d70fdada5c34b3236c628f739c8` |
| `pcap/01_premier_lancement.pcap` | `c018c745bbd2be56d0b5910f56e62a2e9afce21087aa1dec048a549d6361500f` |
| `pcap/02_scenario.pcap` | `cb2c8d4389dbd8e387db4072f7796221c8ae17c0441c147e1c03f76d4966dac1` |
| `mitm/hibp_mitmdump.log` | `95a4cb52b137daa602b6169b6661c78799c919818460c58433055909764017a8` |
| `logs/logcat_partie1.txt` | `aa95c81496d2b76bfaf96834e06625f4ed01dfd77e8e0eee9447c6e950eff646` |
| `logs/logcat_partie2.txt` | `f2ed16e8b09ef4b5eb4dff6db9f0b967d2fdaabfa009bb634fee5fe354ef2f69` |
| `logs/01_iptables_sentinel.txt` | `3b454c5bce6a170dd7bf0dbf105904bf63aeb563b967d6bc945b120bc5d6689c` |
| `logs/02_iptables_sentinel.txt` | `dcef0d3280b5de496be6f3f305fcf0bc84454ec1e358875549a642f9349bb861` |

Les captures d'écran citées sont copiées dans `docs/audit/p2/`.

## 3. Réseau

### 3.1 Premier lancement (SEN-02 : confirmé)

Seule connexion de Sentinel pendant les 70 premières secondes, **sans aucune action de l'utilisateur** :

```
iptables : SENTINEL_NEW OUT=wlan0 DST=142.251.209.99 PROTO=TCP DPT=443 UID=10234
tshark   : 8.406 s  142.251.209.99:443  SNI = fonts.gstatic.com   (54 Ko reçus)
DNS      : fonts.gstatic.com (A et AAAA) en clair vers le résolveur du réseau
```

Le fichier est ensuite mis en cache : `files/ReadexPro_regular_d01db080…4c.ttf` (91 720 octets). Son SHA-256 correspond à son nom, donc le contenu est bien vérifié. Les autres flux du pcap (`android.googleapis.com`, `geomobileservices-pa.googleapis.com`) ne viennent pas de l'UID de Sentinel. Aucune autre connexion de Sentinel n'a lieu sans action de l'utilisateur. Le README (« le seul appel réseau est HIBP, sur accord ») reste donc inexact.

### 3.2 Récapitulatif de tout le trafic de Sentinel (scénario complet)

| Connexions (iptables, UID 10234) | Destination | Déclencheur | Chiffré ? |
|---|---|---|---|
| 1 × TCP 443 | `fonts.gstatic.com` | premier lancement, **sans accord** | TLS |
| 48 × UDP 53 | `9.9.9.9` (Quad9) | pare-feu actif (requêtes des autres apps) | **non** |
| 1 × TCP 443 | `api.pwnedpasswords.com` | « Vérifier les fuites », après accord | TLS |
| 1 × TCP 443 | `raw.githubusercontent.com` | « Mettre à jour » les listes, après accord | TLS |
| HTTP en clair | — | — | aucun |

### 3.3 HIBP (conforme)

Requête déchiffrée par mitmproxy, après acceptation de la fenêtre de consentement :

```
GET https://api.pwnedpasswords.com/range/F1F06
    user-agent: Sentinel-App
    add-padding: true
    accept-encoding: gzip
```

- `F1F06` correspond exactement aux 5 premiers caractères de SHA-1(`ZebreSecret-4417-kW`) = `F1F06D68ADF4A6EB…`. Le suffixe ne quitte jamais l'appareil.
- **Une seule requête**. Le mot de passe maître n'est pas vérifié (son préfixe `C6DED` n'apparaît pas).
- Le cookie `__cf_bm` posé par Cloudflare n'est pas renvoyé.
- Le texte de consentement correspond à ce qui se passe réellement.

### 3.4 Mise à jour des listes (conforme)

- Une fenêtre de consentement s'affiche avant le premier téléchargement et nomme GitHub (`raw.githubusercontent.com`) et HTTPS.
- Le trafic observé est une seule connexion TLS, SNI `raw.githubusercontent.com`.
- Les fichiers obtenus (`malware-*.txt`, `trackers-*.txt`, `manifest.json`) sont stockés en `-rw-------` dans `files/blocklists/`.
- Hors ligne, l'échec est signalé à l'écran (« dernière tentative… ») et les anciennes listes restent en place.

### 3.5 Pare-feu DNS : requêtes amont → voir SEN-10 et SEN-11

Les domaines bloqués ne sortent **jamais** sur le réseau : réponse NXDOMAIN (`rcode 3`) fabriquée dans `tun0`.

```
735.616  tun0  10.111.222.1 → 10.111.222.2  www.google-analytics.com
735.617  tun0  10.111.222.2 → 10.111.222.1  www.google-analytics.com  rcode=3
```

## 4. Constats

### SEN-10 · Requêtes DNS envoyées en clair à Quad9, sans information de l'utilisateur

- **MASVS** : MASVS-NETWORK-1 (données en transit protégées) et MASVS-PRIVACY-3 (transparence)
- **Sévérité : Moyenne.** Tout observateur du réseau (Wi-Fi public, box, opérateur) voit les noms des sites consultés par **toutes** les apps, et peut aussi falsifier les réponses s'il est sur le chemin. C'est souvent déjà le cas sans Sentinel, d'où une sévérité Moyenne et non Élevée. Mais Sentinel ne le dit pas, et sur un réseau qui proposait du DNS chiffré (DNS privé en mode automatique), il fait **reculer** la confidentialité.
- **Preuve** (`02_scenario.pcap`, interface `wlan0`, sockets `protect()` de Sentinel) :

  ```
  00:47:36.361  10.0.2.16 → 9.9.9.9  DNS  A www.wikipedia.org
  00:47:36.497  9.9.9.9 → 10.0.2.16  DNS  CNAME dyna.wikimedia.org A 185.15.58.224
  00:47:36.732  10.0.2.16 → 9.9.9.9  DNS  A audit-visite-privee.example.com
  00:49:59.887  10.0.2.16 → 9.9.9.9  DNS  A es.wikipedia.org
  ```

  Aucune trame sur le port 853 (DoT) ni en DoH de la part de Sentinel. La requête est relayée telle quelle, avec l'identifiant choisi par l'app d'origine. Texte du consentement affiché à l'activation (`logs/ui_consentement.xml`) : « Seules les demandes de noms de sites (DNS) passent par Sentinel… Aucun site visité n'est enregistré ». **Quad9 n'est cité nulle part dans l'interface** (aucune occurrence dans `lib/`), et le fait que les requêtes partent en clair non plus. `SECURITY_DESIGN.md` (limite n° 25) le documente, mais l'utilisateur ne le lit pas.
- **Impact pour l'utilisateur** : sur un Wi-Fi public, le gestionnaire du réseau voit par exemple « banque-x.fr, site-de-santé.fr, appli-de-rencontre.com », avec l'heure. Quad9 reçoit aussi toutes les requêtes. La promesse « tout se passe sur votre téléphone » est trompeuse sur ce point.
- **Recommandation** : envoyer les requêtes amont en **DNS-over-TLS** (`dns.quad9.net:853`) ou en DoH (`https://dns.quad9.net/dns-query`), avec réutilisation de la connexion. En attendant, dire dans la feuille d'activation : « les noms de sites sont transmis à Quad9 (Suisse), sans chiffrement ».

### SEN-11 · Pare-feu + DNS privé « strict » : plus aucune résolution DNS

- **MASVS** : MASVS-NETWORK-1 (contexte : interaction avec le DNS privé d'Android)
- **Sévérité : Moyenne.** Pas de fuite, mais une panne totale (aucun site ne s'ouvre) qui touche précisément les utilisateurs soucieux de leur vie privée (NextDNS, AdGuard, Quad9 en DNS privé). Pendant la panne, Sentinel n'affiche rien d'anormal : « Pare-feu DNS Activé », compteurs figés. Un utilisateur risque de désinstaller l'app ou de couper le DNS privé, ce qui réduit sa protection.
- **Preuve** : DNS privé réglé sur `dns.google` (mode strict), pare-feu actif :

  | Test (uid 2000) | Pare-feu actif | Pare-feu coupé |
  |---|---|---|
  | `fr.wikipedia.org` | **unknown host** | résolu |
  | `www.mozilla.org` | **unknown host** | — |
  | `www.123count.com` (traqueur) | unknown host | **résolu** (non bloqué) |
  | Compteur « Requêtes analysées » | reste à 11 | — |

  Le pcap montre la validation DoT (TCP 853) et DoH de `dns.google` **uniquement par les réseaux physiques** (`10.0.2.15`/`.16`), jamais par `tun0`. Le VPN ne route que `10.111.222.2/32`, donc le DNS privé ne peut pas être validé sur le réseau VPN, et Android bloque alors tout le DNS (comportement « fail-closed » du mode strict). Le mode **automatique** fonctionne normalement avec le pare-feu (requêtes vues et filtrées). Capture : `docs/audit/p2/06_parefeu_dns_strict.png`.
- **Impact pour l'utilisateur** : « Internet ne marche plus dès que j'active Sentinel », sans explication.
- **Recommandation** : lire `LinkProperties.isPrivateDnsActive` / `privateDnsServerName` (déjà fait par `WifiSecurityChecker`). En mode strict, refuser l'activation ou afficher une explication avec un bouton vers les réglages du DNS privé. Une alternative : transmettre les requêtes au serveur DNS privé de l'utilisateur en DoT (ce qui règle aussi SEN-10).

### SEN-12 · Analyse anti-arnaque contournée par un caractère d'inversion de texte

- **MASVS** : MASVS-CODE-4 (validation des entrées non fiables)
- **Sévérité : Faible.** Le contournement est trivial, mais un lien ainsi masqué n'est généralement pas cliquable dans une messagerie : l'escroc perd en efficacité ce qu'il gagne en discrétion.
- **Preuve** : même message, même domaine malveillant, envoyé par `SEND` (uid 2000) :

  | Texte | Verdict |
  |---|---|
  | `Payez ici https://laposte-colis-suivi.example-arnaque.xyz sinon blocage` | **Arnaque probable, 96 %**, « imite La Poste » |
  | même domaine écrit à l'envers entre `U+202E` … `U+202C` | **Suspect, 74 %**, domaine ignoré, aucune marque détectée |
  | `Payez ici ` + `U+202E` + `moc.elgoog//:sptth` + `U+202C` | affiché `https://google.com`, aucune alerte sur le caractère invisible |

  Captures : `docs/audit/p2/10_rtl.png`, `docs/audit/p2/11_rtl_domaine.png`.
- **Impact pour l'utilisateur** : un message conçu pour tromper l'œil reçoit un avertissement plus faible que le même message écrit normalement.
- **Recommandation** : avant l'analyse, détecter et signaler les caractères de contrôle bidirectionnels (U+202A-202E, U+2066-2069) et les caractères invisibles (U+200B-200D, U+FEFF) comme indice d'arnaque fort (« texte piégé »). Analyser aussi la version nettoyée (ces caractères retirés, et chaque segment inversé remis à l'endroit).

### SEN-13 · Clé de récupération et mots de passe révélés lisibles par l'accessibilité

- **MASVS** : MASVS-PLATFORM-3 (l'interface n'expose pas de données sensibles)
- **Sévérité : Faible.** Il faut un service d'accessibilité malveillant activé par l'utilisateur, ce qui est rare mais typique des logiciels espions et des chevaux de Troie bancaires. Sentinel vise précisément ces menaces.
- **Preuve** : arbre d'accessibilité (`uiautomator dump`) pendant que l'écran est **noir en capture** (FLAG_SECURE) :

  ```
  [View] "SCK9 R54D AZWR CFQD 9CD9 2YFA 9XT5"          ← clé de récupération
  [EditText] text="ZebreSecret-4417-kW" password=false ← après « Afficher »
  [EditText] text="•••••••••••••••••••"                ← champ masqué : correct
  ```
- **Impact pour l'utilisateur** : FLAG_SECURE bloque les captures d'écran, mais pas un logiciel espion qui lit l'écran par l'accessibilité. Il pourrait récupérer la clé de récupération, qui ouvre tout le coffre.
- **Recommandation** : sur Android 14+, marquer ces vues `accessibilityDataSensitive` (attribut Android `setAccessibilityDataSensitive(true)`), ce qui les cache aux services non certifiés comme outils d'accessibilité. Dans Flutter, cela passe par un canal natif ou par une version du moteur qui le prend en charge. Afficher la clé masquée par défaut, groupe par groupe.

### SEN-14 · Rapports d'analyse en clair sur le disque ; suppression jusqu'à 1 h en retard

- **MASVS** : MASVS-STORAGE-1
- **Sévérité : Info.** Le stockage est privé (`-rw-------`, UID de l'app) et chiffré par Android (chiffrement par fichier). Il faut root ou une extraction judiciaire.
- **Preuve** : `files/app_reports/1792783456914-1792783336762.json` contient en clair le paquet analysé et les domaines contactés (`accounts.google.com`, `optimizationguide-pa.googleapis.com`…). Suppression vérifiée en avançant l'horloge de 25 h : le fichier disparaît, **conforme**. L'alarme est cependant `RTC_WAKEUP … window=+1h0m0s` : sans la permission d'alarme exacte (refusée par défaut sur Android 14+), le rapport peut vivre jusqu'à 25 h.
- **Recommandation** : rien d'urgent. Pour aller plus loin : chiffrer les rapports avec une clé du Keystore, et purger aussi au démarrage de l'app (déjà fait à chaque `list()`/`save()`).

### SEN-15 · Pas d'épinglage de certificat

- **MASVS** : MASVS-NETWORK-2
- **Sévérité : Info.** L'interception n'a été possible **qu'avec root**, en ajoutant une CA au magasin **système**. Les CA ajoutées par l'utilisateur restent refusées (targetSdk 36). L'épinglage est déconseillé pour des services tiers dont les certificats changent (Cloudflare, GitHub). Les listes sont en plus contrôlées (taille, format, cohérence).
- **Recommandation** : ne pas épingler. Éventuellement, signer `manifest.json` des listes avec une clé de l'auteur, ce qui protège même contre une CA compromise.

### SEN-16 · Prénom du développeur écrit en dur

- **Sévérité : Info** (qualité, pas sécurité).
- **Preuve** : `lib/screens/home_screen.dart:197` → `'Bonjour, Iheb'`, visible sur un émulateur vierge (`docs/audit/p2/01_premier_ecran.png`).
- **Recommandation** : texte neutre (« Bonjour ») ou prénom saisi par l'utilisateur.

### SEN-17 · Le bandeau « Wi-Fi ouvert » bloque des boutons importants

- **Sévérité : Info** (ergonomie). Sur un Wi-Fi ouvert, le bandeau permanent (y = 1 402 à 1 528, ou 2 012 à 2 190 selon l'écran) recouvre et **intercepte les appuis** sur « Créer mon coffre », « J'ai noté ma clé », « Enregistrer » et l'entrée « Pare-feu DNS » de l'accueil. Il a fallu couper le Wi-Fi pour créer le coffre. Or un utilisateur sur Wi-Fi public est justement celui qui a le plus besoin de ces fonctions.
- **Recommandation** : réserver de la place pour le bandeau (`Scaffold.bottomSheet` ou marge du contenu), ou le rendre refermable.

## 5. Logs (SEN-05 : non reproduit)

Logcat complet pendant tout le scénario (installation, coffre, entrée, copie, verrouillage, analyse de message, scan des apps, pare-feu, DNS privé, analyse de Chrome, HIBP, mise à jour, réseau coupé, attaques par intents) : 66 080 lignes en partie 1, plus la partie 2.

- Les marqueurs (mot de passe maître, mot de passe de l'entrée, identifiant, texte du message, domaines visités, clés de récupération, préfixe HIBP) ont été retrouvés **uniquement** dans les lignes `adbd` (mes propres commandes `input text`) et `ActivityTaskManager` (mon lancement de Chrome). **Aucune** ligne écrite par un processus de Sentinel ne contient de donnée sensible.
- Lignes du processus Sentinel : uniquement des messages du système (GC, rendu, `AssistStructure`) et l'avertissement du moteur Flutter `Using the Impeller rendering backend`. Aucun `debugPrint` de l'app, aucun `Log.w("SentinelAnalyzer")`.
- Les erreurs que j'ai pu provoquer sans altérer Android (mise à jour hors ligne, écrans visités sans réseau) sont gérées sous forme de **résultat**, pas d'exception : elles ne passent donc pas par `debugPrint`.

**Conclusion** : SEN-05 reste vrai dans le code (12 `debugPrint` non conditionnels, P1), mais aucune fuite n'a été observée. Le cas « nom de package dans le log » exige un appareil sans écran de désinstallation, ce que même l'émulateur ne tolère pas (§2.4). La sévérité Faible est maintenue, avec une probabilité plus basse que prévu.

## 6. Composants exportés (SEN-06 : confirmé)

Tous les intents ont été envoyés en tant qu'UID 2000 (`shell`), sans root : un UID 0 contournerait toutes les permissions et fausserait le test.

| Test | Résultat |
|---|---|
| `am start -n …/.MainActivity -a com.iheb.sentinel.action.CHECK_ALERT --es android.intent.extra.TEXT "Message de votre banque : votre compte est verifie. Aucun risque."` | **Accepté.** Sentinel s'ouvre sur Messages, le texte est **analysé automatiquement** : « Rien de suspect, 31 % » (`docs/audit/p2/09_check_alert_forge.png`) |
| `SEND` / `PROCESS_TEXT` : texte vide, blancs seuls | ignorés (rien affiché), pas de plantage |
| texte de 120 000 caractères | **tronqué à 5 000** (`MessageTexts.kt`), pas de plantage (200 000 dépasse la limite du shell, `Argument list too long`) |
| 4 999 caractères + emoji à cheval sur la limite | coupé proprement, pas de caractère cassé |
| caractères de contrôle (`\001`, `\033[31m`, `\007`, `\177`), emojis, espaces de largeur nulle | affichés sans effet, pas de plantage |
| caractères RTL | voir SEN-12 |
| `am startservice` / `start-foreground-service` → `SentinelVpnService` | `Error: Requires permission android.permission.BIND_VPN_SERVICE` |
| `am startservice` → `SentinelNotificationListener` | `Error: Requires permission android.permission.BIND_NOTIFICATION_LISTENER_SERVICE` |
| `am broadcast` → `ReportCleanupReceiver` (non exporté) | `SKIPPED … Permission Denial … is not exported from uid 10234` |
| `am broadcast` → `ProfileInstallReceiver` | livré, car `shell` possède `DUMP` : confirme FP-03 (seuls le système et ADB y ont accès) |

PID de Sentinel identique avant et après la vingtaine d'essais ; aucun plantage dans `logcat -b crash`.

**SEN-06, impact précisé** : le texte reçu est analysé tout de suite et le verdict s'affiche dans l'interface de confiance de Sentinel. Une app malveillante peut donc afficher « Rien de suspect » sur un message choisi par l'escroc, par exemple juste après l'avoir envoyé par SMS. Sévérité maintenue à **Faible** : il faut une app malveillante installée, et le même effet est déjà possible par `SEND`. La correction proposée en P1 (activité non exportée ou jeton pour `CHECK_ALERT`) reste valable. En complément : ne pas lancer l'analyse automatiquement pour un texte reçu par intent, ou indiquer « texte reçu de l'application X ».

## 7. Stockage (root)

Contenu de `/data/data/com.iheb.sentinel` après le scénario :

| Fichier | Droits | Contenu | Verdict |
|---|---|---|---|
| `files/vault.json` (1 173 o) | `-rw-------` | voir ci-dessous | **chiffré** |
| `files/breach_consent.json` | `-rw-------` | `{"accepted":true}` | OK, rien de secret |
| `files/app_reports/*.json` | `-rw-------` | domaines contactés par l'app analysée | SEN-14 |
| `files/blocklists/*` | `-rw-------` | listes téléchargées + `manifest.json` | OK |
| `files/ReadexPro_regular_<sha256>.ttf` | `-rw-------` | police Google | preuve de SEN-02 |
| `shared_prefs/sentinel_firewall.xml` | `-rw-rw----` | `last_update_failed`, `last_update_attempt` | OK, aucune donnée de navigation |
| `cache/` | — | uniquement `oat_primary/…/base.art` (ART) | OK |

Structure de `vault.json` :

```
version = 2
derniereOuvertureMdp = 2026-10-23T19:17:35.000Z        ← seule métadonnée en clair
keySlots[0].type = password
keySlots[0].kdf  = argon2id, memoire 47104 Kio (46 Mio), iterations 2, parallelisme 1, sel 16 o
keySlots[0].wrappedKey = nonce 12 o + chiffré 48 o     (clé de 32 o + tag GCM 16 o)
keySlots[1].type = recovery, sel 16 o, wrappedKey 12 o + 48 o
data = nonce 12 o + chiffré 312 o (AES-GCM)
```

- Aucun marqueur (mot de passe maître, mot de passe de l'entrée, titre, identifiant, site, clé de récupération) n'a été trouvé dans **aucun** fichier, en UTF-8 comme en UTF-16.
- Paramètres Argon2id conformes aux recommandations OWASP (46 Mio).
- **Rien dans le stockage externe** : `/sdcard/Android/data`, `/sdcard/Android/media` et une recherche `*sentinel*` sur `/sdcard` sont vides.

## 8. Protections à l'écran

| Contrôle | Méthode | Résultat |
|---|---|---|
| FLAG_SECURE (onglet Coffre) | `adb exec-out screencap` | **image entièrement noire** (conforme) |
| Aperçu dans les apps récentes | touche Récents + capture | **vignette noire** (`docs/audit/p2/03_recents_coffre.png`, conforme) |
| Verrouillage automatique | écran éteint (`KEYCODE_POWER`) puis rallumé | « Coffre verrouillé, entrez votre mot de passe maître » (conforme) |
| Presse-papiers (clé de récupération) | collage par le menu système | t+3 s : `SCK9-R54D-…-9XT5` ; **t+35 s : vide** (conforme, effacé après 30 s) |
| Champs de mot de passe | arbre d'accessibilité | masqués (`•••`), sauf après « Afficher » (SEN-13) |

## 9. Ce qui n'a pas été testé

- Les alertes de la protection automatique (lecture des notifications) : il aurait fallu une vraie messagerie et un accès de lecture des notifications accordé.
- Le déverrouillage biométrique du coffre (pas d'empreinte enregistrée sur l'émulateur).
- Android 7 à 9 (SEN-03) : seul Android 17 a été testé.
- La surface d'attaque côté Kotlin par instrumentation (Frida) : hors périmètre de P2.
