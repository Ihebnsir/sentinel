"""Champ facultatif user_feedback (B2) : validation, stockage, migration."""

import sqlite3
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy.exc import IntegrityError

from app.__main__ import BACKEND_DIR

from .conftest import valid_report

Rows = Callable[[], list[dict[str, Any]]]


@pytest.mark.parametrize("feedback", ["arnaque", "pas_arnaque", "ne_sait_pas"])
def test_avis_accepte_et_enregistre(client: TestClient, rows: Rows, feedback: str) -> None:
    response = client.post("/v1/reports", json=valid_report(user_feedback=feedback))
    assert response.status_code == 201
    assert [row["user_feedback"] for row in rows()] == [feedback]


def test_ancien_client_sans_avis(client: TestClient, rows: Rows) -> None:
    # Client B1 : pas de champ user_feedback → accepté, NULL en base.
    assert "user_feedback" not in valid_report()
    assert client.post("/v1/reports", json=valid_report()).status_code == 201
    assert rows()[0]["user_feedback"] is None


def test_avis_null_accepte(client: TestClient, rows: Rows) -> None:
    response = client.post("/v1/reports", json=valid_report(user_feedback=None))
    assert response.status_code == 201
    assert rows()[0]["user_feedback"] is None


@pytest.mark.parametrize("value", ["oui", "ARNAQUE", "", 1, True, ["arnaque"]])
def test_avis_invalide_refuse(client: TestClient, rows: Rows, value: object) -> None:
    response = client.post("/v1/reports", json=valid_report(user_feedback=value))
    assert response.status_code == 422
    assert rows() == []


def test_contrainte_check_en_base(client: TestClient, sql: Callable[..., Any]) -> None:
    # Même sans l'API, la base refuse une valeur hors liste.
    client.post("/v1/reports", json=valid_report())
    with pytest.raises(IntegrityError):
        sql("UPDATE reports SET user_feedback = 'peut_etre'")


def _alembic(url: str) -> Config:
    config = Config(str(BACKEND_DIR / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", url)
    return config


def test_migration_garde_les_anciens_signalements(tmp_path: Path) -> None:
    db = tmp_path / "old.db"
    config = _alembic(f"sqlite:///{db.as_posix()}")
    # Base B1 (0001) avec un signalement existant.
    command.upgrade(config, "0001")
    with sqlite3.connect(db) as connection:
        connection.execute(
            "INSERT INTO reports VALUES ('00000000000040008000000000000001', '[TEL]',"
            " 'arnaque', 0.9, 'fr', 'sms', '1.0.0', '2026-11-08', 'nouveau', 1)"
        )
    command.upgrade(config, "head")
    with sqlite3.connect(db) as connection:
        row = connection.execute(
            "SELECT text, user_feedback, count, fingerprint, exported_on FROM reports"
        ).fetchone()
    # 0002 et 0003 : avis vide, compteur à 1, pas d'empreinte ni d'export.
    assert row == ("[TEL]", None, 1, None, None)
    # Retour arrière possible : la colonne disparaît, la ligne reste.
    command.downgrade(config, "0001")
    with sqlite3.connect(db) as connection:
        columns = {r[1] for r in connection.execute("PRAGMA table_info(reports)")}
        count = connection.execute("SELECT COUNT(*) FROM reports").fetchone()[0]
    assert "user_feedback" not in columns
    assert count == 1
