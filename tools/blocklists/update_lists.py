"""Génère assets/blocklists/ : une liste de domaines par catégorie et un
manifeste JSON (sources, licences, attributions, nombres, SHA-256).

Usage (depuis la racine du projet) :
    tools/.venv/Scripts/python -I tools/blocklists/update_lists.py
    tools/.venv/Scripts/python -I tools/blocklists/update_lists.py --latest

Chaque source est téléchargée à un commit ÉPINGLÉ (champ « commit ») : le
résultat est reproductible, et une modification en amont n'entre pas dans
l'app sans relecture. --latest prend le dernier commit de chaque dépôt et
affiche les SHA à recopier dans SOURCES.

Format des fichiers générés (trié, une entrée par ligne, fins de ligne LF) :
    exemple.com     ce nom exact seulement
    *.exemple.com   ce nom et tous ses sous-domaines

La même logique (formats, normalisation, domaines protégés, dédoublonnage)
existe en Kotlin pour les mises à jour sur le téléphone :
android/.../firewall/ListParser.kt et CategoryBuilder.kt.
"""

import argparse
import hashlib
import json
import re
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
SORTIE = RACINE / "assets" / "blocklists"
PROTEGES = SORTIE / "protected.txt"

# Ordre = priorité : un domaine présent dans deux catégories est attribué
# à la première (le malware passe avant les traqueurs).
CATEGORIES = [
    {"id": "malware", "name": "Malware et hameçonnage",
     "defaultEnabled": True, "alerts": True},
    {"id": "trackers", "name": "Traqueurs",
     "defaultEnabled": True, "alerts": False},
    {"id": "ads", "name": "Publicités",
     "defaultEnabled": False, "alerts": False},
]

MIT_PHISHING = (
    "Copyright (c) 2018-2025 Mitchell Krog - github.com/mitchellkrogza ; "
    "Copyright (c) 2018-2025 Nissar Chababy - github.com/funilrys ; "
    "Copyright (c) 2018-2025 Phishing.Database Contributors - github.com/Phishing-Database"
)
SW_ATTRIBUTION = (
    "BlockLists par ShadowWhisperer, https://github.com/ShadowWhisperer/BlockLists, "
    "dans le domaine public (The Unlicense)."
)

