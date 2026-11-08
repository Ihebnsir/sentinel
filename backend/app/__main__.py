"""Lancement : `python -m app` (migrations, puis serveur).

Options d'uvicorn choisies pour la vie privée :
- access_log=False : son journal d'accès écrit l'IP de chaque client ;
- server_header=False : pas d'en-tête « server: uvicorn » ;
- log_config : nos journaux, avec le filtre qui efface les IP.
"""

from pathlib import Path

import uvicorn
from alembic import command
from alembic.config import Config

from .config import get_settings
from .logging_config import log_config

BACKEND_DIR = Path(__file__).resolve().parent.parent


def migrate(database_url: str) -> None:
    """Met la base au dernier schéma (alembic upgrade head)."""
    if database_url.startswith("sqlite:///"):
        # Dossier du fichier SQLite (ex : ./data).
        Path(database_url.removeprefix("sqlite:///")).parent.mkdir(parents=True, exist_ok=True)
    config = Config(str(BACKEND_DIR / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", database_url)
    command.upgrade(config, "head")


def main() -> None:
    settings = get_settings()
    migrate(settings.database_url)
    uvicorn.run(
        "app.main:create_app",
        factory=True,
        host=settings.host,
        port=settings.port,
        access_log=False,
        server_header=False,
        log_config=log_config(settings.log_level),
        proxy_headers=True,
        forwarded_allow_ips=settings.forwarded_allow_ips,
    )


if __name__ == "__main__":
    main()
