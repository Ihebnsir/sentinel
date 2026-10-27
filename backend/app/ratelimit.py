"""Limite de débit en mémoire, sans garder l'adresse IP.

L'adresse est remplacée par un HMAC-SHA256 avec une clé aléatoire tirée au
démarrage et jamais écrite : on peut compter les requêtes d'un même client,
mais pas retrouver son adresse, même avec un accès à la mémoire après coup
(la clé disparaît à l'arrêt). Rien n'est écrit sur disque.
"""

import hashlib
import hmac
import secrets
import threading
import time
from collections import OrderedDict, deque
from collections.abc import Callable


class RateLimiter:
    def __init__(
        self,
        limit: int,
        window_seconds: float,
        max_clients: int = 10_000,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._limit = limit
        self._window = window_seconds
        self._max_clients = max_clients
        self._clock = clock
        self._key = secrets.token_bytes(32)
        self._hits: OrderedDict[bytes, deque[float]] = OrderedDict()
        self._lock = threading.Lock()

    def _client_id(self, address: str) -> bytes:
        return hmac.new(self._key, address.encode(), hashlib.sha256).digest()

    def allow(self, address: str) -> bool:
        """Vrai si ce client peut encore envoyer une requête maintenant."""
        now = self._clock()
        client = self._client_id(address)
        with self._lock:
            hits = self._hits.pop(client, None) or deque()
            while hits and hits[0] <= now - self._window:
                hits.popleft()
            allowed = len(hits) < self._limit
            if allowed:
                hits.append(now)
            if hits:
                self._hits[client] = hits  # en dernier : le plus récent
            # Trop de clients suivis : on oublie les plus anciens.
            while len(self._hits) > self._max_clients:
                self._hits.popitem(last=False)
            return allowed

    def tracked_clients(self) -> list[bytes]:
        """Pour les tests : identifiants gardés en mémoire."""
        with self._lock:
            return list(self._hits)