# format : "domains" (un domaine par ligne), "hosts" (« 0.0.0.0 domaine »),
# "adblock" (« ||domaine^ », toujours avec les sous-domaines).
# subdomains : pour "domains" et "hosts", la ligne bloque-t-elle aussi les
# sous-domaines ? (les listes « Wild_ » de ShadowWhisperer : oui.)
SOURCES = [
    {
        "id": "phishing-database",
        "name": "Phishing.Database (domaines actifs)",
        "category": "malware",
        "repo": "Phishing-Database/Phishing.Database",
        "branch": "master",
        "commit": "12a20bf8dd2b7e78d9d38fc12b3e5c970f79d1a7",
        "path": "phishing-domains-ACTIVE.txt",
        "format": "domains",
        "subdomains": False,
        "license": "MIT",
        "licenseUrl": "https://github.com/Phishing-Database/Phishing.Database/blob/master/LICENSE",
        "homepage": "https://github.com/Phishing-Database/Phishing.Database",
        "copyright": MIT_PHISHING,
        "attribution": (
            "Phishing.Database par Mitchell Krog, Nissar Chababy et la "
            "communauté, https://github.com/Phishing-Database/Phishing.Database, "
            "sous licence MIT. " + MIT_PHISHING + "."
        ),
    },
    {
        "id": "sw-malware",
        "name": "ShadowWhisperer – Malware",
        "category": "malware",
        "repo": "ShadowWhisperer/BlockLists",
        "branch": "master",
        "commit": "626738252e16cadd32d409b63944d9601ad84ee7",
        "path": "Lists/Malware",
        "format": "domains",
        # « www. », « m. » et « mobile. » sont retirés de cette liste :
        # elle doit couvrir les sous-domaines.
        "subdomains": True,
        "license": "Unlicense",
        "licenseUrl": "https://github.com/ShadowWhisperer/BlockLists/blob/master/LICENSE",
        "homepage": "https://github.com/ShadowWhisperer/BlockLists",
        "copyright": "",
        "attribution": SW_ATTRIBUTION,
    },
    {
        "id": "sw-scam",
        "name": "ShadowWhisperer – Scam",
        "category": "malware",
        "repo": "ShadowWhisperer/BlockLists",
        "branch": "master",
        "commit": "626738252e16cadd32d409b63944d9601ad84ee7",
        "path": "Lists/Scam",
        "format": "domains",
        "subdomains": True,
        "license": "Unlicense",
        "licenseUrl": "https://github.com/ShadowWhisperer/BlockLists/blob/master/LICENSE",
        "homepage": "https://github.com/ShadowWhisperer/BlockLists",
        "copyright": "",
        "attribution": SW_ATTRIBUTION,
    },
    {
        "id": "sw-tracking",
        "name": "ShadowWhisperer – Tracking",
        "category": "trackers",
        "repo": "ShadowWhisperer/BlockLists",
        "branch": "master",
        "commit": "626738252e16cadd32d409b63944d9601ad84ee7",
        "path": "Lists/Tracking",
        "format": "domains",
        "subdomains": False,
        "license": "Unlicense",
        "licenseUrl": "https://github.com/ShadowWhisperer/BlockLists/blob/master/LICENSE",
        "homepage": "https://github.com/ShadowWhisperer/BlockLists",
        "copyright": "",
        "attribution": SW_ATTRIBUTION,
    },
    {
        "id": "sw-wild-tracking",
        "name": "ShadowWhisperer – Wild_Tracking",
        "category": "trackers",
        "repo": "ShadowWhisperer/BlockLists",
        "branch": "master",
        "commit": "626738252e16cadd32d409b63944d9601ad84ee7",
        "path": "Lists/Wild_Tracking",
        "format": "domains",
        "subdomains": True,
        "license": "Unlicense",
        "licenseUrl": "https://github.com/ShadowWhisperer/BlockLists/blob/master/LICENSE",
        "homepage": "https://github.com/ShadowWhisperer/BlockLists",
        "copyright": "",
        "attribution": SW_ATTRIBUTION,
    },
    {
        "id": "adguard-cname-original",
        "name": "AdGuard CNAME trackers (domaines d'origine)",
        "category": "trackers",
        "repo": "AdguardTeam/cname-trackers",
        "branch": "master",
        "commit": "cfb6b793591f40926a771efdd38d155d721bf2be",
        "path": "data/combined_original_trackers.txt",
        "format": "adblock",
        "subdomains": True,
        "license": "MIT",
        "licenseUrl": "https://github.com/AdguardTeam/cname-trackers/blob/master/LICENSE",
        "homepage": "https://github.com/AdguardTeam/cname-trackers",
        "copyright": "Copyright 2021 Adguard Software Ltd",
        "attribution": (
            "AdGuard CNAME disguised trackers list, "
            "https://github.com/AdguardTeam/cname-trackers, sous licence MIT. "
            "Copyright 2021 Adguard Software Ltd."
        ),
    },
    {
        "id": "adaway",
        "name": "AdAway (liste par défaut)",
        "category": "ads",
        "repo": "AdAway/adaway.github.io",
        "branch": "master",
        "commit": "f39ba0a523564447dfa94e40327c1a14c02304dc",
        "path": "hosts.txt",
        "format": "hosts",
        "subdomains": False,
        "license": "CC BY 3.0",
        "licenseUrl": "https://creativecommons.org/licenses/by/3.0/",
        "homepage": "https://github.com/AdAway/adaway.github.io",
        "copyright": "Kicelo, Dominik Schuermann et contributeurs",
        "attribution": (
            "AdAway default blocklist, par Kicelo, Dominik Schuermann et "
            "contributeurs, https://github.com/AdAway/adaway.github.io, sous "
            "licence CC BY 3.0. Modifications : converti en liste de domaines, "
            "fusionné et dédoublonné avec d'autres sources."
        ),
    },
    {
        "id": "sw-ads",
        "name": "ShadowWhisperer – Ads",
        "category": "ads",
        "repo": "ShadowWhisperer/BlockLists",
        "branch": "master",
        "commit": "626738252e16cadd32d409b63944d9601ad84ee7",
        "path": "Lists/Ads",
        "format": "domains",
        "subdomains": False,
        "license": "Unlicense",
        "licenseUrl": "https://github.com/ShadowWhisperer/BlockLists/blob/master/LICENSE",
        "homepage": "https://github.com/ShadowWhisperer/BlockLists",
        "copyright": "",
        "attribution": SW_ATTRIBUTION,
    },
    {
        "id": "sw-wild-ads",
        "name": "ShadowWhisperer – Wild_Ads",
        "category": "ads",
        "repo": "ShadowWhisperer/BlockLists",
        "branch": "master",
        "commit": "626738252e16cadd32d409b63944d9601ad84ee7",
        "path": "Lists/Wild_Ads",
        "format": "domains",
        "subdomains": True,
        "license": "Unlicense",
        "licenseUrl": "https://github.com/ShadowWhisperer/BlockLists/blob/master/LICENSE",
        "homepage": "https://github.com/ShadowWhisperer/BlockLists",
        "copyright": "",
        "attribution": SW_ATTRIBUTION,
    },
]

