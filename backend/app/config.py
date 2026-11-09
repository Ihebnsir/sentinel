"""Configuration par variables d'environnement (préfixe SENTINEL_).

En production (SENTINEL_ENV=prod, le défaut), le démarrage est REFUSÉ si :
- la base PostgreSQL n'exige pas TLS (sslmode=require, verify-ca ou verify-full) ;
- la base est SQLite sans SENTINEL_ALLOW_SQLITE=true (disque éphémère chez
  l'hébergeur : les données seraient perdues) ;
- la clé d'empreinte (SENTINEL_FINGERPRINT_KEY) manque ou est trop courte.
"""

from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import make_url

# Valeurs de sslmode qui imposent le chiffrement (libpq / psycopg).
TLS_MODES = frozenset({"require", "verify-ca", "verify-full"})
# Clé de développement : jamais acceptée en production.
DEV_FINGERPRINT_KEY = "dev-uniquement-pas-un-secret-0123456789"
MIN_KEY_LENGTH = 32


def normalize_db_url(url: str) -> str:
    """postgres:// et postgresql:// (Neon, Render) → driver psycopg 3."""
    for prefix in ("postgres://", "postgresql://"):
        if url.startswith(prefix):
            return "postgresql+psycopg://" + url.removeprefix(prefix)
    return url


def db_problem(url: str, *, allow_sqlite: bool) -> str | None:
    """Pourquoi cette URL est refusée en production (None : acceptée).
    Le message ne contient jamais l'URL (elle porte le mot de passe)."""
    parsed = make_url(normalize_db_url(url))
    backend = parsed.get_backend_name()
    if backend == "sqlite":
        return None if allow_sqlite else "SQLite refusé en production (SENTINEL_ALLOW_SQLITE)"
    if backend != "postgresql":
        return "seuls PostgreSQL et SQLite sont pris en charge"
    sslmode = parsed.query.get("sslmode")
    if sslmode not in TLS_MODES:
        return "connexion PostgreSQL sans TLS : ajouter ?sslmode=require (ou verify-full)"
    return None


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="SENTINEL_",
        env_file=".env",
        extra="ignore",
        frozen=True,
        # Une erreur de configuration n'affiche jamais la valeur (mots de passe).
        hide_input_in_errors=True,
    )

    # « prod » par défaut : /docs fermé et contrôles stricts si on oublie.
    env: Literal["dev", "prod"] = "prod"
    # repr=False : l'URL (avec mot de passe) n'apparaît pas si on affiche Settings.
    database_url: str = Field("sqlite:///./data/sentinel.db", repr=False)
    # Migrations avec un rôle propriétaire ; vide = même URL que database_url.
    migration_database_url: str | None = Field(None, repr=False)
    allow_sqlite: bool = False
    host: str = "127.0.0.1"
    port: int = 8000
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"

    # Limite de débit : signalements par fenêtre, par adresse.
    rate_limit_per_window: int = 10
    rate_limit_window_seconds: int = 3600
    # Plafond d'adresses suivies (mémoire bornée face à un déni de service).
    rate_limit_max_keys: int = 100_000
    # Limite globale : nouveaux signalements par jour (UTC), tous clients.
    global_daily_limit: int = Field(500, ge=1)
    # Taille maximale d'une requête (octets).
    max_body_bytes: int = 16_384

    # Derrière le proxy de l'hébergeur : IP du client lue dans cet en-tête,
    # SEULEMENT si trust_proxy est vrai (sinon : IP de connexion).
    trust_proxy: bool = False
    client_ip_header: str = "x-forwarded-for"
    # Nombre de proxys de confiance qui ajoutent une entrée (on lit la
    # n-ième en partant de la droite : celles de gauche viennent du client).
    proxy_hops: int = Field(1, ge=1, le=5)

    # Clé HMAC de l'empreinte des textes (doublons). Secret en production.
    fingerprint_key: SecretStr | None = None

    @property
    def is_dev(self) -> bool:
        return self.env == "dev"

    @property
    def migration_url(self) -> str:
        return self.migration_database_url or self.database_url

    @property
    def fingerprint_secret(self) -> bytes:
        key = self.fingerprint_key
        return (key.get_secret_value() if key else DEV_FINGERPRINT_KEY).encode()

    @model_validator(mode="after")
    def _production_checks(self) -> Settings:
        if self.is_dev:
            return self
        for url in {self.database_url, self.migration_url}:
            problem = db_problem(url, allow_sqlite=self.allow_sqlite)
            if problem:
                raise ValueError(problem)
        key = self.fingerprint_key
        if key is None or len(key.get_secret_value()) < MIN_KEY_LENGTH:
            raise ValueError(
                "SENTINEL_FINGERPRINT_KEY manquante ou trop courte "
                f"({MIN_KEY_LENGTH} caractères min.)"
            )
        if key.get_secret_value() == DEV_FINGERPRINT_KEY:
            raise ValueError("clé d'empreinte de développement refusée en production")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
