"""Connexion à la base : PostgreSQL (production) ou SQLite (dev, tests)."""

from collections.abc import Iterator

from fastapi import Request
from sqlalchemy import Engine, create_engine, event
from sqlalchemy.orm import Session, sessionmaker

from .config import normalize_db_url


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
        connect_args={"connect_timeout": 10, "application_name": "sentinel"},
    )


def make_sessionmaker(url: str) -> sessionmaker[Session]:
    return sessionmaker(bind=make_engine(url), expire_on_commit=False)


def get_session(request: Request) -> Iterator[Session]:
    """Une session par requête (fabrique gardée dans l'état de l'app)."""
    with request.app.state.sessionmaker() as session:
        yield session
