"""Affiche les empreintes (SHA-256 et SHA-1) du certificat de signature d'un
APK, pour remplir lib/services/apps/known_apps.dart de façon vérifiable.

Usage (depuis la racine du projet) :
    python -I tools/signatures/extract_cert.py chemin/vers/app.apk
    python -I tools/signatures/extract_cert.py --adb com.whatsapp

Avec --adb, l'APK est copié depuis le téléphone branché (débogage USB
activé). Installez d'abord l'app depuis le Play Store : le script affiche
l'installateur pour le confirmer.

Ce script LIT le certificat sans vérifier la signature. Sur une app
installée, Android l'a déjà vérifiée. Sur un APK téléchargé, contrôlez
avec « apksigner verify --print-certs app.apk » (Android SDK).

Aucune dépendance : lecture du bloc de signature APK v2/v3, sinon v1
(META-INF/*.RSA, *.DSA, *.EC).
"""

import argparse
import hashlib
import struct
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

MAGIE = b"APK Sig Block 42"
ID_V2 = 0x7109871A
ID_V3 = 0xF05368C0
ID_V31 = 0x1B93AD61

# Champs du sujet affichés (OID → nom court).
OIDS = {"2.5.4.3": "CN", "2.5.4.10": "O", "2.5.4.11": "OU", "2.5.4.6": "C"}


# --- Lecture DER minimale (ASN.1) -------------------------------------------

def tlv(data: bytes, pos: int) -> tuple:
    """Lit un élément DER : (étiquette, début du contenu, fin)."""
    tag = data[pos]
    pos += 1
    longueur = data[pos]
    pos += 1
    if longueur & 0x80:
        n = longueur & 0x7F
        longueur = int.from_bytes(data[pos:pos + n], "big")
        pos += n
    return tag, pos, pos + longueur


def enfants(data: bytes, debut: int, fin: int) -> list:
    """Les éléments contenus dans [debut, fin)."""
    res = []
    while debut < fin:
        tag, c, f = tlv(data, debut)
        res.append((tag, c, f, debut))
        debut = f
    return res


