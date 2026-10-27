"""Base de données : rien de sensible n'est écrit, migrations à jour."""

import datetime as dt
import sqlite3
from collections.abc import Callable
from pathlib import Path

from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from fastapi.testclient import TestClient
from sqlalchemy import create_engine

from app.anonymize import ANONYMIZER_VERSION
from app.db import upgrade
from app.models import Base
from tests.conftest import valid_report

SENSITIVE_TEXT = (
    "URGENT Poste Tunisienne : votre colis est bloqué. Appelez le +216 22 123 456 "
    "ou écrivez à ali.bensalah@gmail.com. Virez 2 DT sur TN59 1000 6035 1835 9847 8831 "
    "puis envoyez le code 482913. Carte 4111 1111 1111 1111."
)
SECRETS = [
    "22 123 456",
    "22123456",
    "ali.bensalah",
    "gmail.com",
    "TN59",
    "1000 6035",
    "482913",
    "4111",
]


def test_texte_anonymise_avant_stockage(client: TestClient, rows: Callable) -> None:
    assert client.post("/v1/reports", json=valid_report(text=SENSITIVE_TEXT)).status_code == 201
    (stored,) = rows()
    text = stored[0]
    for secret in SECRETS:
        assert secret not in text
    # Le reste du message est gardé pour le modèle.
    assert "Poste Tunisienne" in text
    assert "[TEL]" in text and "[EMAIL]" in text and "[IBAN]" in text


def test_rien_de_sensible_dans_le_fichier(
    client: TestClient, db_path: Path
) -> None:
    client.post(
        "/v1/reports",
        json=valid_report(text=SENSITIVE_TEXT),
        headers={"user-agent": "Sentinel/1.4.0 (Pixel 8; Android 15)", "x-device-id": "abc-123"},
    )
    raw = db_path.read_bytes()
    for secret in [*SECRETS, "testclient", "Pixel 8", "abc-123", "Sentinel/1.4.0"]:
        assert secret.encode() not in raw, secret
    # Ni journal SQLite à côté (WAL) avec des restes du texte.
    for leftover in db_path.parent.glob("reports.db-*"):
        assert b"22123456" not in leftover.read_bytes()


def test_colonnes_strictement_limitees(client: TestClient, db_path: Path) -> None:
    with sqlite3.connect(db_path) as connection:
        columns = [row[1] for row in connection.execute("PRAGMA table_info(reports)")]
    assert columns == [
        "id",
        "text",
        "verdict",
        "language",
        "app_version",
        "received_on",
        "anonymizer_version",
    ]


def test_jour_seulement_pas_l_heure(client: TestClient, rows: Callable) -> None:
    client.post("/v1/reports", json=valid_report())
    (stored,) = rows()
    received_on = stored[4]
    # Une date ISO (AAAA-MM-JJ), sans heure.
    assert received_on == dt.datetime.now(dt.UTC).date().isoformat()
    assert stored[5] == ANONYMIZER_VERSION
    assert stored[1:4] == ("arnaque", "fr", "1.4.0+12")


def test_migrations_identiques_aux_modeles(tmp_path: Path) -> None:
    url = f"sqlite:///{(tmp_path / 'm.db').as_posix()}"
    upgrade(url)
    engine = create_engine(url)
    with engine.connect() as connection:
        diff = compare_metadata(MigrationContext.configure(connection), Base.metadata)
    engine.dispose()
    assert diff == []


def test_migrations_rejouables(tmp_path: Path) -> None:
    url = f"sqlite:///{(tmp_path / 'm.db').as_posix()}"
    upgrade(url)
    upgrade(url)  # déjà à jour : rien ne casse
