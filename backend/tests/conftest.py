"""Outils communs : une API neuve sur une base SQLite temporaire migrée."""

import sqlite3
from collections.abc import Callable
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.__main__ import migrate
from app.config import Settings
from app.main import create_app

# Adresse de test (plage de documentation, RFC 5737).
CLIENT_IP = "203.0.113.77"


def valid_report(**changes: object) -> dict[str, object]:
    report: dict[str, object] = {
        "text": "Votre colis est bloqué, payez 2 DT ici : poste-tn.xyz/p",
        "verdict": "arnaque",
        "probability": 0.93,
        "language": "fr",
        "app_version": "1.4.0+12",
        "source": "sms",
    }
    report.update(changes)
    return report


@pytest.fixture
def db_path(tmp_path: Path) -> Path:
    return tmp_path / "data" / "reports.db"


@pytest.fixture
def make_client(db_path: Path) -> Callable[..., TestClient]:
    def make(ip: str = CLIENT_IP, **settings: object) -> TestClient:
        url = f"sqlite:///{db_path.as_posix()}"
        migrate(url)
        # _env_file=None : un .env local ne doit pas influencer les tests.
        config = Settings(_env_file=None, database_url=url, **settings)  # type: ignore[arg-type]
        return TestClient(create_app(config), client=(ip, 51000))

    return make


@pytest.fixture
def client(make_client: Callable[..., TestClient]) -> TestClient:
    # Limite haute : les tests de validation ne doivent pas la toucher.
    return make_client(rate_limit_per_window=1000)


@pytest.fixture
def rows(db_path: Path) -> Callable[[], list[sqlite3.Row]]:
    def read() -> list[sqlite3.Row]:
        with sqlite3.connect(db_path) as connection:
            connection.row_factory = sqlite3.Row
            return connection.execute("SELECT * FROM reports").fetchall()

    return read
