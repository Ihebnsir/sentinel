# Audit P3c : constat trouvé après l'audit

| | |
|---|---|
| Base | P3b (`docs/audit/P3b_corrections.md`) |
| Constat traité | SEN-18 |
| Origine | test réel sur l'émulateur Pixel 8 de développement (Android 17, API 37, non rooté), le 07/11/2026 |
| Contrôles | `flutter analyze` sans problème ; `flutter test` **703 réussis** ; `./gradlew testDebugUnitTest` **144 tests, 0 échec** (1 ignoré : benchmark, ignoré exprès) ; `flutter build apk --debug` réussi |

## Résumé

| ID | Constat | MASVS | Sévérité | Statut | Tests | Retest |
|---|---|---|---|---|---|---|
| SEN-18 | Pare-feu actif : la sécurité du Wi-Fi devient « inconnue » | hors MASVS | Moyenne | **Corrigé** | 4 JUnit (`WifiNetworkPickTest`) | 3 situations → « Wi-Fi ouvert / Danger » |

## SEN-18 · Wi-Fi « inconnu » quand le pare-feu est actif

**Constat.** Sur un Wi-Fi ouvert, l'accueil affichait « Wi-Fi ouvert / Danger » pare-feu éteint, mais « Sécurité inconnue / Inconnu » pare-feu allumé. Un utilisateur protégé par le pare-feu n'était donc **plus averti** d'un Wi-Fi dangereux : une protection en désactivait une autre, sans rien dire.

**Cause** (vérifiée avec `dumpsys connectivity`, pare-feu actif) :

| Réseau | Transports | `transportInfo` |
|---|---|---|
| VPN de Sentinel (réseau par défaut) | `WIFI\|VPN` | `VpnTransportInfo` |
| Wi-Fi `wlan0` | `WIFI` | `WifiInfo`, `Security type: 0` (ouvert) |

Android donne à un VPN les transports de son réseau sous-jacent : le VPN annonce donc lui aussi `TRANSPORT_WIFI`. `findWifiNetwork()` prenait le réseau par défaut dès qu'il avait `TRANSPORT_WIFI`, donc le VPN. Sa `transportInfo` n'est pas une `WifiInfo`, et `securityType()` renvoyait `unknown`. Ce n'était pas un masquage d'informations : le vrai réseau Wi-Fi donne bien son type de sécurité **sans permission de localisation** (`WifiInfo.getCurrentSecurityType()`, Android 12+).

**Changement** (`WifiSecurityChecker.kt`) : nouvelle fonction pure `pickWifiNetwork()`, qui garde un réseau seulement s'il a `TRANSPORT_WIFI` **et pas** `TRANSPORT_VPN`, d'abord le réseau par défaut, puis tous les réseaux. L'écoute des changements n'avait pas ce défaut : une `NetworkRequest` exclut les VPN par défaut (`NOT_VPN`). Toujours aucune permission de localisation, et ni SSID ni BSSID lus.

**Tests JUnit** : `WifiNetworkPickTest` (4), avec les réseaux relevés sur l'émulateur : sans VPN, le Wi-Fi par défaut est gardé ; VPN par défaut avec `WIFI` → le vrai Wi-Fi est choisi ; VPN sur données mobiles → pas de Wi-Fi ; Wi-Fi sans internet → trouvé parmi tous les réseaux.

**Retest émulateur** (APK debug, Wi-Fi ouvert `AndroidWifi` de l'émulateur, app en arabe ; l'accueil relit l'état au retour au premier plan) :

| Situation | Réseaux vus | Affiché | Preuve |
|---|---|---|---|
| Pare-feu inactif | pas de VPN | « شبكة Wi-Fi مفتوحة » / « خطر » (Wi-Fi ouvert / Danger) | [00_parefeu_inactif.png](sen18/00_parefeu_inactif.png) |
| Pare-feu actif | VPN `WIFI\|VPN` présent, icône clé | Wi-Fi ouvert / Danger | [01_parefeu_actif.png](sen18/01_parefeu_actif.png) |
| Analyse de Chrome en cours | VPN `WIFI\|VPN` présent | Wi-Fi ouvert / Danger | [02_analyse_app.png](sen18/02_analyse_app.png) |

Avant la correction, les deux dernières lignes affichaient « Sécurité inconnue / Inconnu ».
