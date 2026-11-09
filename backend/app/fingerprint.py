"""Empreinte d'un texte anonymisé, pour repérer les doublons.

HMAC-SHA256 avec une clé secrète (SENTINEL_FINGERPRINT_KEY) : sans la clé,
quelqu'un qui lit la base ne peut pas tester « ce texte est-il dedans ? ».
Le texte est normalisé avant : majuscules, espaces et formes Unicode
équivalentes ne changent pas l'empreinte.
"""

import hashlib
import hmac
import re
import unicodedata

_SPACES = re.compile(r"\s+")


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKC", text).casefold()
    return _SPACES.sub(" ", text).strip()


def fingerprint(text: str, key: bytes) -> str:
    """64 caractères hexadécimaux."""
    return hmac.new(key, normalize(text).encode(), hashlib.sha256).hexdigest()
