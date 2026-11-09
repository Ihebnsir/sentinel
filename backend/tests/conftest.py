"""Outils communs : une API neuve sur une base temporaire migrée.

Par défaut : SQLite (fichier temporaire). Pour une passe en PostgreSQL :
    $env:SENTINEL_TEST_DATABASE_URL = "postgresql://sentinel:sentinel-local@127.0.0.1:5432/sentinel?sslmode=require"
    python -m pytest
(base du docker compose local ; le schéma public est vidé avant chaque test).
"""

import datetime as dt
import os
import uuid
from collections.abc import Callable, Iterator
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Engine, create_engine, text

from app.__main__ import migrate
from app.config import Settings, normalize_db_url
from app.main import create_app

# Adresse de test (plage de documentation, RFC 5737).
CLIENT_IP = "203.0.113.77"
# Clé d'empreinte des tests (pas un secret).
FINGERPRINT_KEY = "cle-de-test-pas-un-secret-0123456789abcdef"
PG_URL = os.environ.get("SENTINEL_TEST_DATABASE_URL")
ON_POSTGRES = bool(PG_URL)

sqlite_only = pytest.mark.skipif(ON_POSTGRES, reason="propre au fichier SQLite")
postgres_only = pytest.mark.skipif(
    not ON_POSTGRES, reason="SENTINEL_TEST_DATABASE_URL absent (PostgreSQL)"
)


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


def engine_for(url: str) -> Engine:
    return create_engine(normalize_db_url(url))


def reset_postgres(url: str) -> None:
    """Schéma public vide (tables, contraintes, version Alembic)."""
    engine = engine_for(url)
    with engine.begin() as connection:
        connection.execute(text("DROP SCHEMA public CASCADE"))
        connection.execute(text("CREATE SCHEMA public"))
    engine.dispose()


@pytest.fixture
def db_path(tmp_path: Path) -> Path:
    return tmp_path / "data" / "reports.db"


@pytest.fixture
def db_url(db_path: Path) -> str:
    if PG_URL:
        reset_postgres(PG_URL)
        return PG_URL
    return f"sqlite:///{db_path.as_posix()}"


def make_settings(db_url: str, **settings: Any) -> Settings:
    # _env_file=None : un .env local ne doit pas influencer les tests.
    base: dict[str, Any] = {
        "database_url": db_url,
        "allow_sqlite": True,
        "fingerprint_key": FINGERPRINT_KEY,
    }
    base.update(settings)
    return Settings(_env_file=None, **base)


@pytest.fixture
def make_client(db_url: str) -> Iterator[Callable[..., TestClient]]:
    apps = []

    def make(ip: str = CLIENT_IP, **settings: Any) -> TestClient:
        migrate(db_url)
        app = create_app(make_settings(db_url, **settings))
        apps.append(app)
        return TestClient(app, client=(ip, 51000))

    yield make
    # Connexions rendues : sinon PostgreSQL atteint sa limite de connexions.
    for app in apps:
        app.state.sessionmaker.kw["bind"].dispose()


@pytest.fixture
def client(make_client: Callable[..., TestClient]) -> TestClient:
    # Limite haute : les tests de validation ne doivent pas la toucher.
    return make_client(rate_limit_per_window=1000)


def _plain(value: object) -> object:
    # Mêmes valeurs en SQLite et en PostgreSQL.
    if isinstance(value, dt.date):
        return value.isoformat()
    if isinstance(value, uuid.UUID):
        return value.hex
    return value


@pytest.fixture
def rows(db_url: str) -> Iterator[Callable[[], list[dict[str, object]]]]:
    engine = engine_for(db_url)

    def read() -> list[dict[str, object]]:
        with engine.connect() as connection:
            result = connection.execute(text("SELECT * FROM reports ORDER BY received_on"))
            return [{k: _plain(v) for k, v in row.items()} for row in result.mappings()]

    yield read
    engine.dispose()


@pytest.fixture
def sql(db_url: str) -> Iterator[Callable[..., Any]]:
    """Exécute du SQL brut (propriétaire) : sql("UPDATE …", {"x": 1})."""
    engine = engine_for(db_url)

    def run(statement: str, params: dict[str, object] | None = None) -> Any:
        with engine.begin() as connection:
            result = connection.execute(text(statement), params or {})
            return result.all() if result.returns_rows else None

    yield run
    engine.dispose()
