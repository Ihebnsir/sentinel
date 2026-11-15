"""Diagnostic TEMPORAIRE de l'IP client derrière le proxy (SENTINEL_IP_DIAGNOSTIC).

Désactivé par défaut. Activé, il journalise pour chaque POST /v1/reports une
EMPREINTE courte de chaque source possible de l'adresse du client, jamais
l'adresse elle-même :

- chaque entrée de X-Forwarded-For, numérotée depuis la DROITE (d1 = la
  dernière, celle qu'ajoute le dernier proxy ; même numéro que
  SENTINEL_PROXY_HOPS) ;
- True-Client-IP, CF-Connecting-IP, X-Real-IP ;
- l'adresse de la connexion TCP ;
- l'adresse retenue aujourd'hui par la configuration.

Empreinte = HMAC-SHA256 avec une clé aléatoire tirée au démarrage, gardée en
mémoire, jamais journalisée : on ne peut pas retrouver l'adresse à partir du
journal, et la clé disparaît au redémarrage. Les mêmes adresses donnent la
même empreinte tant que le serveur tourne : on voit donc quelle source reste
STABLE entre deux requêtes, et laquelle reprend une fausse adresse envoyée
par le client (son empreinte est donnée au démarrage, « référence »).
"""

import hashlib
import hmac
import ipaddress
import logging
import secrets

from starlette.requests import Request

log = logging.getLogger("sentinel.ip_diagnostic")

# Fausse adresse envoyée par le smoke test (tools/smoke_test.ps1 -Diagnostic).
SMOKE_FAKE_IP = "1.2.3.4"
SINGLE_HEADERS = ("true-client-ip", "cf-connecting-ip", "x-real-ip")
MAX_XFF = 6  # au-delà, entrées ignorées (en-tête gonflé par le client)
SHORT = 8  # caractères hexadécimaux affichés (32 bits)


def parse_ip(value: str) -> str | None:
    """Adresse normalisée, port éventuel retiré (« 1.2.3.4:56 », « [::1]:56 »)."""
    value = value.strip()
    if value.startswith("[") and "]" in value:
        value = value[1 : value.index("]")]
    elif value.count(":") == 1:  # IPv4 avec port
        value = value.split(":", 1)[0]
    try:
        return str(ipaddress.ip_address(value))
    except ValueError:
        return None


class IpDiagnostic:
    def __init__(self, key: bytes | None = None) -> None:
        self._key = key or secrets.token_bytes(32)

    def fingerprint(self, value: str | None) -> str:
        """Empreinte courte ; « absent » ou « invalide » sans adresse valable."""
        if value is None:
            return "absent"
        ip = parse_ip(value)
        if ip is None:
            return "invalide"
        return hmac.new(self._key, ip.encode(), hashlib.sha256).hexdigest()[:SHORT]

    def reference(self) -> str:
        return self.fingerprint(SMOKE_FAKE_IP)

    def candidates(self, request: Request, chosen: str) -> dict[str, str]:
        values = request.headers.getlist("x-forwarded-for")
        entries = [e.strip() for e in ",".join(values).split(",") if e.strip()]
        result = {"n_xff": str(len(entries))}
        for position, entry in enumerate(reversed(entries[-MAX_XFF:]), start=1):
            result[f"xff_d{position}"] = self.fingerprint(entry)
        for name in SINGLE_HEADERS:
            header = request.headers.getlist(name)
            key = name.replace("-", "_")
            if len(header) > 1:
                result[f"{key}_nb"] = str(len(header))
            result[key] = self.fingerprint(header[-1] if header else None)
        result["connexion"] = self.fingerprint(request.client.host if request.client else None)
        result["retenue"] = self.fingerprint(chosen)
        return result

    def log_request(self, request: Request, chosen: str) -> None:
        fields = " ".join(f"{k}={v}" for k, v in self.candidates(request, chosen).items())
        log.warning("diagnostic ip: %s", fields)

    def log_start(self) -> None:
        log.warning(
            "diagnostic ip ACTIF (temporaire, SENTINEL_IP_DIAGNOSTIC) : "
            "empreinte de la fausse adresse du smoke test = %s",
            self.reference(),
        )
