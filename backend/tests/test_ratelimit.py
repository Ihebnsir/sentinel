"""Limite de débit : fenêtre glissante, aucune adresse IP gardée."""

from app.ratelimit import RateLimiter


class FakeClock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


def test_fenetre_glissante() -> None:
    clock = FakeClock()
    limiter = RateLimiter(limit=2, window_seconds=60, clock=clock)
    assert limiter.allow("1.2.3.4")
    assert limiter.allow("1.2.3.4")
    assert not limiter.allow("1.2.3.4")
    clock.now += 59
    assert not limiter.allow("1.2.3.4")
    clock.now += 2  # la première requête sort de la fenêtre
    assert limiter.allow("1.2.3.4")


def test_clients_independants() -> None:
    limiter = RateLimiter(limit=1, window_seconds=60, clock=FakeClock())
    assert limiter.allow("1.2.3.4")
    assert limiter.allow("5.6.7.8")
    assert not limiter.allow("1.2.3.4")


def test_aucune_adresse_en_memoire() -> None:
    limiter = RateLimiter(limit=5, window_seconds=60, clock=FakeClock())
    address = "197.15.42.200"
    limiter.allow(address)
    ids = limiter.tracked_clients()
    assert len(ids) == 1
    assert address.encode() not in ids[0]
    assert len(ids[0]) == 32  # HMAC-SHA256


def test_cle_differente_a_chaque_demarrage() -> None:
    # Le même client n'a pas le même identifiant d'un démarrage à l'autre.
    first = RateLimiter(limit=5, window_seconds=60, clock=FakeClock())
    second = RateLimiter(limit=5, window_seconds=60, clock=FakeClock())
    first.allow("1.2.3.4")
    second.allow("1.2.3.4")
    assert first.tracked_clients() != second.tracked_clients()


def test_memoire_bornee() -> None:
    limiter = RateLimiter(limit=1, window_seconds=60, max_clients=100, clock=FakeClock())
    for i in range(1000):
        limiter.allow(f"10.0.{i // 256}.{i % 256}")
    assert len(limiter.tracked_clients()) == 100


def test_clients_expires_oublies() -> None:
    clock = FakeClock()
    limiter = RateLimiter(limit=1, window_seconds=60, clock=clock)
    limiter.allow("1.2.3.4")
    clock.now += 61
    limiter.allow("5.6.7.8")
    # 1.2.3.4 n'est plus suivi qu'à sa prochaine requête : la fenêtre
    # vidée le fait disparaître.
    limiter.allow("1.2.3.4")
    assert len(limiter.tracked_clients()) == 2
