"""Génère l'image d'aperçu social du dépôt GitHub (1280 x 640) :
icône (arche de Sidi Bou Saïd), nom, promesse et deux captures d'écran.

Usage (depuis la racine du projet) :
    tools/.venv/Scripts/python tools/branding/make_social_preview.py
Sortie : docs/branding/social-preview.png (à choisir dans GitHub,
Settings > General > Social preview).

Entrées : assets/branding/icon_full.png, docs/screenshots/*.png (données
fictives) et la police Readex Pro embarquée. Dessin en 2x puis réduit.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RACINE = Path(__file__).resolve().parents[2]
SORTIE = RACINE / "docs" / "branding" / "social-preview.png"
POLICE = RACINE / "assets" / "fonts" / "ReadexPro-Regular.ttf"
ICONE = RACINE / "assets" / "branding" / "icon_full.png"
CAPTURES = [
    RACINE / "docs" / "screenshots" / "home.png",
    RACINE / "docs" / "screenshots" / "links.png",
]

LARGEUR, HAUTEUR = 1280, 640
K = 2  # suréchantillonnage

# Couleurs de l'icône v2 « nuit » et du bleu des portes de Sidi Bou.
NUIT = (14, 26, 51)
NUIT_CENTRE = (26, 44, 82)
BLEU = (47, 122, 214)
HALO = (127, 178, 240)
BLANC = (255, 255, 255)
GRIS = (190, 204, 226)

PROMESSE = ["Your phone's security,", "checked on the phone itself."]
DETAIL = "Phone audit · App scanner · Links & QR codes · DNS firewall · Vault"
# Pas de texte arabe ici : Pillow sans libraqm ne lie pas les lettres arabes.
PIED = "Android 7+  ·  French · Arabic · English  ·  Open source"


def police(taille: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(POLICE), taille * K)


def fond() -> Image.Image:
    """Dégradé radial nuit, plus clair derrière les captures."""
    w, h = LARGEUR * K, HAUTEUR * K
    image = Image.new("RGB", (w, h), NUIT)
    halo = Image.new("L", (w, h), 0)
    ImageDraw.Draw(halo).ellipse((w * 0.45, -h * 0.4, w * 1.25, h * 1.4), fill=255)
    halo = halo.filter(ImageFilter.GaussianBlur(160 * K))
    return Image.composite(Image.new("RGB", (w, h), NUIT_CENTRE), image, halo)


def arches_decor(image: Image.Image) -> None:
    """Fines arches en filigrane, rappel des portes de Sidi Bou Saïd."""
    calque = Image.new("RGBA", image.size, (0, 0, 0, 0))
    dessin = ImageDraw.Draw(calque)
    for i, x in enumerate((40, 140)):
        largeur, haut = 70 * K, (470 + 40 * i) * K
        g = x * K
        dessin.arc((g, haut, g + largeur, haut + largeur), 180, 360, fill=(*HALO, 40), width=2 * K)
        dessin.line((g, haut + largeur / 2, g, HAUTEUR * K), fill=(*HALO, 40), width=2 * K)
        dessin.line((g + largeur, haut + largeur / 2, g + largeur, HAUTEUR * K), fill=(*HALO, 40), width=2 * K)
    image.paste(calque, (0, 0), calque)


def telephone(capture: Path, hauteur: int) -> Image.Image:
    """Capture aux coins arrondis, avec un fin cadre et une ombre douce."""
    ecran = Image.open(capture).convert("RGB")
    largeur = round(ecran.width * hauteur / ecran.height)
    ecran = ecran.resize((largeur, hauteur), Image.LANCZOS)
    rayon = 34 * K
    masque = Image.new("L", ecran.size, 0)
    ImageDraw.Draw(masque).rounded_rectangle((0, 0, largeur - 1, hauteur - 1), rayon, fill=255)
    marge = 40 * K
    bloc = Image.new("RGBA", (largeur + 2 * marge, hauteur + 2 * marge), (0, 0, 0, 0))
    ombre = Image.new("L", bloc.size, 0)
    ImageDraw.Draw(ombre).rounded_rectangle(
        (marge, marge + 12 * K, marge + largeur, marge + hauteur + 12 * K), rayon, fill=150
    )
    ombre = ombre.filter(ImageFilter.GaussianBlur(18 * K))
    bloc.paste(Image.new("RGBA", bloc.size, (0, 0, 0, 255)), (0, 0), ombre)
    cadre = Image.new("RGBA", (largeur + 6 * K, hauteur + 6 * K), (0, 0, 0, 0))
    ImageDraw.Draw(cadre).rounded_rectangle(
        (0, 0, cadre.width - 1, cadre.height - 1), rayon + 3 * K, fill=(*HALO, 90)
    )
    bloc.paste(cadre, (marge - 3 * K, marge - 3 * K), cadre)
    bloc.paste(ecran, (marge, marge), masque)
    return bloc


def texte_gras(dessin: ImageDraw.ImageDraw, xy, texte, taille, couleur) -> None:
    # Une seule graisse embarquée : le gras est simulé par un contour.
    dessin.text(xy, texte, font=police(taille), fill=couleur, stroke_width=K, stroke_fill=couleur)


def main() -> None:
    image = fond()
    arches_decor(image)
    dessin = ImageDraw.Draw(image)

    icone = Image.open(ICONE).convert("RGBA").resize((132 * K, 132 * K), Image.LANCZOS)
    masque_icone = Image.new("L", icone.size, 0)
    ImageDraw.Draw(masque_icone).rounded_rectangle((0, 0, icone.width - 1, icone.height - 1), 30 * K, fill=255)
    image.paste(icone, (72 * K, 92 * K), masque_icone)

    texte_gras(dessin, (72 * K, 250 * K), "Sentinel", 76, BLANC)
    y = 362
    for ligne in PROMESSE:
        dessin.text((72 * K, y * K), ligne, font=police(32), fill=HALO)
        y += 44
    dessin.text((72 * K, 476 * K), DETAIL, font=police(17), fill=GRIS)
    # Petit trait bleu, comme les séparateurs fins de l'app.
    dessin.line((72 * K, 520 * K, 132 * K, 520 * K), fill=BLEU, width=3 * K)
    dessin.text((72 * K, 540 * K), PIED, font=police(17), fill=GRIS)

    hauteur = 560 * K
    gauche, droite = telephone(CAPTURES[0], hauteur), telephone(CAPTURES[1], hauteur)
    marge = 40 * K
    x_droite = LARGEUR * K - droite.width + marge - 36 * K
    x_gauche = x_droite - gauche.width + 2 * marge - 26 * K
    image.paste(gauche, (x_gauche, 40 * K - marge + 20 * K), gauche)
    image.paste(droite, (x_droite, 40 * K - marge), droite)

    SORTIE.parent.mkdir(parents=True, exist_ok=True)
    image.resize((LARGEUR, HAUTEUR), Image.LANCZOS).save(SORTIE, optimize=True)
    print(f"{SORTIE.relative_to(RACINE)} ({LARGEUR} x {HAUTEUR})")


if __name__ == "__main__":
    main()
