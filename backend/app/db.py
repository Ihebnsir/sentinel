"""Connexion à la base : PostgreSQL (production) ou SQLite (dev, tests)."""

import contextlib
import os
from collections.abc import Iterator
from pathlib import Path

from fastapi import Request
from sqlalchemy import Engine, create_engine, event
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session, sessionmaker

from .config import normalize_db_url

# Fichiers de certificats racine du système (Debian/Ubuntu, Fedora, Alpine).
SYSTEM_CA_FILES = (
    "/etc/ssl/certs/ca-certificates.crt",
    "/etc/pki/tls/certs/ca-bundle.crt",
    "/etc/ssl/cert.pem",
)


def root_cert_file() -> str:
    """Certificats racine pour sslmode=verify-ca / verify-full.

    Sans sslrootcert, libpq cherche ~/.postgresql/root.crt : ce fichier
    n'existe pas dans l'image Docker (utilisateur sans dossier personnel),
    et la connexion échoue (OperationalError). On donne donc le fichier du
    système ; « system » (libpq 16+) en dernier recours.
    """
    candidates = [os.environ.get("SSL_CERT_FILE"), *SYSTEM_CA_FILES]
    # Windows : pas de fichier système, certifi s'il est installé (outils).
    with contextlib.suppress(ImportError):
        import certifi

        candidates.append(certifi.where())
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return candidate
    return "system"


def postgres_connect_args(url: str) -> dict[str, object]:
    """Options de connexion psycopg, communes au serveur et aux migrations."""
    args: dict[str, object] = {
        "connect_timeout": 10,
        "application_name": "sentinel",
        # Pas de requêtes préparées côté serveur : compatibles avec le
        # pooler de Neon (PgBouncer en mode transaction).
        "prepare_threshold": None,
    }
    query = make_url(normalize_db_url(url)).query
    if query.get("sslmode") in {"verify-ca", "verify-full"} and not query.get("sslrootcert"):
        args["sslrootcert"] = root_cert_file()
    return args


def make_engine(url: str) -> Engine:
    url = normalize_db_url(url)
    if url.startswith("sqlite"):
        # echo=False : les requêtes SQL (et leurs paramètres) ne vont pas aux logs.
        engine = create_engine(url, echo=False, connect_args={"check_same_thread": False})

        @event.listens_for(engine, "connect")
        def _sqlite_pragmas(conn, _record) -> None:
            cursor = conn.cursor()
            # Effacement réel des données supprimées, et contraintes actives.
            cursor.execute("PRAGMA secure_delete=ON")
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()

        return engine
    # PostgreSQL managé : la base s'endort (Neon) et coupe les connexions
    # inactives. pre_ping vérifie la connexion avant usage ; recycle la renouvelle.
    return create_engine(
        url,
        echo=False,
        pool_pre_ping=True,
        pool_recycle=300,
        pool_size=3,
        max_overflow=2,
        connect_args=postgres_connect_args(url),
    )


def make_sessionmaker(url: str) -> sessionmaker[Session]:
    return sessionmaker(bind=make_engine(url), expire_on_commit=False)


def get_session(request: Request) -> Iterator[Session]:
    """Une session par requête (fabrique gardée dans l'état de l'app)."""
    with request.app.state.sessionmaker() as session:
        yield session
