"""Journaux du serveur : jamais d'adresse IP ni de texte de signalement.

- Le journal d'accès d'uvicorn (qui écrit l'IP du client) est désactivé ;
  il est remplacé par sentinel.access (méthode, chemin, statut, durée).
- Un filtre efface quand même toute adresse IP qui passerait dans un message
  (par exemple dans un message d'erreur d'une bibliothèque).
"""

import logging
import re

from .anonymize import IP, IP_PATTERN

# Une IP suivie d'un port (« 1.2.3.4:5678 ») : le port part avec.
_IP_PORT = re.compile("(?:" + IP_PATTERN + ")(?::[0-9]{1,5})?")


class RedactIpFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        message = record.getMessage()
        redacted = _IP_PORT.sub(IP, message)
        if redacted != message:
            record.msg = redacted
            record.args = None
        return True


def log_config(level: str) -> dict:
    """Configuration commune à uvicorn et à l'app (dictConfig)."""
    return {
        "version": 1,
        "disable_existing_loggers": False,
        "filters": {"redact_ip": {"()": "app.logging_config.RedactIpFilter"}},
        "formatters": {"plain": {"format": "%(asctime)s %(levelname)s %(name)s: %(message)s"}},
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "formatter": "plain",
                "filters": ["redact_ip"],
                "stream": "ext://sys.stderr",
            }
        },
        "loggers": {
            "uvicorn": {"handlers": ["console"], "level": level, "propagate": False},
            "uvicorn.error": {"handlers": ["console"], "level": level, "propagate": False},
            # Coupé : il écrit l'adresse IP de chaque client.
            "uvicorn.access": {"handlers": [], "level": "CRITICAL", "propagate": False},
            "sentinel": {"handlers": ["console"], "level": level, "propagate": False},
            # Jamais les requêtes SQL (elles contiendraient le texte).
            "sqlalchemy": {"handlers": ["console"], "level": "WARNING", "propagate": False},
        },
        "root": {"handlers": ["console"], "level": "WARNING"},
    }
