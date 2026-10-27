"""Lancement en production : migrations, puis serveur sans journal d'accès.

python -m app.serve
"""

import os

import uvicorn

from .config import Settings
from .db import upgrade
from .main import create_app


def main() -> None:
    settings = Settings.from_env()
    upgrade(settings.database_url)
    # Derrière un reverse proxy : son adresse, pour lire la vraie adresse
    # du client (limite de débit seulement, jamais écrite).
    trusted_proxy = os.environ.get("SENTINEL_TRUSTED_PROXY")
    uvicorn.run(
        create_app(settings),
        # 0.0.0.0 : dans le conteneur, pour que Docker puisse relayer le port.
        host=os.environ.get("SENTINEL_HOST", "127.0.0.1"),
        port=int(os.environ.get("SENTINEL_PORT", "8000")),
        # Aucun journal d'accès : il contiendrait l'adresse IP de chaque envoi.
        access_log=False,
        server_header=False,
        date_header=False,
        # X-Forwarded-For ignoré tant qu'aucun proxy n'est déclaré.
        proxy_headers=trusted_proxy is not None,
        forwarded_allow_ips=trusted_proxy or "",
    )


if __name__ == "__main__":
    main()
