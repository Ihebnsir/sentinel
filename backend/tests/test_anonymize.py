"""Anonymisation : tous les cas partagés avec le téléphone (fixtures JSON)."""

import json
from pathlib import Path

import pytest

from app.anonymize import anonymize, luhn_valid

CASES_FILE = Path(__file__).parent / "fixtures" / "anonymize_cases.json"
CASES = json.loads(CASES_FILE.read_text(encoding="utf-8"))["cases"]


def test_fichier_de_cas_complet() -> None:
    assert len(CASES) >= 60
    ids = [c["id"] for c in CASES]
    assert len(ids) == len(set(ids)), "identifiants en double"
    # Beaucoup de cas en arabe (lettres arabes dans l'entrée).
    arabic = [c for c in CASES if any("؀" <= ch <= "ۿ" for ch in c["input"])]
    assert len(arabic) >= 12


@pytest.mark.parametrize("case", CASES, ids=[c["id"] for c in CASES])
def test_cas_partages(case: dict[str, str]) -> None:
    assert anonymize(case["input"]) == case["expected"]


@pytest.mark.parametrize("case", CASES, ids=[c["id"] for c in CASES])
def test_idempotent(case: dict[str, str]) -> None:
    # Ré-anonymiser un texte déjà traité ne change plus rien.
    assert anonymize(case["expected"]) == case["expected"]


def test_luhn() -> None:
    assert luhn_valid([4] + [1] * 15)  # 4111 1111 1111 1111
    assert not luhn_valid([1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4, 5, 7])