TAILLE_MAX = 32 * 1024 * 1024  # par source, comme sur le téléphone

LABEL_RE = re.compile(r"^[a-z0-9_]([a-z0-9_-]{0,61}[a-z0-9_])?$")
ADBLOCK_RE = re.compile(r"^\|\|([^\^$/|*]+)\^(\$important)?$")
IP_HOSTS = {"0.0.0.0", "127.0.0.1", "::", "::1", "0:0:0:0:0:0:0:0", "0:0:0:0:0:0:0:1"}
NOMS_LOCAUX = {"localhost.localdomain", "local.localdomain"}


def normaliser(nom: str) -> str | None:
    """Minuscules, punycode, sans point final ; None si invalide."""
    nom = nom.strip().rstrip(".").lower()
    if not nom:
        return None
    if not nom.isascii():
        try:
            # IDNA 2003, comme java.net.IDN côté Android.
            nom = nom.encode("idna").decode("ascii")
        except UnicodeError:
            return None
    if len(nom) > 253 or nom in NOMS_LOCAUX:
        return None
    labels = nom.split(".")
    if len(labels) < 2 or labels[-1].isdigit():
        return None  # nom sans point, ou adresse IP
    if not all(LABEL_RE.match(label) for label in labels):
        return None
    return nom


def analyser_ligne(ligne: str, fmt: str, sous_domaines: bool):
    """Renvoie (entrées, invalide) ; entrées = [(domaine, sous_domaines)]."""
    ligne = ligne.strip()
    if fmt == "adblock":
        if not ligne or ligne[0] in "!#[":
            return [], False
        m = ADBLOCK_RE.match(ligne)
        if not m:
            return [], False  # règle non DNS (cosmétique, exception…) : ignorée
        nom = normaliser(m.group(1))
        return ([(nom, True)], False) if nom else ([], True)

    ligne = ligne.split("#", 1)[0].strip()
    if not ligne:
        return [], False
    morceaux = ligne.split()
    if fmt == "hosts":
        if len(morceaux) < 2 or morceaux[0] not in IP_HOSTS:
            return [], True
        noms = morceaux[1:]
    else:
        if len(morceaux) != 1:
            return [], True
        noms = morceaux
    entrees = []
    invalide = False
    for brut in noms:
        joker = brut.startswith("*.")
        nom = normaliser(brut[2:] if joker else brut)
        if nom is None:
            if brut not in ("localhost", "broadcasthost", "local",
                            "ip6-localhost", "ip6-loopback"):
                invalide = True
            continue
        entrees.append((nom, sous_domaines or joker))
    return entrees, invalide


def parents(nom: str):
    """« a.b.c » → a.b.c, b.c, c."""
    labels = nom.split(".")
    for i in range(len(labels)):
        yield ".".join(labels[i:])


def construire(entrees, proteges: set):
    """Retire les entrées qui bloqueraient un domaine protégé et les
    doublons. Renvoie (exacts, jokers, retirés_protégés)."""
    interdits_joker = {p for nom in proteges for p in parents(nom)}
    exacts, jokers, retires = set(), set(), 0
    for nom, joker in entrees:
        if (joker and nom in interdits_joker) or (not joker and nom in proteges):
            retires += 1
        elif joker:
            jokers.add(nom)
        else:
            exacts.add(nom)
    # « *.a.b » est inutile si « *.a.b » ou « *.b » existe déjà.
    jokers = {j for j in jokers
              if not any(p in jokers for p in list(parents(j))[1:])}
    exacts = {e for e in exacts if not any(p in jokers for p in parents(e))}
    return exacts, jokers, retires


def lire_proteges() -> set:
    noms = set()
    for ligne in PROTEGES.read_text(encoding="utf-8").splitlines():
        ligne = ligne.split("#", 1)[0].strip()
        if not ligne:
            continue
        nom = normaliser(ligne)
        if nom is None:
            sys.exit(f"Domaine protégé invalide : {ligne}")
        noms.add(nom)
    return noms


