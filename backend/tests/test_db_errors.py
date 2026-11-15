"""Erreurs de base : journaux utiles au diagnostic, mais sans aucun secret.

Et options de connexion (TLS verify-full sans certificats dans l'image).
"""

import logging
from collections.abc import Callable
from pathlib import Path

import psycopg
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError, ProgrammingError
from sqlalchemy.orm import Session

from app.db import postgres_connect_args, root_cert_file
from app.db_errors import clean_message, describe, sqlstate

from .conftest import valid_report

SECRET_PASSWORD = "npg_Zx9SuperSecret42"  # noqa: S105 (faux secret de test)
HOST = "ep-cool-darkness-123456.eu-central-1.aws.neon.tech"
URL = f"postgresql://sentinel_app:{SECRET_PASSWORD}@{HOST}/neondb?sslmode=require"
REPORT_TEXT = "Votre colis est bloqué, payez ici : poste-tn.xyz/p"
# Tout ce qui ne doit JAMAIS sortir dans un journal.
FORBIDDEN = [
    SECRET_PASSWORD,
    "Zx9SuperSecret42",
    "npg_",
    HOST,
    "neon.tech",
    "postgresql://",
    "18.153.2.77",
    "hunter2pass",
    "poste-tn",
    "colis",
    "INSERT",
]


class FakeDriverError(Exception):
    """Erreur de pilote (comme psycopg) avec un code SQLSTATE."""

    def __init__(self, message: str, code: str | None) -> None:
        super().__init__(message)
        self.sqlstate = code


DRIVER_MESSAGE = (
    f'connection failed: connection to server at "{HOST}" (18.153.2.77), port 5432 '
    f'failed: FATAL:  password authentication failed for user "sentinel_app" ({URL}) '
    "password=hunter2pass"
)


def _wrapped(message: str = DRIVER_MESSAGE, code: str | None = "28P01") -> OperationalError:
    # Comme SQLAlchemy : la requête et ses paramètres (le texte) dans l'erreur.
    return OperationalError(
        "INSERT INTO reports (text) VALUES (%(text)s)",
        {"text": REPORT_TEXT},
        FakeDriverError(message, code),
    )


def _assert_clean(output: str) -> None:
    for secret in FORBIDDEN:
        assert secret not in output, secret


def test_description_utile_et_sans_secret() -> None:
    output = describe(_wrapped(), forbidden=(REPORT_TEXT, URL))
    assert output.startswith("type=OperationalError sqlstate=28P01 piste=mot de passe refusé")
    assert 'password authentication failed for user "sentinel_app"' in output
    _assert_clean(output)


def test_texte_du_signalement_masque_meme_entre_guillemets() -> None:
    message = f'invalid input syntax: "{REPORT_TEXT}"'
    output = describe(_wrapped(message, "22P02"), forbidden=())
    _assert_clean(output)
    # Un mot isolé : masqué s'il est donné dans forbidden.
    assert "bonjour" not in clean_message('valeur "bonjour"', forbidden=["bonjour"])


def test_erreur_sqlalchemy_sans_pilote_ne_donne_pas_son_texte() -> None:
    exc = ProgrammingError("INSERT INTO reports VALUES ('poste-tn')", {}, None)
    exc.orig = None
    output = describe(exc)
    assert output == "type=ProgrammingError sqlstate=aucun piste=inconnue message=-"


@pytest.mark.parametrize(
    ("message", "expected"),
    [
        ('root certificate file "/nonexistent/.postgresql/root.crt" does not exist', "certificats"),
        ("connection timeout expired", "délai"),
        ('could not translate host name "ep-x.neon.tech"', "hôte introuvable"),
        ("SSL error: certificate verify failed", "certificat du serveur"),
    ],
)
def test_piste_sans_sqlstate(message: str, expected: str) -> None:
    output = describe(_wrapped(message, None))
    assert "sqlstate=aucun" in output
    assert expected in output
    _assert_clean(output)


def test_message_court_sur_une_ligne() -> None:
    output = clean_message("ligne 1\nligne 2 " + "x" * 500)
    assert "\n" not in output
    assert len(output) <= 160


def test_sqlstate_sqlite() -> None:
    import sqlite3

    error = sqlite3.OperationalError("no such table: reports")
    error.sqlite_errorname = "SQLITE_ERROR"
    assert sqlstate(OperationalError("x", {}, error)) == "SQLITE_ERROR"


def test_journal_de_l_api_sans_secret(
    make_client: Callable[..., TestClient],
    caplog: pytest.LogCaptureFixture,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    client = make_client()

    def fail(*_args: object, **_kwargs: object) -> None:
        raise _wrapped()

    monkeypatch.setattr(Session, "scalar", fail)
    with caplog.at_level(logging.DEBUG):
        response = client.post("/v1/reports", json=valid_report(text=REPORT_TEXT))
    assert response.status_code == 500
    assert response.json() == {"detail": "erreur interne"}
    everything = "\n".join(r.getMessage() for r in caplog.records)
    assert "enregistrement impossible: type=OperationalError sqlstate=28P01" in everything
    assert "piste=mot de passe refusé" in everything
    _assert_clean(everything)


# --- Options de connexion --------------------------------------------------


def test_options_require_sans_certificat() -> None:
    args = postgres_connect_args(URL)
    assert "sslrootcert" not in args
    # Compatible avec le pooler de Neon (PgBouncer, mode transaction).
    assert args["prepare_threshold"] is None
    assert args["connect_timeout"] == 10


def test_verify_full_donne_des_certificats_racine() -> None:
    args = postgres_connect_args(URL.replace("require", "verify-full"))
    root = args["sslrootcert"]
    assert root == "system" or Path(str(root)).is_file()


def test_sslrootcert_de_l_url_respecte() -> None:
    args = postgres_connect_args(URL.replace("require", "verify-full&sslrootcert=/x/ca.pem"))
    assert "sslrootcert" not in args


def test_ssl_cert_file_prioritaire(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    bundle = tmp_path / "ca.pem"
    bundle.write_text("certificats", encoding="utf-8")
    monkeypatch.setenv("SSL_CERT_FILE", str(bundle))
    assert root_cert_file() == str(bundle)


def test_options_acceptees_par_libpq() -> None:
    # Port fermé : la connexion échoue, mais pas pour une option inconnue.
    url = "postgresql://u:p@127.0.0.1:1/db?sslmode=verify-full"
    args = {**postgres_connect_args(url), "connect_timeout": 2}
    with pytest.raises(psycopg.OperationalError) as error:
        psycopg.connect(url, **args)
    assert "invalid connection option" not in str(error.value)
