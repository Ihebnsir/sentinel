"""Réglages du serveur, lus dans les variables d'environnement."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    # « production » par défaut : pas de documentation interactive.
    environment: str = "production"
    database_url: str = "sqlite:///./data/reports.db"
    # Corps de requête : 8 Kio suffisent pour 2000 caractères en JSON.
    max_body_bytes: int = 8 * 1024
    # Limite de débit : N signalements par fenêtre, par adresse.
    rate_limit: int = 5
    rate_window_seconds: int = 60
    # Nombre max d'adresses suivies en mémoire (protège la mémoire).
    rate_max_clients: int = 10_000

    @property
    def is_development(self) -> bool:
        return self.environment == "development"

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            environment=os.environ.get("SENTINEL_ENV", "production"),
            database_url=os.environ.get(
                "SENTINEL_DATABASE_URL", cls.database_url
            ),
            rate_limit=int(os.environ.get("SENTINEL_RATE_LIMIT", cls.rate_limit)),
            rate_window_seconds=int(
                os.environ.get("SENTINEL_RATE_WINDOW", cls.rate_window_seconds)
            ),
        )
