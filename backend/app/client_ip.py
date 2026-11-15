"""Adresse du client, pour la limite de débit UNIQUEMENT (jamais stockée ni
journalisée).

Sans proxy de confiance (défaut) : l'IP de la connexion TCP.
Avec SENTINEL_TRUST_PROXY=true : l'en-tête du proxy de l'hébergeur
(X-Forwarded-For par défaut). Le client peut écrire ce qu'il veut AU DÉBUT
de cet en-tête ; chaque proxy AJOUTE l'adresse qu'il voit À LA FIN. On lit
donc la n-ième entrée en partant de la droite (n = SENTINEL_PROXY_HOPS),
jamais la première : une fausse adresse ajoutée par le client est ignorée.

Render passe par Cloudflare (protection DDoS) : la dernière entrée de
X-Forwarded-For peut être un proxy de bord qui CHANGE à chaque requête.
Alors : SENTINEL_CLIENT_IP_HEADER=cf-connecting-ip (réécrit par Cloudflare)
ou SENTINEL_PROXY_HOPS=2. Choix guidé par SENTINEL_IP_DIAGNOSTIC
(app.ip_diagnostic) et docs/DEPLOIEMENT.md.
"""

from starlette.requests import Request

from .config import Settings
from .ip_diagnostic import parse_ip

UNKNOWN = "inconnu"


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
    return parse_ip(entries[-settings.proxy_hops]) or connection
