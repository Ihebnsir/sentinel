"""Tables de la base. Volontairement : ni adresse IP, ni appareil, ni heure."""

import datetime
import enum
import uuid

from sqlalchemy import Date, Enum, Float, Integer, String, Text, Uuid
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class Verdict(enum.StrEnum):
    arnaque = "arnaque"
    suspect = "suspect"
    rien = "rien"


class Language(enum.StrEnum):
    fr = "fr"
    ar = "ar"
    derja_latin = "derja_latin"
    derja_arabe = "derja_arabe"
    en = "en"
    autre = "autre"


class Source(enum.StrEnum):
    sms = "sms"
    whatsapp = "whatsapp"
    messenger = "messenger"
    telegram = "telegram"
    autre = "autre"
    inconnue = "inconnue"


class ReviewStatus(enum.StrEnum):
    nouveau = "nouveau"
    arnaque_confirmee = "arnaque_confirmee"
    pas_arnaque = "pas_arnaque"
    rejete = "rejete"


def _enum(cls: type[enum.Enum], name: str) -> Enum:
    # Valeurs stockées en texte, avec contrainte CHECK.
    return Enum(cls, name=name, native_enum=False, create_constraint=True, length=20)


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    # Texte DÉJÀ anonymisé (app.anonymize).
    text: Mapped[str] = mapped_column(Text, nullable=False)
    verdict: Mapped[Verdict] = mapped_column(_enum(Verdict, "verdict"), nullable=False)
    probability: Mapped[float] = mapped_column(Float, nullable=False)
    language: Mapped[Language] = mapped_column(_enum(Language, "language"), nullable=False)
    source: Mapped[Source] = mapped_column(_enum(Source, "source"), nullable=False)
    app_version: Mapped[str] = mapped_column(String(32), nullable=False)
    # Jour seulement (UTC) : l'heure exacte pourrait relier un signalement à
    # une personne.
    received_on: Mapped[datetime.date] = mapped_column(Date, nullable=False)
    review_status: Mapped[ReviewStatus] = mapped_column(
        _enum(ReviewStatus, "review_status"),
        nullable=False,
        default=ReviewStatus.nouveau,
    )
    # Version des règles d'anonymisation appliquées (app.anonymize).
    anonymizer_version: Mapped[int] = mapped_column(Integer, nullable=False)
