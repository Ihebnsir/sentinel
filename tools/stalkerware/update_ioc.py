"""Génère assets/data/stalkerware_ioc.json à partir des indicateurs publics
du projet AssoEchap/stalkerware-indicators (licence CC BY 4.0).

Usage (depuis la racine du projet) :
    tools/.venv/Scripts/python -I tools/stalkerware/update_ioc.py
    tools/.venv/Scripts/python -I tools/stalkerware/update_ioc.py --commit <sha>

Le fichier ioc.yaml est téléchargé à un commit ÉPINGLÉ (jamais « master ») :
le résultat est reproductible et une modification en amont ne peut pas
entrer dans l'app sans relecture. Pour mettre à jour : choisir un commit
récent sur GitHub, relire le diff de ioc.yaml, changer COMMIT ci-dessous,
relancer le script et relire le diff du JSON.

On garde seulement : nom de l'app, noms de packages, empreintes SHA-1 des
certificats. Les sites web et serveurs (C2) ne servent pas dans l'app.
"""

import argparse
import json
import re
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import yaml

DEPOT = "AssoEchap/stalkerware-indicators"
# Commit épinglé (9 octobre 2026).
COMMIT = "a15f0ed88a78076b2442f3620239e751c9a3af69"

RACINE = Path(__file__).resolve().parents[2]
SORTIE = RACINE / "assets" / "data" / "stalkerware_ioc.json"

LICENCE = "CC BY 4.0"
LICENCE_URL = "https://creativecommons.org/licenses/by/4.0/"
ATTRIBUTION = (
    "Stalkerware Indicators of Compromise, par Echap "
    "(Julien Voisin, Tek et contributeurs), "
    "https://github.com/AssoEchap/stalkerware-indicators, sous licence "
    "CC BY 4.0. Modifications : seuls les noms, packages et empreintes "
    "SHA-1 de certificats sont conservés, au format JSON."
)

# Formats attendus : tout le reste est rejeté.
PACKAGE_RE = re.compile(r"^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$")
SHA1_RE = re.compile(r"^[0-9A-Fa-f]{40}$")


def telecharger(url: str) -> bytes:
    requete = urllib.request.Request(url, headers={"User-Agent": "sentinel-ioc"})
    with urllib.request.urlopen(requete, timeout=60) as reponse:
        return reponse.read()


def date_du_commit(commit: str) -> str:
    """Date du commit (UTC, ISO 8601) via l'API GitHub."""
    url = f"https://api.github.com/repos/{DEPOT}/commits/{commit}"
    infos = json.loads(telecharger(url))
    if infos.get("sha") != commit:
        sys.exit(f"Commit introuvable : {commit}")
    return infos["commit"]["committer"]["date"]


def liste(entree: dict, cle: str) -> list:
    valeur = entree.get(cle) or []
    return valeur if isinstance(valeur, list) else []


def extraire(iocs: list) -> list:
    """Garde les entrées « stalkerware » avec au moins un indicateur valide."""
    apps = []
    rejetes = 0
    for entree in iocs:
        if not isinstance(entree, dict) or entree.get("type") != "stalkerware":
            continue
        packages = []
        for p in liste(entree, "packages"):
            if isinstance(p, str) and PACKAGE_RE.match(p):
                packages.append(p)
            else:
                rejetes += 1
        certificats = []
        for c in liste(entree, "certificates"):
            if isinstance(c, str) and SHA1_RE.match(c):
                certificats.append(c.upper())
            else:
                rejetes += 1
        if not packages and not certificats:
            continue
        apps.append({
            "name": str(entree.get("name", "?")),
            "packages": sorted(set(packages)),
            "certificatesSha1": sorted(set(certificats)),
        })
    if rejetes:
        print(f"{rejetes} indicateur(s) au format inattendu ignoré(s)")
    return sorted(apps, key=lambda a: a["name"].lower())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--commit", default=COMMIT, help="commit à utiliser")
    args = parser.parse_args()
    # Console Windows : afficher les accents sans planter.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if not re.fullmatch(r"[0-9a-f]{40}", args.commit):
        sys.exit("Le commit doit être un SHA complet de 40 caractères.")

    url = f"https://raw.githubusercontent.com/{DEPOT}/{args.commit}/ioc.yaml"
    print(f"Téléchargement de {url}")
    # safe_load : le YAML ne peut pas créer d'objets Python arbitraires.
    iocs = yaml.safe_load(telecharger(url))
    if not isinstance(iocs, list):
        sys.exit("Format inattendu : ioc.yaml devrait être une liste.")

    apps = extraire(iocs)
    donnees = {
        "source": f"https://github.com/{DEPOT}",
        "file": "ioc.yaml",
        "commit": args.commit,
        "commitDate": date_du_commit(args.commit),
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "license": LICENCE,
        "licenseUrl": LICENCE_URL,
        "attribution": ATTRIBUTION,
        "apps": apps,
    }
    SORTIE.parent.mkdir(parents=True, exist_ok=True)
    SORTIE.write_text(
        json.dumps(donnees, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    nb_packages = sum(len(a["packages"]) for a in apps)
    nb_certs = sum(len(a["certificatesSha1"]) for a in apps)
    print(f"{len(apps)} applications, {nb_packages} packages, "
          f"{nb_certs} certificats -> {SORTIE.relative_to(RACINE)}")


if __name__ == "__main__":
    main()
