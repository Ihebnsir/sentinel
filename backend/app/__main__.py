"""Lancement : `python -m app` (migrations, puis serveur).

Options d'uvicorn choisies pour la vie privée :
- access_log=False : son journal d'accès écrit l'IP de chaque client ;
- server_header=False : pas d'en-tête « server: uvicorn » ;
- log_config : nos journaux, avec le filtre qui efface les IP ;
- proxy_headers=False : uvicorn ne réécrit pas l'IP du client à partir de
  X-Forwarded-For ; l'app lit elle-même l'en-tête du proxy de confiance,
  seulement si SENTINEL_TRUST_PROXY est activé (app.client_ip).

Migrations au démarrage avec SENTINEL_MIGRATION_DATABASE_URL (rôle
propriétaire), puis le serveur avec SENTINEL_DATABASE_URL (rôle « app »).
"""

from pathlib import Path

import uvicorn
from alembic import command
from alembic.config import Config

from .config import get_settings, normalize_db_url
from .logging_config import log_config

BACKEND_DIR = Path(__file__).resolve().parent.parent


def migrate(database_url: str) -> None:
    """Met la base au dernier schéma (alembic upgrade head)."""
    database_url = normalize_db_url(database_url)
    if database_url.startswith("sqlite:///"):
        # Dossier du fichier SQLite (ex : ./data).
        Path(database_url.removeprefix("sqlite:///")).parent.mkdir(parents=True, exist_ok=True)
    config = Config(str(BACKEND_DIR / "alembic.ini"))
    # Par attributes : voir migrations/env.py.
    config.attributes["url"] = database_url
    command.upgrade(config, "head")


def main() -> None:
    settings = get_settings()
    migrate(settings.migration_url)
    uvicorn.run(
        "app.main:create_app",
        factory=True,
        host=settings.host,
        port=settings.port,
        access_log=False,
        server_header=False,
        log_config=log_config(settings.log_level),
        proxy_headers=False,
    )


if __name__ == "__main__":
    main()
