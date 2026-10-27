"""Format d'un signalement, validé strictement (Pydantic)."""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

# Mêmes valeurs que l'enum Verdict de l'app (message_analyzer.dart).
Verdict = Literal["arnaque", "suspect", "rien"]

# Langues de l'app ; « und » : langue du message inconnue.
Language = Literal["fr", "en", "ar", "und"]

MAX_TEXT_LENGTH = 2000


class ReportIn(BaseModel):
    """Corps de POST /v1/reports. Tout champ en plus est refusé."""

    model_config = ConfigDict(extra="forbid", strict=True, frozen=True)

    text: str = Field(min_length=1, max_length=MAX_TEXT_LENGTH)
    verdict: Verdict
    language: Language
    # Version de l'app : 1.2.3 ou 1.2.3+45, rien d'autre.
    app_version: str = Field(
        max_length=20, pattern=r"^\d{1,3}\.\d{1,3}\.\d{1,3}(\+\d{1,6})?$"
    )


class ReportAccepted(BaseModel):
    """Réponse : aucun identifiant, rien qui permette de relier l'envoi."""

    status: str = "recu"
