"""Limite de débit : en mémoire, empreintes salées, jamais l'IP en clair."""

from collections.abc import Callable

from fastapi.testclient import TestClient

from app.rate_limit import RateLimiter

from .conftest import CLIENT_IP, valid_report


class FakeClock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


def test_limite_par_adresse() -> None:
    limiter = RateLimiter(limit=3, window_seconds=3600, max_keys=100, clock=FakeClock())
    assert [limiter.hit("1.2.3.4").allowed for _ in range(4)] == [True, True, True, False]
    # Une autre adresse a son propre compteur.
    assert limiter.hit("5.6.7.8").allowed


def test_nouvelle_fenetre_nouveau_sel() -> None:
    clock = FakeClock()
    limiter = RateLimiter(limit=1, window_seconds=3600, max_keys=100, clock=clock)
    assert limiter.hit("1.2.3.4").allowed
    first = limiter.fingerprint("1.2.3.4")
    assert not limiter.hit("1.2.3.4").allowed
    clock.now += 3600
    assert limiter.hit("1.2.3.4").allowed
    # Le sel a changé : impossible de relier les deux heures.
    assert limiter.fingerprint("1.2.3.4") != first


def test_aucune_ip_en_memoire() -> None:
    limiter = RateLimiter(limit=5, window_seconds=3600, max_keys=100, clock=FakeClock())
    limiter.hit("203.0.113.9")
    keys = limiter.tracked_keys()
    assert len(keys) == 1
    assert b"203.0.113.9" not in keys[0]
    assert bytes([203, 0, 113, 9]) not in keys[0]
    assert len(keys[0]) == 32  # HMAC-SHA256


def test_ipv6_meme_sous_reseau() -> None:
    limiter = RateLimiter(limit=1, window_seconds=3600, max_keys=100, clock=FakeClock())
    assert limiter.hit("2001:db8:1:2::1").allowed
    # Même /64 : même compteur (changer d'adresse ne contourne pas la limite).
    assert not limiter.hit("2001:db8:1:2::ffff").allowed
    assert limiter.hit("2001:db8:1:3::1").allowed


def test_memoire_bornee() -> None:
    limiter = RateLimiter(limit=5, window_seconds=3600, max_keys=2, clock=FakeClock())
    assert limiter.hit("1.1.1.1").allowed
    assert limiter.hit("2.2.2.2").allowed
    assert not limiter.hit("3.3.3.3").allowed  # table pleine
    assert limiter.hit("1.1.1.1").allowed  # adresse déjà suivie


def test_api_repond_429(make_client: Callable[..., TestClient]) -> None:
    client = make_client(rate_limit_per_window=2)
    assert client.post("/v1/reports", json=valid_report()).status_code == 201
    assert client.post("/v1/reports", json=valid_report()).status_code == 201
    response = client.post("/v1/reports", json=valid_report())
    assert response.status_code == 429
    assert int(response.headers["retry-after"]) > 0
    assert CLIENT_IP not in response.text
    # La santé n'est pas limitée.
    assert client.get("/v1/health").status_code == 200
