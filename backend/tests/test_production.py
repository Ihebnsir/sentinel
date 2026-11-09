"""Démarrage en production : TLS obligatoire, clé d'empreinte, pas de SQLite
par accident, et aucun mot de passe dans les messages d'erreur."""

import pytest
from pydantic import ValidationError

from app.config import DEV_FINGERPRINT_KEY, Settings, normalize_db_url

from .conftest import FINGERPRINT_KEY

SECRET = "MotDePasseTresSecret42"  # noqa: S105 - faux mot de passe de test
PG = f"postgresql://app:{SECRET}@ep-test.eu-central-1.aws.neon.tech/neondb"


def prod(**values: object) -> Settings:
    base: dict[str, object] = {"env": "prod", "fingerprint_key": FINGERPRINT_KEY}
    base.update(values)
    return Settings(_env_file=None, **base)  # type: ignore[arg-type]


def refused(**values: object) -> str:
    with pytest.raises(ValidationError) as error:
        prod(**values)
    message = str(error.value)
    # La configuration refusée n'est jamais recopiée (mot de passe).
    assert SECRET not in message
    return message


@pytest.mark.parametrize("query", ["", "?sslmode=disable", "?sslmode=prefer", "?sslmode=allow"])
def test_postgres_sans_tls_refuse(query: str) -> None:
    assert "TLS" in refused(database_url=PG + query)


@pytest.mark.parametrize("mode", ["require", "verify-ca", "verify-full"])
def test_postgres_avec_tls_accepte(mode: str) -> None:
    assert prod(database_url=f"{PG}?sslmode={mode}&channel_binding=require").env == "prod"


def test_url_des_migrations_aussi_verifiee() -> None:
    message = refused(database_url=PG + "?sslmode=require", migration_database_url=PG)
    assert "TLS" in message


def test_sqlite_refuse_en_production_sauf_choix_explicite() -> None:
    assert "SQLite" in refused(database_url="sqlite:///./data/x.db")
    assert prod(database_url="sqlite:///./data/x.db", allow_sqlite=True).allow_sqlite


def test_autre_base_refusee() -> None:
    assert "PostgreSQL" in refused(database_url="mysql://u:p@h/db", allow_sqlite=True)


@pytest.mark.parametrize("key", [None, "trop-courte", DEV_FINGERPRINT_KEY])
def test_cle_empreinte_obligatoire(key: str | None) -> None:
    message = refused(database_url=PG + "?sslmode=require", fingerprint_key=key)
    assert "empreinte" in message or "FINGERPRINT" in message


def test_dev_sans_contrainte() -> None:
    settings = Settings(_env_file=None, env="dev", database_url=PG)  # type: ignore[call-arg]
    assert settings.fingerprint_secret == DEV_FINGERPRINT_KEY.encode()


def test_url_absente_de_la_representation() -> None:
    settings = prod(database_url=PG + "?sslmode=require")
    assert SECRET not in repr(settings)
    assert FINGERPRINT_KEY not in repr(settings)


@pytest.mark.parametrize(
    ("url", "expected"),
    [
        ("postgres://u:p@h/db", "postgresql+psycopg://u:p@h/db"),
        ("postgresql://u:p@h/db?sslmode=require", "postgresql+psycopg://u:p@h/db?sslmode=require"),
        ("postgresql+psycopg://u:p@h/db", "postgresql+psycopg://u:p@h/db"),
        ("sqlite:///./x.db", "sqlite:///./x.db"),
    ],
)
def test_driver_psycopg(url: str, expected: str) -> None:
    assert normalize_db_url(url) == expected
