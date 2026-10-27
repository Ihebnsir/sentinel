"""Table des signalements anonymisés.

Révision : 0001
"""

import sqlalchemy as sa
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Aucune colonne pour l'IP, l'appareil ou l'heure : seulement le jour.
    op.create_table(
        "reports",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("verdict", sa.String(16), nullable=False),
        sa.Column("language", sa.String(8), nullable=False),
        sa.Column("app_version", sa.String(20), nullable=False),
        sa.Column("received_on", sa.Date(), nullable=False),
        sa.Column("anonymizer_version", sa.Integer(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("reports")
