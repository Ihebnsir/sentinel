"""Limite de débit en mémoire, sans jamais garder l'adresse IP en clair.

Fenêtre fixe (1 h par défaut). À chaque nouvelle fenêtre, un nouveau sel
aléatoire est tiré et les compteurs sont effacés : une empreinte d'une heure
ne peut pas être reliée à celle de l'heure suivante, et rien n'est écrit sur
le disque.
"""

import hashlib
import hmac
import ipaddress
import secrets
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass


@dataclass(frozen=True)
class Decision:
    allowed: bool
    retry_after: int  # secondes avant la prochaine fenêtre


def _network_key(ip: str) -> bytes:
    """IPv6 : le /64 entier (un abonné en reçoit souvent un) ; IPv4 : l'adresse."""
    try:
        addr = ipaddress.ip_address(ip)
    except ValueError:
        return ip.encode()
    if addr.version == 6:
        if addr.ipv4_mapped is not None:
            return addr.ipv4_mapped.packed
        return ipaddress.ip_network(f"{addr}/64", strict=False).network_address.packed
    return addr.packed


class RateLimiter:
    def __init__(
        self,
        limit: int,
        window_seconds: int,
        max_keys: int,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._limit = limit
        self._window = window_seconds
        self._max_keys = max_keys
        self._clock = clock
        self._lock = threading.Lock()
        self._window_index = -1
        self._salt = b""
        self._counts: dict[bytes, int] = {}

    def _rotate_if_needed(self, now: float) -> None:
        index = int(now // self._window)
        if index != self._window_index:
            self._window_index = index
            self._salt = secrets.token_bytes(32)
            self._counts.clear()

    def fingerprint(self, ip: str) -> bytes:
        """Empreinte salée (HMAC-SHA256) : l'IP elle-même n'est jamais gardée."""
        return hmac.new(self._salt, _network_key(ip), hashlib.sha256).digest()

    def hit(self, ip: str) -> Decision:
        with self._lock:
            now = self._clock()
            self._rotate_if_needed(now)
            retry_after = max(1, int(self._window - now % self._window))
            key = self.fingerprint(ip)
            count = self._counts.get(key)
            if count is None:
                # Table pleine : on refuse les nouvelles adresses (mémoire bornée).
                if len(self._counts) >= self._max_keys:
                    return Decision(False, retry_after)
                count = 0
            if count >= self._limit:
                return Decision(False, retry_after)
            self._counts[key] = count + 1
            return Decision(True, retry_after)

    def tracked_keys(self) -> list[bytes]:
        """Pour les tests : uniquement des empreintes."""
        with self._lock:
            return list(self._counts)
