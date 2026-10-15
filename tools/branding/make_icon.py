"""Génère l'icône officielle de Sentinel (v2 « nuit » : arche de Sidi Bou Saïd
+ trou de serrure) et ses déclinaisons pour Android, Windows et le splash.

Usage (depuis la racine du projet) :
    tools/.venv/Scripts/python tools/branding/make_icon.py
puis :
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create

Les images sont dessinées en 4x puis réduites (LANCZOS) pour des bords nets.
Sortie : assets/branding/ (les anciennes propositions restent dans preview/).
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

# Taille finale et facteur de suréchantillonnage
TAILLE = 1024
ECHELLE = 4
S = TAILLE * ECHELLE

# Proportions de l'arche (par rapport au canevas)
LARGEUR_ARCHE = 0.46
HAUTEUR_ARCHE = 0.58
PART_BASSE = 0.65  # partie basse de l'arche, où se place la serrure

# Icônes adaptatives : motif réduit pour tenir, halo compris,
# dans les 66 % centraux du calque (zone de sécurité Android).
ECHELLE_ADAPTATIVE = 0.75
ZONE_SECURITE = 0.66

# Couleurs de la v2
NUIT = "#0E1A33"
NUIT_CENTRE = "#1A2C52"
ARCHE = "#2F7AD6"
HALO = "#7FB2F0"
BLANC = "#FFFFFF"

RACINE = Path(__file__).resolve().parents[2]
SORTIE = RACINE / "assets" / "branding"


def hexa(couleur: str, alpha: int = 255) -> tuple[int, int, int, int]:
    """Convertit '#RRGGBB' en tuple RGBA."""
    c = couleur.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), alpha)


def boite_arche(k: float) -> tuple[float, float, float, float]:
    """Rectangle englobant de l'arche (k = échelle du motif), centré."""
    largeur = S * LARGEUR_ARCHE * k
    hauteur = S * HAUTEUR_ARCHE * k
    gauche = (S - largeur) / 2
    haut = (S - hauteur) / 2
    return gauche, haut, gauche + largeur, haut + hauteur


def masque_arche(k: float) -> Image.Image:
    """Masque de l'arche : rectangle surmonté d'un demi-cercle."""
    g, h, d, b = boite_arche(k)
    rayon = (d - g) / 2
    masque = Image.new("L", (S, S), 0)
    dessin = ImageDraw.Draw(masque)
    # Demi-cercle du haut (on dessine le cercle entier, le bas est recouvert)
    dessin.ellipse((g, h, d, h + 2 * rayon), fill=255)
    # Corps rectangulaire, à partir du centre du cercle
    dessin.rectangle((g, h + rayon, d, b), fill=255)
    return masque


def masque_serrure(k: float) -> Image.Image:
    """Trou de serrure (cercle + trapèze qui s'élargit vers le bas),
    centré dans la partie basse de l'arche."""
    g, h, d, b = boite_arche(k)
    largeur = d - g
    haut_bas = b - (b - h) * PART_BASSE
    cx = S / 2
    cy = (haut_bas + b) / 2  # centre vertical de la partie basse

    rayon = largeur * 0.13
    haut_trapeze = rayon * 2.1
    demi_haut = rayon * 0.45  # demi-largeur en haut du trapèze
    demi_bas = rayon * 0.85  # demi-largeur en bas du trapèze

    # On centre l'ensemble (cercle + trapèze) verticalement sur cy
    hauteur_totale = rayon + haut_trapeze + rayon * 0.6
    centre_cercle = cy - hauteur_totale / 2 + rayon
    y_haut = centre_cercle + rayon * 0.6
    y_bas = y_haut + haut_trapeze

    masque = Image.new("L", (S, S), 0)
    dessin = ImageDraw.Draw(masque)
    dessin.ellipse(
        (cx - rayon, centre_cercle - rayon, cx + rayon, centre_cercle + rayon),
        fill=255,
    )
    dessin.polygon(
        [
            (cx - demi_haut, y_haut - rayon * 0.6),
            (cx + demi_haut, y_haut - rayon * 0.6),
            (cx + demi_bas, y_bas),
            (cx - demi_bas, y_bas),
        ],
        fill=255,
    )
    return masque


