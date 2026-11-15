"""Description NETTOYÉE d'une erreur de base, pour les journaux et les outils.

Donne le type d'erreur, le code SQLSTATE, une piste en français et un court
message du pilote, débarrassé de tout ce qui pourrait être secret ou
personnel : URL, mot de passe, nom d'hôte, adresse IP, valeurs entre
guillemets (un morceau de signalement), requête SQL et ses paramètres.
"""

import re
from collections.abc import Iterable

from .anonymize import IP_PATTERN

MAX_MESSAGE = 160

# Pistes de diagnostic selon le code SQLSTATE (PostgreSQL).
HINTS = {
    "28P01": "mot de passe refusé (URL ou ALTER ROLE à refaire)",
    "28000": "rôle inconnu ou connexion non autorisée",
    "3D000": "base inconnue (nom de base dans l'URL)",
    "42501": "droits manquants (relancer sql/roles.sql)",
    "42P01": "table absente (migrations pas appliquées)",
    "53300": "trop de connexions",
    "57P01": "connexion fermée par le serveur (base en veille ?)",
    "57014": "requête annulée (délai dépassé)",
}
# Sans SQLSTATE (échec AVANT d'atteindre la base) : piste d'après le message.
_TEXT_HINTS = (
    ("password authentication failed", "mot de passe refusé (URL ou ALTER ROLE à refaire)"),
    ("root certificate", "certificats racine introuvables (sslmode=verify-full)"),
    ("certificate verify failed", "certificat du serveur refusé (TLS)"),
    ("ssl", "problème TLS (sslmode, channel_binding)"),
    ("channel binding", "problème TLS (channel_binding)"),
    ("timeout expired", "délai de connexion dépassé (base en veille, réseau)"),
    ("could not translate host name", "hôte introuvable (URL)"),
    ("name or service not known", "hôte introuvable (URL)"),
    ("does not exist", "rôle ou base inconnu"),
    ("connection refused", "connexion refusée (hôte, port)"),
    ("no such table", "table absente (migrations pas appliquées)"),
)

_SUBSTITUTIONS = (
    # Requête et paramètres ajoutés par SQLAlchemy.
    (re.compile(r"\[SQL:.*", re.DOTALL), ""),
    # URL complètes (postgresql://utilisateur:motdepasse@hôte/base…).
    (re.compile(r"\b[a-z][a-z0-9+.-]*://\S+", re.IGNORECASE), "[URL]"),
    # Mots de passe Neon (npg_…) et paires clé=valeur sensibles.
    (re.compile(r"npg_\w+", re.IGNORECASE), "[SECRET]"),
    (
        re.compile(r"\b(password|passwd|pwd|user|host|hostaddr)\s*=\s*\S+", re.IGNORECASE),
        r"\1=[MASQUÉ]",
    ),
    # Adresses IP (avec port éventuel).
    (re.compile("(?:" + IP_PATTERN + ")(?::[0-9]{1,5})?"), "[IP]"),
    # Noms d'hôte (ep-xxx.eu-central-1.aws.neon.tech, localhost…).
    (re.compile(r"\b(?:[a-z0-9-]+\.)+[a-z]{2,}\b", re.IGNORECASE), "[HÔTE]"),
    (re.compile(r"\blocalhost\b", re.IGNORECASE), "[HÔTE]"),
)
# Entre guillemets : seul un identifiant SQL simple (nom de rôle, de table)
# est gardé ; tout le reste (une valeur, un morceau de texte) est masqué.
_QUOTED = re.compile(r'"([^"]*)"|\'([^\']*)\'')
_IDENTIFIER = re.compile(r"[a-z_][a-z0-9_]{0,62}")


def _keep_identifier(match: re.Match[str]) -> str:
    inner = match.group(1) if match.group(1) is not None else match.group(2)
    return f'"{inner}"' if _IDENTIFIER.fullmatch(inner) else '"[…]"'


def clean_message(message: str, forbidden: Iterable[str | None] = ()) -> str:
    """Message court, sur une ligne, sans secret ni donnée personnelle.

    forbidden : textes qui ne doivent jamais ressortir (le signalement, l'URL,
    un mot de passe). Ils sont masqués même s'ils ne ressemblent à rien.
    """
    for secret in forbidden:
        if secret and len(secret) >= 3:
            message = message.replace(secret, "[MASQUÉ]")
    for pattern, replacement in _SUBSTITUTIONS:
        message = pattern.sub(replacement, message)
    message = _QUOTED.sub(_keep_identifier, message)
    message = " ".join(message.split())
    if len(message) > MAX_MESSAGE:
        message = message[: MAX_MESSAGE - 1] + "…"
    return message


def _driver_error(exc: BaseException) -> BaseException:
    # SQLAlchemy enveloppe l'erreur du pilote (psycopg, sqlite3) dans .orig.
    return getattr(exc, "orig", None) or exc


def sqlstate(exc: BaseException) -> str | None:
    """Code SQLSTATE (psycopg) ou nom d'erreur SQLite ; None sinon."""
    driver = _driver_error(exc)
    code = getattr(driver, "sqlstate", None) or getattr(driver, "sqlite_errorname", None)
    return str(code) if code else None


def hint(code: str | None, message: str) -> str:
    if code and code in HINTS:
        return HINTS[code]
    lowered = message.lower()
    for needle, text in _TEXT_HINTS:
        if needle in lowered:
            return text
    return "inconnue"


def describe(exc: BaseException, forbidden: Iterable[str | None] = ()) -> str:
    """« type=… sqlstate=… piste=… message=… », sûr à journaliser.

    Le message vient de l'erreur du PILOTE seulement : celui de SQLAlchemy
    recopie la requête et ses paramètres (donc le texte du signalement).
    """
    driver = getattr(exc, "orig", None)
    if driver is not None:
        raw = str(driver)
    elif type(exc).__module__.startswith("sqlalchemy"):
        # Erreur SQLAlchemy sans erreur de pilote : son texte n'est pas sûr.
        raw = ""
    else:
        raw = str(exc)
    raw = " ".join(raw.split())
    # Échec de connexion : la cause utile est après « FATAL: ».
    fatal = raw.find("FATAL:")
    if fatal > 0:
        raw = raw[fatal:]
    code = sqlstate(exc)
    message = clean_message(raw, forbidden)
    return (
        f"type={type(exc).__name__} sqlstate={code or 'aucun'} "
        f"piste={hint(code, raw)} message={message or '-'}"
    )
