"""Connexion des outils : URL dans --database-url ou DATABASE_URL.

PostgreSQL : TLS obligatoire (sslmode=require ou verify-full), même en local.
"""

import os
import sys

from sqlalchemy.orm import Session, sessionmaker

from app.config import db_problem
from app.db import make_sessionmaker


class ToolError(Exception):
    """Erreur affichée telle quelle (jamais l'URL : elle porte le mot de passe)."""


def database_url(cli_value: str | None) -> str:
    url = cli_value or os.environ.get("DATABASE_URL") or os.environ.get("SENTINEL_DATABASE_URL")
    if not url:
        raise ToolError("DATABASE_URL manquante (variable d'environnement ou --database-url)")
    problem = db_problem(url, allow_sqlite=True)
    if problem:
        raise ToolError(problem)
    return url


def sessions(cli_value: str | None) -> sessionmaker[Session]:
    return make_sessionmaker(database_url(cli_value))


def fail(error: Exception) -> None:
    print(f"Erreur : {error}", file=sys.stderr)
    raise SystemExit(2)
