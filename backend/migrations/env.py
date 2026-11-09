"""Environnement Alembic : PostgreSQL ou SQLite.

URL, par ordre : config.attributes["url"] (app.__main__.migrate), sinon
sqlalchemy.url, sinon SENTINEL_MIGRATION_DATABASE_URL / SENTINEL_DATABASE_URL.
Passée par attributes : pas d'interpolation « % » de configparser, et le mot
de passe ne passe pas par le fichier .ini.
"""

from alembic import context
from sqlalchemy import create_engine, pool

from app.config import get_settings, normalize_db_url
from app.models import Base

config = context.config
url = normalize_db_url(
    config.attributes.get("url")
    or config.get_main_option("sqlalchemy.url")
    or get_settings().migration_url
)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        render_as_batch=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = create_engine(url, poolclass=pool.NullPool)
    with connectable.connect() as connection:
        # render_as_batch : SQLite ne sait pas modifier une colonne en place.
        context.configure(
            connection=connection, target_metadata=target_metadata, render_as_batch=True
        )
        with context.begin_transaction():
            context.run_migrations()
    connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
