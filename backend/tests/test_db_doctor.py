"""Outil tools.db_doctor : logique testée sans vraie base (et une passe
PostgreSQL avec SENTINEL_TEST_DATABASE_URL)."""

import string
from collections.abc import Iterator
from pathlib import Path

import pytest
from sqlalchemy import text
from sqlalchemy.engine import make_url

from app.__main__ import migrate
from tools import db_doctor
from tools.db_doctor import (
    DoctorError,
    build_role_url,
    check_owner_url,
    clean_history,
    clean_history_files,
    expected_checks,
    generate_password,
    safe_error,
)

from .conftest import engine_for, postgres_only
from .test_postgres_roles import _drop_roles

OWNER_PASSWORD = "npg_OwnerSecret123"  # noqa: S105 (faux secret de test)
HOST = "ep-cool-darkness-123456.eu-central-1.aws.neon.tech"
OWNER_URL = (
    f"postgresql://neondb_owner:{OWNER_PASSWORD}@{HOST}/neondb"
    "?sslmode=require&channel_binding=require"
)


# --- Mot de passe ----------------------------------------------------------


def test_mot_de_passe_fort() -> None:
    passwords = {generate_password() for _ in range(50)}
    assert len(passwords) == 50  # jamais deux fois le même
    for password in passwords:
        assert len(password) == 32
        assert set(password) <= set(string.ascii_letters + string.digits)
        assert any(c.islower() for c in password)
        assert any(c.isupper() for c in password)
        assert any(c.isdigit() for c in password)


# --- URL -------------------------------------------------------------------


def test_url_du_role_garde_hote_base_et_tls() -> None:
    password = generate_password()
    url = build_role_url(OWNER_URL, "sentinel_app", password)
    parsed, owner = make_url(url), make_url(OWNER_URL)
    assert parsed.drivername == "postgresql"  # pas de +psycopg : collable dans Render
    assert parsed.username == "sentinel_app"
    assert parsed.password == password
    assert (parsed.host, parsed.port, parsed.database) == (owner.host, owner.port, owner.database)
    assert parsed.query == owner.query  # sslmode et channel_binding
    assert OWNER_PASSWORD not in url and "neondb_owner" not in url


def test_url_du_role_revue_et_port() -> None:
    owner = OWNER_URL.replace(HOST, HOST + ":5433")
    parsed = make_url(build_role_url(owner, "sentinel_revue", "abc123XYZ"))
    assert (parsed.username, parsed.password) == ("sentinel_revue", "abc123XYZ")
    assert (parsed.host, parsed.port) == (HOST, 5433)


@pytest.mark.parametrize(("role", "password"), [("postgres", "abc123"), ("sentinel_app", "a'b")])
def test_url_du_role_refusee(role: str, password: str) -> None:
    with pytest.raises(DoctorError):
        build_role_url(OWNER_URL, role, password)


def test_url_proprietaire_acceptee() -> None:
    check_owner_url(OWNER_URL)
    check_owner_url("  " + OWNER_URL.replace("require&", "verify-full&") + "\n")


@pytest.mark.parametrize(
    "url",
    [
        OWNER_URL.replace("?sslmode=require&", "?"),  # sans TLS
        OWNER_URL.replace("neondb_owner", "sentinel_app"),  # pas le propriétaire
        OWNER_URL.replace("postgresql", "mysql"),
        f"postgresql://neondb_owner@{HOST}/neondb?sslmode=require",  # sans mot de passe
        "n'importe quoi",
        "",
    ],
)
def test_url_proprietaire_refusee_sans_la_recopier(url: str) -> None:
    with pytest.raises(DoctorError) as error:
        check_owner_url(url)
    assert OWNER_PASSWORD not in str(error.value)
    assert HOST not in str(error.value)


def test_options_de_connexion() -> None:
    args = db_doctor.connect_kwargs(OWNER_URL)
    assert args["application_name"] == "sentinel-db-doctor"
    assert args["prepare_threshold"] is None


# --- Messages d'erreur -----------------------------------------------------


class FakeError(Exception):
    sqlstate = "28P01"