def oid(octets: bytes) -> str:
    parts = [octets[0] // 40, octets[0] % 40]
    valeur = 0
    for b in octets[1:]:
        valeur = (valeur << 7) | (b & 0x7F)
        if not b & 0x80:
            parts.append(valeur)
            valeur = 0
    return ".".join(map(str, parts))


def sujet(cert: bytes) -> dict:
    """Champs du sujet du certificat X.509 (CN, O…)."""
    _, c, f = tlv(cert, 0)  # Certificate
    tag, c, f, _ = enfants(cert, c, f)[0]  # TBSCertificate
    champs = enfants(cert, c, f)
    if champs[0][0] == 0xA0:  # [0] version présente
        champs = champs[1:]
    # serial, signature, issuer, validity, subject
    _, c, f, _ = champs[4]
    res = {}
    for _, sc, sf, _ in enfants(cert, c, f):  # SET
        for _, ac, af, _ in enfants(cert, sc, sf):  # SEQUENCE {oid, valeur}
            (_, oc, of_, _), (_, vc, vf, _) = enfants(cert, ac, af)[:2]
            nom = OIDS.get(oid(cert[oc:of_]))
            if nom and nom not in res:
                res[nom] = cert[vc:vf].decode("utf-8", "replace")
    return res


def certs_pkcs7(data: bytes) -> list:
    """Certificats d'une signature PKCS#7 (signature v1)."""
    _, c, f = tlv(data, 0)  # ContentInfo
    elems = enfants(data, c, f)
    _, c, f, _ = elems[1]  # [0] EXPLICIT
    _, c, f = tlv(data, c)  # SignedData
    for tag, cc, cf, _ in enfants(data, c, f):
        if tag == 0xA0:  # [0] IMPLICIT certificates
            return [data[d:fin] for _, _, fin, d in enfants(data, cc, cf)]
    return []


# --- Bloc de signature APK v2/v3 --------------------------------------------

def prefixe(data: bytes, pos: int) -> tuple:
    """Bloc précédé de sa longueur (uint32) : (contenu, position suivante)."""
    (n,) = struct.unpack_from("<I", data, pos)
    return data[pos + 4:pos + 4 + n], pos + 4 + n


def sequence(data: bytes) -> list:
    res, pos = [], 0
    while pos < len(data):
        elem, pos = prefixe(data, pos)
        res.append(elem)
    return res


def bloc_signature(apk: bytes):
    """Paires (id, valeur) du bloc de signature APK, ou None (v1 seule)."""
    eocd = apk.rfind(b"PK\x05\x06")
    if eocd < 0:
        sys.exit("Fichier ZIP invalide.")
    (debut_cd,) = struct.unpack_from("<I", apk, eocd + 16)
    if apk[debut_cd - 16:debut_cd] != MAGIE:
        return None
    (taille,) = struct.unpack_from("<Q", apk, debut_cd - 24)
    debut = debut_cd - taille - 8
    paires, pos = {}, debut + 8
    while pos < debut_cd - 24:
        (n,) = struct.unpack_from("<Q", apk, pos)
        (ident,) = struct.unpack_from("<I", apk, pos + 8)
        paires[ident] = apk[pos + 12:pos + 8 + n]
        pos += 8 + n
    return paires


def certs_v2_v3(valeur: bytes) -> list:
    """Certificats de chaque signataire (signed data → certificates)."""
    res = []
    for signataire in sequence(prefixe(valeur, 0)[0]):
        donnees, _ = prefixe(signataire, 0)
        _, pos = prefixe(donnees, 0)  # digests
        certificats, _ = prefixe(donnees, pos)
        res.extend(sequence(certificats))
    return res


def certificats(chemin: Path) -> tuple:
    """(schéma, liste des certificats DER) d'un APK."""
    apk = chemin.read_bytes()
    paires = bloc_signature(apk)
    if paires:
        for ident, nom in ((ID_V31, "v3.1"), (ID_V3, "v3"), (ID_V2, "v2")):
            if ident in paires:
                return nom, certs_v2_v3(paires[ident])
    with zipfile.ZipFile(chemin) as z:
        for nom in z.namelist():
            if nom.startswith("META-INF/") and nom.upper().endswith(
                (".RSA", ".DSA", ".EC")
            ):
                return "v1", certs_pkcs7(z.read(nom))
    sys.exit("Aucune signature trouvée dans cet APK.")


# --- adb ---------------------------------------------------------------------

def adb(*args: str) -> str:
    try:
        sortie = subprocess.run(
            ["adb", *args], capture_output=True, text=True, check=True
        )
    except FileNotFoundError:
        sys.exit("adb introuvable : installez les Android platform-tools.")
    except subprocess.CalledProcessError as e:
        sys.exit(f"adb a échoué : {e.stderr.strip()}")
    return sortie.stdout


def apk_depuis_adb(package: str, dossier: Path) -> Path:
    chemins = [
        ligne.removeprefix("package:").strip()
        for ligne in adb("shell", "pm", "path", package).splitlines()
        if ligne.startswith("package:")
    ]
    base = next((c for c in chemins if c.endswith("/base.apk")), None)
    if not base:
        sys.exit(f"Package introuvable sur le téléphone : {package}")
    for ligne in adb("shell", "pm", "list", "packages", "-i", package).splitlines():
        if ligne.split()[0] == f"package:{package}":
            print(f"Installateur : {ligne.partition('installer=')[2] or '?'}")
    destination = dossier / "base.apk"
    adb("pull", base, str(destination))
    return destination


def afficher(chemin: Path) -> None:
    schema, certs = certificats(chemin)
    print(f"Schéma de signature : {schema}")
    for i, cert in enumerate(certs, 1):
        champs = sujet(cert)
        print(f"\nCertificat {i}")
        print(f"  Sujet   : {', '.join(f'{k}={v}' for k, v in champs.items())}")
        print(f"  SHA-256 : {hashlib.sha256(cert).hexdigest().upper()}")
        print(f"  SHA-1   : {hashlib.sha1(cert).hexdigest().upper()}")
    if certs:
        print("\nPour known_apps.dart :")
        empreintes = ", ".join(
            f"'{hashlib.sha256(c).hexdigest().upper()}'" for c in certs
        )
        print(f"  certSha256: [{empreintes}],")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("cible", help="chemin d'un APK, ou package avec --adb")
    parser.add_argument("--adb", action="store_true",
                        help="copier l'APK depuis le téléphone branché")
    args = parser.parse_args()
    if args.adb:
        with tempfile.TemporaryDirectory() as dossier:
            afficher(apk_depuis_adb(args.cible, Path(dossier)))
    else:
        afficher(Path(args.cible))


if __name__ == "__main__":
    main()
