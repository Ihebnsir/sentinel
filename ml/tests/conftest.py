"""Petites données factices pour tester retrain.py (aucune vraie donnée, aucune base)."""

import random
import sys
from pathlib import Path

import pandas as pd
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import retrain  # noqa: E402

# Vocabulaires : chaque message = mots tirés au hasard (graine fixe).
SCAM = ["payez", "colis", "bloqué", "gagné", "cliquez", "urgent", "compte", "suspendu",
        "code", "vérifiez", "lien", "amende", "cadeau", "iphone", "frais", "bit.ly/x",
        "promo.xyz", "banque", "confirmez", "dernier avis", "réclamez", "virement"]
OK = ["demain", "café", "merci", "repas", "maison", "soir", "réunion", "pain", "bisous",
      "dentiste", "école", "match", "voiture", "anniversaire", "plage", "travail",
      "rentre", "déjeuner", "photos", "week-end", "cinéma", "marché"]


def make(words: list[str], label: int, count: int, source: str, offset: int = 0):
    rng = random.Random(1000 * label + offset)
    return [{"text": " ".join(rng.sample(words, 7)), "label": label, "langue": "fr",
             "source": source} for _ in range(count)]


def write(df: pd.DataFrame, path: Path) -> None:
    retrain.write_csv(df, path)


@pytest.fixture
def paths(tmp_path: Path) -> retrain.Paths:
    p = retrain.Paths(seed=tmp_path / "seed.csv", perso=tmp_path / "perso.csv",
                      frozen=tmp_path / "fige.csv", model=tmp_path / "model.json",
                      parity=tmp_path / "parity.json", reports=tmp_path / "reports")
    seed = pd.DataFrame(make(SCAM, 1, 36, "synthetique") + make(OK, 0, 36, "synthetique"))
    perso = pd.DataFrame(make(SCAM, 1, 15, "reel", 500) + make(OK, 0, 15, "reel", 500))
    write(seed, p.seed)
    write(perso, p.perso)
    return p
