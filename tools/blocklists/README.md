# Listes de blocage du pare-feu DNS (update_lists.py)

Génère `assets/blocklists/` : `malware.txt`, `trackers.txt`, `ads.txt` et
`manifest.json` (sources, licences, attributions, date, nombre d'entrées,
SHA-256 de chaque fichier). `protected.txt` (domaines jamais bloqués) et
`LICENSES.txt` (textes des licences, livrés dans l'APK) sont écrits à la main.

## Sources retenues

Vérifiées le 19 octobre 2026. Tailles = entrées valides à la génération.

| Source | Catégorie | Licence | Taille | Mise à jour | Compatible MIT |
|---|---|---|---|---|---|
| [Phishing.Database](https://github.com/Phishing-Database/Phishing.Database) `phishing-domains-ACTIVE.txt` | Malware et hameçonnage | MIT | 386 612 domaines (11 Mo) | Plusieurs fois par jour sur phish.co.za ; copie GitHub moins fréquente (dernier commit : 2 oct. 2026) | Oui (notice à reproduire : `LICENSES.txt`) |
| [ShadowWhisperer](https://github.com/ShadowWhisperer/BlockLists) `Malware` + `Scam` | Malware et hameçonnage | Unlicense (domaine public) | 46 344 + 7 447 | Quotidienne | Oui |
| ShadowWhisperer `Tracking` + `Wild_Tracking` | Traqueurs | Unlicense | 119 165 + 17 630 | Quotidienne | Oui |
| [AdGuard CNAME trackers](https://github.com/AdguardTeam/cname-trackers) `combined_original_trackers.txt` | Traqueurs | MIT | 94 | Hebdomadaire environ | Oui (notice : `LICENSES.txt`) |
| [AdAway](https://github.com/AdAway/adaway.github.io) `hosts.txt` | Publicités | CC BY 3.0 (en-tête du fichier ; le site lui-même est GPL) | 6 540 | Rare (dernier commit : déc. 2025) | Oui, avec attribution et mention des modifications |
| ShadowWhisperer `Ads` + `Wild_Ads` | Publicités | Unlicense | 28 234 + 19 571 | Quotidienne | Oui |

Résultat après fusion : 431 303 entrées malware, 119 217 traqueurs, 31 799
publicités. ShadowWhisperer précise qu'il ne fusionne pas d'autres listes
(script et ajouts manuels), donc pas de licence amont cachée.

Les listes ShadowWhisperer « Wild_ » couvrent les sous-domaines ; les autres
listes ShadowWhisperer sont exactes, sauf `Malware` et `Scam` (les préfixes
`www.`, `m.`, `mobile.` y sont retirés : elles doivent couvrir les
sous-domaines). Les fichiers hosts sont exacts, les règles Adblock `||x^`
couvrent les sous-domaines.

## Sources écartées

| Source | Licence | Raison |
|---|---|---|
| URLhaus (abuse.ch) | Conditions d'utilisation abuse.ch / Spamhaus | Clé d'accès obligatoire, usage « fair use » non commercial, œuvres dérivées et copie interdites sans accord écrit |
| HaGeZi DNS blocklists | GPL-3.0 | Copyleft : redistribuer la liste imposerait la GPL |
| OISD | GPL-3.0 | Copyleft |
| AdGuard DNS filter | GPL-3.0 | Copyleft |
| EasyList / EasyPrivacy | GPL-3.0 ou CC BY-SA 3.0 | Copyleft / partage à l'identique |
| Disconnect tracking protection | CC BY-NC-SA 4.0 | Non commerciale (NC) |
| DuckDuckGo Tracker Radar | CC BY-NC-SA 4.0 | Non commerciale (NC) |
| The Block List Project | Unlicense annoncée | Intègre des listes HaGeZi (GPL-3.0) : licence réelle incertaine |
| StevenBlack hosts (unifié) | MIT pour le dépôt | Agrège MVPS (CC BY-NC-SA 4.0) et someonewhocares (non commercial) |
| Phishing Army | Aucune licence propre | Renvoie aux conditions de chaque source amont |
| AdGuard CNAME `disguised_trackers` | MIT | 240 000 entrées, beaucoup invalides : trop lourd pour le gain |
| 1Hosts | MPL-2.0 | Copyleft faible par fichier : obligations de partage de la liste modifiée |

## Utilisation

```sh
tools/.venv/Scripts/python -I tools/blocklists/update_lists.py
tools/.venv/Scripts/python -I tools/blocklists/update_lists.py --latest
```

Aucune dépendance en dehors de la bibliothèque standard. Les commits sont
épinglés dans `SOURCES`. Pour passer à une version plus récente :

1. Lancer avec `--latest` : le script affiche le commit de chaque dépôt.
2. Relire le diff des fichiers générés (domaines ajoutés ou retirés en masse,
   domaines connus qui apparaîtraient).
3. Recopier les SHA dans `SOURCES`, relancer sans `--latest`, puis
   `./gradlew testDebugUnitTest` (le test du manifeste vérifie les SHA-256).

ShadowWhisperer réécrit parfois l'historique de son dépôt : un commit épinglé
peut disparaître. Le script s'arrête alors avec « Commit introuvable » ; il
suffit de reprendre l'étape 1.

## Domaines protégés

Toute entrée qui bloquerait un nom de `protected.txt` est retirée (exacte
identique, ou `*.` qui le couvrirait), ici comme sur le téléphone. Premier
lancement : `docs.google.com` et `sites.google.com` (Phishing.Database) et
`fcm.googleapis.com` (ShadowWhisperer Ads, notifications push) ont été retirés.

Deuxième passe (faux positif vu en analysant Chrome) : `cdn.ampproject.org`
(cache AMP de Google), `firebasestorage.googleapis.com`,
`storage.cloud.google.com`, `l.instagram.com`, `bit.ly` et le joker
`*.amplifyapp.com` (Phishing.Database). Une ligne protège un NOM, pas ses
sous-domaines : protéger `amplifyapp.com` retire le joker, mais les 348 sites
piégés précis (`0utlook-owa.d1n3vfe0lukbep.amplifyapp.com`…) restent bloqués.
Règle de choix : on protège un nom partagé par tout le monde (CDN, stockage,
redirecteur, raccourcisseur) quand le piège est dans le chemin de l'adresse,
invisible pour le DNS. On ne protège pas une passerelle surtout utilisée
par les arnaques (`cloudflare-ipfs.com`) ni un site ordinaire (`gravatar.com`).

## Fins de ligne

Les `.txt` sont en LF et marqués `-text` dans `.gitattributes` : avec
`core.autocrlf=true`, Git les convertirait sinon en CRLF au checkout, et
leur SHA-256 ne correspondrait plus au manifeste.
