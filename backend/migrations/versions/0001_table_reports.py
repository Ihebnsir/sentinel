"""Table des signalements anonymisés.

Révision : 0001
"""

import sqlalchemy as sa
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def _choice(name: str, values: tuple[str, ...]) -> sa.Enum:
    # Texte + contrainte CHECK (comme app.models).
    return sa.Enum(*values, name=name, native_enum=False, create_constraint=True, length=20)


def upgrade() -> None:
    # Aucune colonne pour l'IP, l'appareil ou l'heure : seulement le jour.
    op.create_table(
        "reports",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("verdict", _choice("verdict", ("arnaque", "suspect", "rien")), nullable=False),
        sa.Column("probability", sa.Float(), nullable=False),
        sa.Column(
            "language",
            _choice("language", ("fr", "ar", "derja_latin", "derja_arabe", "en", "autre")),
            nullable=False,
        ),
        sa.Column(
            "source",
            _choice("source", ("sms", "whatsapp", "messenger", "telegram", "autre", "inconnue")),
            nullable=False,
        ),
        sa.Column("app_version", sa.String(32), nullable=False),
        sa.Column("received_on", sa.Date(), nullable=False),
        sa.Column(
            "review_status",
            _choice("review_status", ("nouveau", "arnaque_confirmee", "pas_arnaque", "rejete")),
            nullable=False,
        ),
        sa.Column("anonymizer_version", sa.Integer(), nullable=False),
    )
    # Pour la revue : les signalements à traiter, par jour.
    op.create_index("ix_reports_status_day", "reports", ["review_status", "received_on"])


def downgrade() -> None:
    op.drop_index("ix_reports_status_day", table_name="reports")
    op.drop_table("reports")
