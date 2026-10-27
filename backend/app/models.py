"""Table des signalements. Volontairement pauvre : aucune donnée personnelle."""

import datetime as dt

from sqlalchemy import Date, Integer, String, Text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # Texte déjà anonymisé (jamais le texte reçu).
    text: Mapped[str] = mapped_column(Text, nullable=False)
    verdict: Mapped[str] = mapped_column(String(16), nullable=False)
    language: Mapped[str] = mapped_column(String(8), nullable=False)
    app_version: Mapped[str] = mapped_column(String(20), nullable=False)
    # Jour seulement, pas l'heure : impossible de recouper avec un journal.
    received_on: Mapped[dt.date] = mapped_column(Date, nullable=False)
    anonymizer_version: Mapped[int] = mapped_column(Integer, nullable=False)