def test_erreur_nettoyee() -> None:
    password = generate_password()
    role_url = build_role_url(OWNER_URL, "sentinel_app", password)
    error = FakeError(
        f'connection to server at "{HOST}" (3.65.1.2), port 5432 failed: FATAL: '
        f'password authentication failed for user "sentinel_app" {role_url} {password}'
    )
    output = safe_error(error, (OWNER_URL, password, role_url))
    assert "sqlstate=28P01" in output and "mot de passe refusé" in output
    for secret in (password, OWNER_PASSWORD, HOST, "3.65.1.2", "postgresql://", "npg_"):
        assert secret not in output


# --- Droits attendus -------------------------------------------------------


def test_droits_attendus_comme_roles_sql() -> None:
    app = {c.label: c.expected for c in expected_checks("sentinel_app")}
    assert app["ajouter un signalement (INSERT)"] is True
    assert app["lire les textes (interdit)"] is False
    assert app["supprimer (interdit)"] is False
    revue = {c.label: c.expected for c in expected_checks("sentinel_revue")}
    assert revue["supprimer (DELETE)"] is True
    assert revue["ajouter un signalement (interdit)"] is False


@pytest.mark.parametrize("role", db_doctor.ROLES)
def test_requetes_de_droits_parametrees(role: str) -> None:
    for check in expected_checks(role):
        assert check.sql.count("%s") == len(check.args)
        assert role not in check.sql  # le rôle passe en paramètre, pas dans le SQL


# --- Historique PowerShell -------------------------------------------------

HISTORY = [
    "cd backend\r\n",
    "$env:DATABASE_URL = 'postgresql://sentinel_revue:abc@h/db?sslmode=require'\r\n",
    "git status\r\n",
    "Write-Host `\r\n",
    "  npg_secret123\r\n",
    "echo NPG_MAJUSCULES\r\n",
    "python -m tools.db_doctor\r\n",
]


def test_historique_nettoye() -> None:
    kept, removed = clean_history(HISTORY)
    # La commande sur deux lignes (accent grave) part en entier.
    assert kept == ["cd backend\r\n", "git status\r\n", "python -m tools.db_doctor\r\n"]
    assert removed == 4


def test_fichier_historique_apres_confirmation(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    folder = tmp_path / "Microsoft" / "Windows" / "PowerShell" / "PSReadLine"
    folder.mkdir(parents=True)
    history = folder / "ConsoleHost_history.txt"
    history.write_bytes("".join(HISTORY).encode())
    monkeypatch.setenv("APPDATA", str(tmp_path))

    clean_history_files(ask=lambda _q: "n")
    assert history.read_bytes() == "".join(HISTORY).encode()  # refus : rien ne change

    clean_history_files(ask=lambda _q: "o")
    assert history.read_bytes() == b"cd backend\r\ngit status\r\npython -m tools.db_doctor\r\n"
    assert not list(folder.glob("*.tmp"))
    output = capsys.readouterr().out
    assert "npg_secret" not in output and "abc@h" not in output


# --- Vraie base (PostgreSQL) -----------------------------------------------


@pytest.fixture
def owner_conn(db_url: str) -> Iterator[object]:
    import psycopg

    migrate(db_url)
    roles_sql = db_doctor.ROLES_SQL.read_text(encoding="utf-8")
    plain = db_url.replace("postgresql+psycopg://", "postgresql://")
    _drop_roles(db_url)
    with psycopg.connect(plain, autocommit=True) as conn:
        conn.execute(roles_sql)
        yield conn
    _drop_roles(db_url)


@postgres_only
def test_diagnostic_et_rotation_sur_postgres(
    owner_conn: object, db_url: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    assert db_doctor.diagnose(owner_conn) == dict.fromkeys(db_doctor.ROLES, True)
    copied: list[str] = []
    monkeypatch.setattr(db_doctor, "copy_to_clipboard", copied.append)
    monkeypatch.setattr(db_doctor, "clear_clipboard", lambda: None)
    monkeypatch.setattr("builtins.input", lambda _q="": "")
    plain = db_url.replace("postgresql+psycopg://", "postgresql://")
    for role in db_doctor.ROLES:
        db_doctor.rotate(owner_conn, plain, role)
    assert [make_url(u).username for u in copied] == list(db_doctor.ROLES)
    # Rien n'a été gardé par les tests d'insertion (transactions annulées).
    engine = engine_for(db_url)
    with engine.connect() as connection:
        assert connection.scalar(text("SELECT count(*) FROM reports")) == 0
    engine.dispose()
