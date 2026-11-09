"""Adresse du client, pour la limite de débit UNIQUEMENT (jamais stockée ni
journalisée).

Sans proxy de confiance (défaut) : l'IP de la connexion TCP.
Avec SENTINEL_TRUST_PROXY=true : l'en-tête du proxy de l'hébergeur
(X-Forwarded-For par défaut). Le client peut écrire ce qu'il veut AU DÉBUT
de cet en-tête ; chaque proxy AJOUTE l'adresse qu'il voit À LA FIN. On lit
donc la n-ième entrée en partant de la droite (n = SENTINEL_PROXY_HOPS),
jamais la première : une fausse adresse ajoutée par le client est ignorée.
"""

import ipaddress

from starlette.requests import Request

from .config import Settings

UNKNOWN = "inconnu"


def _valid_ip(value: str) -> str | None:
    try:
        return str(ipaddress.ip_address(value.strip()))
    except ValueError:
        return None


def client_ip(request: Request, settings: Settings) -> str:
    connection = request.client.host if request.client else UNKNOWN
    if not settings.trust_proxy:
        return connection
    # Plusieurs en-têtes du même nom = une seule liste, dans l'ordre.
    values = request.headers.getlist(settings.client_ip_header)
    entries = [e.strip() for e in ",".join(values).split(",") if e.strip()]
    if len(entries) < settings.proxy_hops:
        # Requête arrivée sans passer par le proxy (ex. contrôle de santé).
        return connection
    return _valid_ip(entries[-settings.proxy_hops]) or connection
