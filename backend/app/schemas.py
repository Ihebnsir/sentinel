"""Formats d'entrée et de sortie de l'API (validation stricte)."""

import re
import uuid
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, field_validator

from .models import Language, Source, Verdict

# Caractères de contrôle refusés (sauf tabulation et retours à la ligne).
_CONTROL = re.compile("[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
_VERSION = r"^[0-9]{1,4}(\.[0-9]{1,4}){0,3}(\+[0-9]{1,9})?$"


class ReportIn(BaseModel):
    # Champs inconnus refusés.
    model_config = ConfigDict(extra="forbid", frozen=True)

    # strict=True : pas de conversion implicite (« 0.5 » texte ≠ 0.5).
    text: Annotated[str, Field(strict=True, min_length=1, max_length=2000)]
    verdict: Verdict
    probability: Annotated[float, Field(strict=True, ge=0.0, le=1.0, allow_inf_nan=False)]
    language: Language
    app_version: Annotated[str, Field(strict=True, max_length=32, pattern=_VERSION)]
    source: Source

    @field_validator("text")
    @classmethod
    def _clean_text(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("texte vide")
        if _CONTROL.search(value):
            raise ValueError("caractère de contrôle interdit")
        return value


class ReportCreated(BaseModel):
    id: uuid.UUID


class Health(BaseModel):
    status: str
