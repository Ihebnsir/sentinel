"""Derrière le proxy de l'hébergeur : IP du client pour la limite de débit,
HTTPS obligatoire, et jamais d'IP stockée ni journalisée."""

import logging
from collections.abc import Callable
from typing import Any

import pytest
from fastapi.testclient import TestClient
from starlette.requests import Request

from app.client_ip import client_ip

from .conftest import CLIENT_IP, make_settings, valid_report

PROXY_IP = "10.20.0.5"  # le proxy de l'hébergeur, vu par le serveur


def _request(headers: list[tuple[str, str]], peer: str = PROXY_IP) -> Request:
    scope = {
        "type": "http",
        "headers": [(k.lower().encode(), v.encode()) for k, v in headers],
        "client": (peer, 40000),
    }
    return Request(scope)


def _ip(headers: list[tuple[str, str]], **settings: Any) -> str:
    return client_ip(_request(headers), make_settings("sqlite://", **settings))


def test_sans_proxy_de_confiance_en_tete_ignore() -> None:
    assert _ip([("X-Forwarded-For", "198.51.100.1")]) == PROXY_IP


def test_proxy_de_confiance_derniere_entree() -> None:
    headers = [("X-Forwarded-For", "6.6.6.6, 198.51.100.1")]
    # « 6.6.6.6 » a été écrit par le client : ignoré.
    assert _ip(headers, trust_proxy=True) == "198.51.100.1"


def test_deux_proxys() -> None:
    headers = [("X-Forwarded-For", "6.6.6.6, 198.51.100.1, 10.0.0.9")]
    assert _ip(headers, trust_proxy=True, proxy_hops=2) == "198.51.100.1"


def test_plusieurs_en_tetes_lus_dans_l_ordre() -> None:
    headers = [("X-Forwarded-For", "6.6.6.6"), ("X-Forwarded-For", "198.51.100.1")]
    assert _ip(headers, trust_proxy=True) == "198.51.100.1"


@pytest.mark.parametrize("value", ["", "pas-une-ip", " , "])
def test_en_tete_absent_ou_invalide(value: str) -> None:
    headers = [("X-Forwarded-For", value)] if value else []
    assert _ip(headers, trust_proxy=True) == PROXY_IP


def test_en_tete_configurable() -> None:
    headers = [("True-Client-IP", "2001:db8::1"), ("X-Forwarded-For", "6.6.6.6")]
    ip = _ip(headers, trust_proxy=True, client_ip_header="true-client-ip")
    assert ip == "2001:db8::1"


def _post(client: TestClient, forwarded: str, proto: str | None = None) -> int:
    headers = {"X-Forwarded-For": forwarded}
    if proto:
        headers["X-Forwarded-Proto"] = proto
    return client.post("/v1/reports", json=valid_report(), headers=headers).status_code


def test_api_sans_confiance_une_seule_adresse(make_client: Callable[..., TestClient]) -> None:
    client = make_client(rate_limit_per_window=1)
    # Changer l'en-tête ne contourne pas la limite : l'IP de connexion compte.
    assert _post(client, "198.51.100.1") == 201
    assert _post(client, "198.51.100.2") == 429


def test_api_avec_confiance_une_limite_par_client(
    make_client: Callable[..., TestClient],
) -> None:
    client = make_client(rate_limit_per_window=1, trust_proxy=True)
    assert _post(client, "198.51.100.1") == 201
    assert _post(client, "198.51.100.2") == 201
    # Usurpation : le client invente une adresse au début, la vraie reste à la fin.
    assert _post(client, "6.6.6.6, 198.51.100.1") == 429


def test_ip_jamais_stockee_ni_journalisee(
    make_client: Callable[..., TestClient],
    rows: Callable[[], list[dict[str, Any]]],
    caplog: pytest.LogCaptureFixture,
) -> None:
    client = make_client(trust_proxy=True, env="prod")
    with caplog.at_level(logging.DEBUG):
        assert _post(client, "198.51.100.77", proto="https") == 201
    logs = "\n".join(r.getMessage() for r in caplog.records)
    stored = repr(rows())
    for ip in ("198.51.100.77", CLIENT_IP):
        assert ip not in logs and ip not in stored


def test_https_obligatoire_derriere_le_proxy(make_client: Callable[..., TestClient]) -> None:
    client = make_client(trust_proxy=True, rate_limit_per_window=100)
    response = client.post(
        "/v1/reports",
        json=valid_report(),
        headers={"X-Forwarded-For": "198.51.100.1", "X-Forwarded-Proto": "http"},
    )
    assert response.status_code == 400
    assert response.json() == {"detail": "HTTPS obligatoire"}
    assert _post(client, "198.51.100.1", proto="https") == 201
    # Contrôle de santé interne de l'hébergeur : sans en-tête, accepté.
    assert client.get("/v1/health").status_code == 200


def test_en_tete_proto_ignore_sans_proxy_de_confiance(
    make_client: Callable[..., TestClient],
) -> None:
    client = make_client()
    assert _post(client, "198.51.100.1", proto="http") == 201


def test_hsts_deux_ans(client: TestClient) -> None:
    hsts = client.get("/v1/health").headers["strict-transport-security"]
    assert hsts == "max-age=63072000; includeSubDomains"
