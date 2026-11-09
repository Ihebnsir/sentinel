"""Doublons (empreinte + compteur) et date d'export pour la rétention.

Révision : 0003
"""

import sqlalchemy as sa
from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("reports") as batch:
        # NULL pour les anciennes lignes : la clé n'est pas connue ici.
        batch.add_column(sa.Column("fingerprint", sa.String(64), nullable=True))
        batch.add_column(sa.Column("count", sa.Integer(), nullable=False, server_default="1"))
        batch.add_column(sa.Column("exported_on", sa.Date(), nullable=True))
        # Plusieurs NULL restent permis (PostgreSQL et SQLite).
        batch.create_unique_constraint("uq_reports_fingerprint", ["fingerprint"])


def downgrade() -> None:
    with op.batch_alter_table("reports") as batch:
        batch.drop_constraint("uq_reports_fingerprint", type_="unique")
        batch.drop_column("exported_on")
        batch.drop_column("count")
        batch.drop_column("fingerprint")
