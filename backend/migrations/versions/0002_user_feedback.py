"""Avis de l'utilisateur (facultatif) sur chaque signalement.

Révision : 0002
"""

import sqlalchemy as sa
from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None

_VALUES = ("arnaque", "pas_arnaque", "ne_sait_pas")


def upgrade() -> None:
    # Colonne NULL autorisée : les anciens signalements et clients n'en ont pas.
    # Mode batch : SQLite recrée la table pour ajouter la contrainte CHECK.
    with op.batch_alter_table("reports") as batch:
        batch.add_column(
            sa.Column(
                "user_feedback",
                sa.Enum(
                    *_VALUES,
                    name="user_feedback",
                    native_enum=False,
                    create_constraint=True,
                    length=20,
                ),
                nullable=True,
            )
        )


def downgrade() -> None:
    # La contrainte CHECK d'abord, sinon la table recréée la garde.
    with op.batch_alter_table("reports") as batch:
        batch.drop_constraint("user_feedback", type_="check")
        batch.drop_column("user_feedback")
