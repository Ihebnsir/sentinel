"""Outils communs : une API neuve sur une base SQLite temporaire."""

import sqlite3
from collections.abc import Callable
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.db import upgrade
from app.main import create_app


def valid_report(**changes: object) -> dict[str, object]:
    report: dict[str, object] = {
        "text": "Votre colis est bloqué, payez 2 DT ici : poste-tn.xyz/p",
        "verdict": "arnaque",
        "language": "fr",
        "app_version": "1.4.0+12",
    }
    report.update(changes)
    return report


@pytest.fixture
def db_path(tmp_path: Path) -> Path:
    return tmp_path / "data" / "reports.db"


@pytest.fixture
def make_client(db_path: Path) -> Callable[..., TestClient]:
    def make(**settings: object) -> TestClient:
        url = f"sqlite:///{db_path.as_posix()}"
        upgrade(url)
        app = create_app(Settings(database_url=url, **settings))  # type: ignore[arg-type]
        return TestClient(app)

    return make


@pytest.fixture
def client(make_client: Callable[..., TestClient]) -> TestClient:
    # Limite haute : les tests de validation ne doivent pas la toucher.
    return make_client(rate_limit=1000)


@pytest.fixture
def rows(db_path: Path) -> Callable[[], list[tuple[object, ...]]]:
    def read() -> list[tuple[object, ...]]:
        with sqlite3.connect(db_path) as connection:
            return connection.execute(
                "SELECT text, verdict, language, app_version, received_on,"
                " anonymizer_version FROM reports"
            ).fetchall()

    return read