def peindre(fond: Image.Image, couleur, masque: Image.Image) -> None:
    """Peint une couleur unie sur le fond à travers un masque."""
    calque = Image.new("RGBA", (S, S), couleur)
    fond.paste(calque, (0, 0), masque)


def calque_flou(couleur, masque: Image.Image, rayon: float, opacite: float) -> Image.Image:
    """Halo : masque flouté, teinté et atténué."""
    flou = masque.filter(ImageFilter.GaussianBlur(rayon))
    flou = flou.point(lambda v: int(v * opacite))
    calque = Image.new("RGBA", (S, S), couleur)
    calque.putalpha(flou)
    return calque


def fond_nuit() -> Image.Image:
    """Fond bleu nuit avec un dégradé radial très léger (plus clair au centre)."""
    nuit = Image.new("RGBA", (S, S), hexa(NUIT))
    centre = Image.new("RGBA", (S, S), hexa(NUIT_CENTRE))
    # radial_gradient : 0 au centre, 255 au bord -> on inverse pour le masque
    degrade = Image.radial_gradient("L").resize((S, S), Image.Resampling.BICUBIC)
    degrade = degrade.point(lambda v: max(0, 255 - int(v * 1.4)))
    return Image.composite(centre, nuit, degrade)


def motif(fond: Image.Image, k: float) -> Image.Image:
    """Dessine arche + halo + serrure (échelle k) par-dessus le fond."""
    arche = masque_arche(k)
    # Halo bleu clair doux autour de l'arche
    img = Image.alpha_composite(fond, calque_flou(hexa(HALO), arche, S * 0.04 * k, 0.45))
    peindre(img, hexa(ARCHE), arche)

    serrure = masque_serrure(k)
    # Lueur blanche autour du trou de serrure
    img = Image.alpha_composite(img, calque_flou(hexa(BLANC), serrure, S * 0.012 * k, 0.55))
    peindre(img, hexa(BLANC), serrure)
    return img


def transparent() -> Image.Image:
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def icone_complete() -> Image.Image:
    """Identique à preview/v2_nuit.png."""
    return motif(fond_nuit(), 1.0)


def icone_premier_plan() -> Image.Image:
    return motif(transparent(), ECHELLE_ADAPTATIVE)


def icone_monochrome() -> Image.Image:
    """Silhouette de l'arche d'une seule couleur, serrure découpée, sans halo."""
    img = transparent()
    silhouette = ImageChops.subtract(
        masque_arche(ECHELLE_ADAPTATIVE), masque_serrure(ECHELLE_ADAPTATIVE)
    )
    peindre(img, hexa(BLANC), silhouette)
    return img


def reduire(img: Image.Image, opaque: bool) -> Image.Image:
    """Réduit l'image 4x vers 1024 (RGB si opaque, sinon RGBA)."""
    if opaque:
        img = img.convert("RGB")
    return img.resize((TAILLE, TAILLE), Image.Resampling.LANCZOS)


def verifier_zone(img: Image.Image, nom: str) -> None:
    """Vérifie que tout le contenu visible tient dans la zone de sécurité."""
    alpha = img.getchannel("A").point(lambda v: 255 if v > 2 else 0)
    g, h, d, b = alpha.getbbox()
    marge = TAILLE * (1 - ZONE_SECURITE) / 2
    dedans = min(g, h) >= marge and max(d, b) <= TAILLE - marge
    etat = "ok" if dedans else "HORS ZONE"
    print(f"  {nom} : contenu {g}..{d} x {h}..{b} (zone {marge:.0f}..{TAILLE - marge:.0f}) {etat}")
    if not dedans:
        raise SystemExit(f"{nom} dépasse la zone de sécurité")


def main() -> None:
    SORTIE.mkdir(parents=True, exist_ok=True)
    fichiers = (
        ("icon_full", icone_complete, True),
        ("icon_background", fond_nuit, True),
        ("icon_foreground", icone_premier_plan, False),
        ("icon_monochrome", icone_monochrome, False),
    )
    for nom, fabrique, opaque in fichiers:
        img = reduire(fabrique(), opaque)
        if not opaque:
            verifier_zone(img, nom)
        chemin = SORTIE / f"{nom}.png"
        img.save(chemin, optimize=True)
        print(chemin.relative_to(RACINE))


if __name__ == "__main__":
    main()
