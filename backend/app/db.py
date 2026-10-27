"""Connexion SQLite et migrations (Alembic)."""

from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import Engine, create_engine
from sqlalchemy.engine import make_url

BACKEND_DIR = Path(__file__).resolve().parent.parent


def make_engine(database_url: str) -> Engine:
    url = make_url(database_url)
    if url.get_backend_name() == "sqlite" and url.database not in (None, "", ":memory:"):
        # Dossier de la base lisible par le seul utilisateur du serveur.
        Path(url.database).parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    return create_engine(database_url)


def upgrade(database_url: str) -> None:
    """Applique toutes les migrations (alembic upgrade head)."""
    config = Config(str(BACKEND_DIR / "alembic.ini"))
    config.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    config.set_main_option("sqlalchemy.url", database_url)
    make_engine(database_url).dispose()  # crée le dossier si besoin
    command.upgrade(config, "head")
