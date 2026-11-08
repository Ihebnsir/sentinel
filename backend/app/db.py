"""Connexion à la base (SQLite en local)."""

from collections.abc import Iterator

from fastapi import Request
from sqlalchemy import Engine, create_engine, event
from sqlalchemy.orm import Session, sessionmaker


def make_engine(url: str) -> Engine:
    is_sqlite = url.startswith("sqlite")
    connect_args = {"check_same_thread": False} if is_sqlite else {}
    # echo=False : les requêtes SQL (et leurs paramètres) ne vont pas aux logs.
    engine = create_engine(url, echo=False, connect_args=connect_args)
    if is_sqlite:

        @event.listens_for(engine, "connect")
        def _sqlite_pragmas(conn, _record) -> None:
            cursor = conn.cursor()
            # Effacement réel des données supprimées, et contraintes actives.
            cursor.execute("PRAGMA secure_delete=ON")
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()

    return engine


def make_sessionmaker(url: str) -> sessionmaker[Session]:
    return sessionmaker(bind=make_engine(url), expire_on_commit=False)


def get_session(request: Request) -> Iterator[Session]:
    """Une session par requête (fabrique gardée dans l'état de l'app)."""
    with request.app.state.sessionmaker() as session:
        yield session
