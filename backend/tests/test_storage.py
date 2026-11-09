"""Base et journaux : rien de personnel n'est écrit, schéma conforme."""

import datetime as dt
import logging
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import inspect

from app.anonymize import ANONYMIZER_VERSION
from app.logging_config import RedactIpFilter

from .conftest import CLIENT_IP, engine_for, sqlite_only, valid_report

PERSONAL_TEXT = (
    "Appelle 98 123 456 ou écris à sami.trabelsi@gmail.com, carte 4111 1111 1111 1111, "
    "code 482910, lien https://poste-tn.xyz/suivi?cin=09876543 @sami_t"
)
PERSONAL_BITS = [
    "98 123 456",
    "sami.trabelsi",
    "4111",
    "482910",
    "suivi",
    "09876543",
    "@sami_t",
    CLIENT_IP,
]


def test_colonnes_attendues_seulement(db_url: str, client: TestClient) -> None:
    engine = engine_for(db_url)
    columns = {c["name"] for c in inspect(engine).get_columns("reports")}
    engine.dispose()
    assert columns == {
        "id",
        "text",
        "verdict",
        "probability",
        "language",
        "source",
        "app_version",
        "user_feedback",
        "received_on",
        "review_status",
        "anonymizer_version",
        "fingerprint",
        "count",
        "exported_on",
    }


def test_rien_de_personnel_en_base(
    client: TestClient, rows: Callable[[], list[dict[str, Any]]]
) -> None:
    assert client.post("/v1/reports", json=valid_report(text=PERSONAL_TEXT)).status_code == 201
    (row,) = rows()
    assert row["text"] == (
        "Appelle [TEL] ou écris à [EMAIL], carte [CARTE], "
        "code [CODE], lien https://poste-tn.xyz/[CHEMIN] [USER]"
    )
    assert row["review_status"] == "nouveau"
    assert row["anonymizer_version"] == ANONYMIZER_VERSION
    # Jour seulement, sans heure.
    assert row["received_on"] == dt.datetime.now(dt.UTC).date().isoformat()
    for key, value in row.items():
        if key in ("id", "fingerprint"):  # hexadécimal aléatoire / HMAC
            continue
        for bit in PERSONAL_BITS:
            assert bit not in str(value), bit


@sqlite_only
def test_rien_de_personnel_dans_le_fichier(db_path: Path, client: TestClient) -> None:
    assert client.post("/v1/reports", json=valid_report(text=PERSONAL_TEXT)).status_code == 201
    # Nulle part dans le fichier (pages libres comprises).
    raw = db_path.read_bytes()
    for bit in PERSONAL_BITS:
        assert bit.encode() not in raw, bit


@pytest.mark.parametrize("level", [logging.DEBUG])
def test_aucune_ip_ni_texte_dans_les_journaux(
    make_client: Callable[..., TestClient], caplog: pytest.LogCaptureFixture, level: int
) -> None:
    client = make_client(rate_limit_per_window=1)
    with caplog.at_level(level):
        client.post("/v1/reports", json=valid_report(text=PERSONAL_TEXT))
        client.post("/v1/reports", json=valid_report(text=PERSONAL_TEXT))  # 429
        client.post("/v1/reports", json=valid_report(text=PERSONAL_TEXT, verdict="x"))  # 422
    assert caplog.records, "le journal d'accès doit écrire quelque chose"
    everything = "\n".join(r.getMessage() for r in caplog.records)
    assert "POST /v1/reports 201" in everything
    assert "POST /v1/reports 429" in everything
    for bit in [*PERSONAL_BITS, "poste-tn", "Appelle"]:
        assert bit not in everything, bit


def test_filtre_efface_les_ip() -> None:
    record = logging.LogRecord(
        "x", logging.WARNING, __file__, 1, "client %s:%d refusé", ("203.0.113.5", 4242), None
    )
    assert RedactIpFilter().filter(record)
    assert record.getMessage() == "client [IP] refusé"


def test_erreur_base_sans_detail(
    make_client: Callable[..., TestClient],
    sql: Callable[..., Any],
    caplog: pytest.LogCaptureFixture,
) -> None:
    client = make_client()
    sql("DROP TABLE reports")
    with caplog.at_level(logging.DEBUG):
        response = client.post("/v1/reports", json=valid_report(text=PERSONAL_TEXT))
    assert response.status_code == 500
    assert response.json() == {"detail": "erreur interne"}
    everything = "\n".join(r.getMessage() for r in caplog.records)
    # OperationalError (SQLite) ou ProgrammingError (PostgreSQL) : le type seul.
    assert "Error" in everything
    assert "poste-tn" not in everything and "INSERT" not in everything