def telecharger(url: str) -> bytes:
    requete = urllib.request.Request(url, headers={"User-Agent": "sentinel-blocklists"})
    with urllib.request.urlopen(requete, timeout=120) as reponse:
        donnees = reponse.read(TAILLE_MAX + 1)
    if len(donnees) > TAILLE_MAX:
        sys.exit(f"Fichier trop gros : {url}")
    return donnees


def infos_commit(depot: str, ref: str) -> dict:
    url = f"https://api.github.com/repos/{depot}/commits/{ref}"
    infos = json.loads(telecharger(url))
    return {"sha": infos["sha"], "date": infos["commit"]["committer"]["date"]}


def sha256(donnees: bytes) -> str:
    return hashlib.sha256(donnees).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--latest", action="store_true",
                        help="dernier commit de chaque dépôt au lieu des commits épinglés")
    args = parser.parse_args()
    # Console Windows : afficher les accents sans planter.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    proteges = lire_proteges()
    commits = {}  # (dépôt, ref) → infos, une requête par dépôt
    par_categorie = {c["id"]: [] for c in CATEGORIES}
    sources_manifeste = []

    for source in SOURCES:
        ref = source["branch"] if args.latest else source["commit"]
        cle = (source["repo"], ref)
        if cle not in commits:
            commits[cle] = infos_commit(source["repo"], ref)
        commit = commits[cle]
        if not args.latest and commit["sha"] != source["commit"]:
            sys.exit(f"Commit introuvable : {source['commit']}")

        url = f"https://raw.githubusercontent.com/{source['repo']}/{commit['sha']}/{source['path']}"
        print(f"Téléchargement de {url}")
        brut = telecharger(url)
        texte = brut.decode("utf-8", errors="replace")
        entrees, invalides = [], 0
        for ligne in texte.splitlines():
            trouvees, invalide = analyser_ligne(ligne, source["format"], source["subdomains"])
            entrees.extend(trouvees)
            invalides += invalide
        if not entrees:
            sys.exit(f"Aucun domaine valide dans {source['id']}")
        print(f"  {len(entrees)} entrées valides, {invalides} invalides ignorées")
        par_categorie[source["category"]].append((source["id"], entrees))

        sources_manifeste.append({
            "id": source["id"],
            "name": source["name"],
            "category": source["category"],
            "format": source["format"],
            "subdomains": source["subdomains"],
            "url": url,
            "updateUrl": (f"https://raw.githubusercontent.com/{source['repo']}/"
                          f"refs/heads/{source['branch']}/{source['path']}"),
            "commit": commit["sha"],
            "commitDate": commit["date"],
            "downloadSha256": sha256(brut),
            "parsed": len(entrees),
            "invalid": invalides,
            "license": source["license"],
            "licenseUrl": source["licenseUrl"],
            "homepage": source["homepage"],
            "copyright": source["copyright"],
            "attribution": source["attribution"],
        })
        if args.latest:
            print(f"  commit : {commit['sha']} ({commit['date']})")

    # Pas de dédoublonnage ENTRE catégories : si l'utilisateur coupe
    # « Malware », un domaine aussi présent dans « Traqueurs » reste bloqué.
    categories_manifeste = []
    for categorie in CATEGORIES:
        toutes = [e for _, liste in par_categorie[categorie["id"]] for e in liste]
        exacts, jokers, retires = construire(toutes, proteges)
        lignes = sorted([f"*.{j}" for j in jokers] + list(exacts))
        contenu = ("\n".join(lignes) + "\n").encode("ascii")
        fichier = f"{categorie['id']}.txt"
        (SORTIE / fichier).write_bytes(contenu)
        print(f"{categorie['name']} : {len(lignes)} entrées "
              f"({len(exacts)} exactes, {len(jokers)} avec sous-domaines), "
              f"{retires} retirées car protégées -> {fichier}")
        categories_manifeste.append({
            **categorie,
            "file": fichier,
            "entries": len(lignes),
            "exact": len(exacts),
            "wildcard": len(jokers),
            "removedProtected": retires,
            "bytes": len(contenu),
            "sha256": sha256(contenu),
        })

    manifeste = {
        "formatVersion": 1,
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "categories": categories_manifeste,
        "sources": sources_manifeste,
        "protected": {
            "file": PROTEGES.name,
            "domains": len(proteges),
            "sha256": sha256(PROTEGES.read_bytes()),
        },
    }
    (SORTIE / "manifest.json").write_text(
        json.dumps(manifeste, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"Manifeste -> {(SORTIE / 'manifest.json').relative_to(RACINE)}")


if __name__ == "__main__":
    main()
