"""Configuration par variables d'environnement (préfixe SENTINEL_).

Aucun secret : le sel de la limite de débit est tiré au hasard en mémoire.
"""

from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="SENTINEL_", env_file=".env", extra="ignore", frozen=True
    )

    # « prod » par défaut : /docs fermé si on oublie de configurer.
    env: Literal["dev", "prod"] = "prod"
    database_url: str = "sqlite:///./data/sentinel.db"
    host: str = "127.0.0.1"
    port: int = 8000
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"

    # Limite de débit : signalements par fenêtre, par adresse.
    rate_limit_per_window: int = 10
    rate_limit_window_seconds: int = 3600
    # Plafond d'adresses suivies (mémoire bornée face à un déni de service).
    rate_limit_max_keys: int = 100_000

    # Taille maximale d'une requête (octets).
    max_body_bytes: int = 16_384

    # Adresses des proxys de confiance pour X-Forwarded-For (uvicorn).
    forwarded_allow_ips: str = "127.0.0.1"

    @property
    def is_dev(self) -> bool:
        return self.env == "dev"


@lru_cache
def get_settings() -> Settings:
    return Settings()
