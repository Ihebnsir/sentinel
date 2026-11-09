"""Rôles à moindre privilège (sql/roles.sql), sur un vrai PostgreSQL.

Lancé seulement avec SENTINEL_TEST_DATABASE_URL (voir conftest.py).
"""

import datetime as dt
import uuid
from collections.abc import Callable, Iterator
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import ProgrammingError

from app.__main__ import migrate
from app.config import normalize_db_url
from app.db import make_sessionmaker
from app.main import create_app
from tools import retention, review

from .conftest import CLIENT_IP, engine_for, make_settings, postgres_only, valid_report

pytestmark = postgres_only

ROLES_SQL = Path(__file__).resolve().parents[1] / "sql" / "roles.sql"
PASSWORDS = {"app": "mot-de-passe-app-test-123", "revue": "mot-de-passe-revue-test-123"}


def _drop_roles(owner_url: str) -> None:
    engine = engine_for(owner_url)
    with engine.begin() as connection:
        for role in ("sentinel_app", "sentinel_revue"):
            exists = connection.scalar(
                text("SELECT 1 FROM pg_roles WHERE rolname = :r"), {"r": role}
            )
            if exists:
                connection.execute(text(f"DROP OWNED BY {role}"))
                connection.execute(text(f"DROP ROLE {role}"))
    engine.dispose()


def _role_url(owner_url: str, role: str) -> str:
    url = make_url(normalize_db_url(owner_url))
    return url.set(username=f"sentinel_{role}", password=PASSWORDS[role]).render_as_string(
        hide_password=False
    )


@pytest.fixture
def roles(db_url: str) -> Iterator[dict[str, str]]:
    migrate(db_url)  # la table doit exister avant les GRANT
    _drop_roles(db_url)
    script = (
        ROLES_SQL.read_text(encoding="utf-8")
        .replace("REMPLACER_MOT_DE_PASSE_APP", PASSWORDS["app"])
        .replace("REMPLACER_MOT_DE_PASSE_REVUE", PASSWORDS["revue"])
    )
    engine = engine_for(db_url)
    with engine.begin() as connection:
        # Script complet tel quel (blocs DO $$ … $$), sans paramètres.
        connection.connection.driver_connection.execute(script)
    engine.dispose()
    yield {"app": _role_url(db_url, "app"), "revue": _role_url(db_url, "revue")}
    _drop_roles(db_url)


def _as(url: str, statement: str, params: dict[str, Any] | None = None) -> Any:
    engine = engine_for(url)
    try:
        with engine.begin() as connection:
            result = connection.execute(text(statement), params or {})
            return result.all() if result.returns_rows else None
    finally:
        engine.dispose()


def test_script_relancable(roles: dict[str, str], db_url: str) -> None:
    script = ROLES_SQL.read_text(encoding="utf-8")
    engine = engine_for(db_url)
    with engine.begin() as connection:
        connection.connection.driver_connection.execute(script)  # deuxième fois : OK
    engine.dispose()


def test_role_app_peut_signaler_et_compter(roles: dict[str, str], db_url: str) -> None:
    # Le serveur tourne avec le rôle app ; les migrations avec le propriétaire.
    settings = make_settings(roles["app"], migration_database_url=db_url)
    app = create_app(settings)
    client = TestClient(app, client=(CLIENT_IP, 51000))
    first = client.post("/v1/reports", json=valid_report(text="Doublon"))
    second = client.post("/v1/reports", json=valid_report(text="Doublon"))
    assert first.status_code == second.status_code == 201
    assert first.json() == second.json()
    assert client.post("/v1/reports", json=valid_report(text="Autre")).status_code == 201
    app.state.sessionmaker.kw["bind"].dispose()
    counts = _as(db_url, "SELECT count FROM reports ORDER BY count")
    assert [c for (c,) in counts] == [1, 2]


@pytest.mark.parametrize(
    "statement",
    [
        "SELECT text FROM reports",
        "SELECT * FROM reports",
        "UPDATE reports SET review_status = 'arnaque_confirmee'",
        "UPDATE reports SET text = 'x'",
        "DELETE FROM reports",
        "DROP TABLE reports",
        "CREATE TABLE pirate (x int)",
        "SELECT * FROM alembic_version",
    ],
)
def test_role_app_ne_peut_rien_d_autre(
    roles: dict[str, str], sql: Callable[..., Any], statement: str
) -> None:
    sql(
        "INSERT INTO reports (id, text, verdict, probability, language, source, app_version,"
        " received_on, review_status, anonymizer_version, count)"
        " VALUES (:id, 'secret [TEL]', 'arnaque', 0.9, 'fr', 'sms', '1.0', :d, 'nouveau', 1, 1)",
        {"id": uuid.uuid4(), "d": dt.date.today()},
    )
    with pytest.raises(ProgrammingError, match=r"permission denied|must be owner"):
        _as(roles["app"], statement)


def test_role_revue_revoit_exporte_et_nettoie(
    roles: dict[str, str], db_url: str, tmp_path: Path
) -> None:
    owner = make_settings(db_url)
    client = TestClient(create_app(owner), client=(CLIENT_IP, 51000))
    for name in ("Arnaque", "Normal", "Spam"):
        assert client.post("/v1/reports", json=valid_report(text=name)).status_code == 201
    client.app.state.sessionmaker.kw["bind"].dispose()

    maker = make_sessionmaker(roles["revue"])
    with maker() as session:
        keys = iter(["a", "p", "r"])
        review.review(session, lambda _p: next(keys), lambda _m: None)
    with maker() as session:
        assert review.export(session, tmp_path / "perso.csv", dt.date.today()) == 2
    with maker() as session:
        # Rien de vieux : aucune suppression, mais le droit de compter et supprimer.
        assert retention.purge(session, dt.date.today()).total == 0
        assert retention.purge(session, dt.date.today() + dt.timedelta(days=400)).total == 1
    maker.kw["bind"].dispose()


@pytest.mark.parametrize(
    "statement",
    [
        "INSERT INTO reports (id, text, verdict, probability, language, source, app_version,"
        " received_on, review_status, anonymizer_version)"
        " VALUES (gen_random_uuid(), 'x', 'rien', 0, 'fr', 'sms', '1', current_date, 'nouveau', 1)",
        "UPDATE reports SET text = 'modifié'",
        "UPDATE reports SET count = 99",
        "DROP TABLE reports",
    ],
)
def test_role_revue_limite(roles: dict[str, str], statement: str) -> None:
    with pytest.raises(ProgrammingError, match=r"permission denied|must be owner"):
        _as(roles["revue"], statement)
