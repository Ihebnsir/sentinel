"""Diagnostic temporaire de l'IP client (SENTINEL_IP_DIAGNOSTIC), et
configurations finales possibles derrière Render + Cloudflare."""

import logging
import re
from collections.abc import Callable
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.ip_diagnostic import SMOKE_FAKE_IP, IpDiagnostic, parse_ip

from .conftest import valid_report

CLIENT = "198.51.100.7"  # le téléphone (plage de documentation)
OTHER = "203.0.113.9"  # un autre client
EDGES = ["172.70.1.1", "172.70.2.2", "172.70.3.3"]  # proxys qui changent
ALL_IPS = [CLIENT, OTHER, SMOKE_FAKE_IP, *EDGES]


def _post(client: TestClient, headers: dict[str, str], text: str = "message") -> int:
    return client.post("/v1/reports", json=valid_report(text=text), headers=headers).status_code


def _fields(message: str) -> dict[str, str]:
    return dict(re.findall(r"(\w+)=(\S+)", message.split("diagnostic ip: ", 1)[1]))


def _diagnostic_lines(caplog: pytest.LogCaptureFixture) -> list[dict[str, str]]:
    return [_fields(r.getMessage()) for r in caplog.records if "diagnostic ip: " in r.getMessage()]


# --- Empreintes --------------------------------------------------------------


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("198.51.100.7", "198.51.100.7"),
        (" 198.51.100.7:4242 ", "198.51.100.7"),
        ("[2001:db8::1]:443", "2001:db8::1"),
        ("2001:DB8::1", "2001:db8::1"),
        ("pas-une-ip", None),
        ("", None),
    ],
)
def test_parse_ip(value: str, expected: str | None) -> None:
    assert parse_ip(value) == expected


def test_empreinte_courte_stable_et_salee() -> None:
    first, second = IpDiagnostic(), IpDiagnostic()
    assert first.fingerprint(CLIENT) == first.fingerprint(CLIENT + ":1234")
    assert re.fullmatch(r"[0-9a-f]{8}", first.fingerprint(CLIENT))
    assert first.fingerprint(CLIENT) != first.fingerprint(OTHER)
    # Nouvelle clé au démarrage : l'empreinte change, rien à relier.
    assert first.fingerprint(CLIENT) != second.fingerprint(CLIENT)
    assert first.fingerprint(None) == "absent"
    assert first.fingerprint("x") == "invalide"


# --- Dans l'API ----------------------------------------------------------------


def test_desactive_par_defaut(
    make_client: Callable[..., TestClient], caplog: pytest.LogCaptureFixture
) -> None:
    client = make_client(trust_proxy=True)
    with caplog.at_level(logging.DEBUG):
        assert _post(client, {"X-Forwarded-For": CLIENT}) == 201
    assert client.app.state.ip_diagnostic is None
    assert not any("diagnostic ip" in r.getMessage() for r in caplog.records)


def test_diagnostic_montre_la_source_stable_sans_ip(
    make_client: Callable[..., TestClient], caplog: pytest.LogCaptureFixture
) -> None:
    client = make_client(trust_proxy=True, ip_diagnostic=True, rate_limit_per_window=1000)
    diagnostic: IpDiagnostic = client.app.state.ip_diagnostic
    with caplog.at_level(logging.INFO):
        # Comme derrière Cloudflare : le proxy de bord change à chaque requête.
        for n, edge in enumerate(EDGES):
            headers = {"X-Forwarded-For": f"{CLIENT}, {edge}", "CF-Connecting-IP": CLIENT}
            assert _post(client, headers, f"normal {n}") == 201
        # Faux en-têtes du client (le proxy réécrit CF-Connecting-IP, ajoute à XFF).
        fake = {
            "X-Forwarded-For": f"{SMOKE_FAKE_IP}, {CLIENT}, {EDGES[0]}",
            "True-Client-IP": SMOKE_FAKE_IP,
            "CF-Connecting-IP": CLIENT,
        }
        assert _post(client, fake, "faux") == 201

    everything = "\n".join(r.getMessage() for r in caplog.records)
    for ip in ALL_IPS:
        assert ip not in everything  # jamais d'IP en clair
    assert diagnostic._key.hex() not in everything  # ni la clé
    assert f"= {diagnostic.reference()}" in everything  # référence au démarrage

    lines = _diagnostic_lines(caplog)
    assert len(lines) == 4
    normal, spoofed = lines[:3], lines[3]
    client_fp = diagnostic.fingerprint(CLIENT)
    # CF-Connecting-IP et xff_d2 : stables. xff_d1 (dernier proxy) : change.
    assert {line["cf_connecting_ip"] for line in normal} == {client_fp}
    assert {line["xff_d2"] for line in normal} == {client_fp}
    assert len({line["xff_d1"] for line in normal}) == 3
    # Configuration actuelle (dernière entrée) : « retenue » change aussi.
    assert len({line["retenue"] for line in normal}) == 3
    # Requête truquée : la fausse adresse n'apparaît qu'en tête de XFF et
    # dans True-Client-IP (non réécrit) ; les sources sûres ne bougent pas.
    assert spoofed["n_xff"] == "3"
    assert spoofed["xff_d3"] == diagnostic.reference()
    assert spoofed["true_client_ip"] == diagnostic.reference()
    assert spoofed["cf_connecting_ip"] == spoofed["xff_d2"] == client_fp
    assert spoofed["connexion"] == normal[0]["connexion"]


# --- Configurations finales ---------------------------------------------------


@pytest.mark.parametrize(
    ("settings", "description"),
    [
        ({"client_ip_header": "cf-connecting-ip", "proxy_hops": 1}, "CF-Connecting-IP"),
        ({"client_ip_header": "x-forwarded-for", "proxy_hops": 2}, "X-Forwarded-For, 2e"),
    ],
)
def test_configuration_finale_limite_par_client(
    make_client: Callable[..., TestClient], settings: dict[str, object], description: str
) -> None:
    client = make_client(trust_proxy=True, rate_limit_per_window=2, **settings)

    def headers(ip: str, edge: str, fake: str | None = None) -> dict[str, str]:
        forwarded = f"{ip}, {edge}" if fake is None else f"{fake}, {ip}, {edge}"
        return {"X-Forwarded-For": forwarded, "CF-Connecting-IP": ip}

    # Même client, proxy de bord différent à chaque fois : UNE seule limite.
    assert _post(client, headers(CLIENT, EDGES[0]), "a") == 201
    assert _post(client, headers(CLIENT, EDGES[1]), "b") == 201
    assert _post(client, headers(CLIENT, EDGES[2]), "c") == 429, description
    # Une fausse adresse en tête de X-Forwarded-For ne contourne rien.
    assert _post(client, headers(CLIENT, EDGES[0], fake=SMOKE_FAKE_IP), "d") == 429
    # Un autre client a sa propre limite.
    assert _post(client, headers(OTHER, EDGES[1]), "e") == 201


def test_derniere_entree_ne_limite_pas_derriere_un_bord_changeant(
    make_client: Callable[..., TestClient],
) -> None:
    # Le bug vu en production : on lisait le proxy de bord, qui change.
    client = make_client(trust_proxy=True, rate_limit_per_window=2)
    for n, edge in enumerate(EDGES):
        assert _post(client, {"X-Forwarded-For": f"{CLIENT}, {edge}"}, f"x{n}") == 201


# --- Configuration de production (render.yaml) -----------------------------

RENDER_YAML = Path(__file__).resolve().parents[2] / "render.yaml"


def _render_settings() -> dict[str, str]:
    import yaml

    service = yaml.safe_load(RENDER_YAML.read_text(encoding="utf-8"))["services"][0]
    return {v["key"]: v["value"] for v in service["envVars"] if "value" in v}


def test_render_yaml_lit_cf_connecting_ip() -> None:
    env = _render_settings()
    assert env["SENTINEL_TRUST_PROXY"] == "true"
    assert env["SENTINEL_CLIENT_IP_HEADER"] == "cf-connecting-ip"
    assert env["SENTINEL_PROXY_HOPS"] == "1"
    assert env["SENTINEL_IP_DIAGNOSTIC"] == "false"


def test_render_yaml_limite_par_client_et_non_falsifiable(
    make_client: Callable[..., TestClient],
) -> None:
    env = _render_settings()
    client = make_client(
        trust_proxy=True,
        client_ip_header=env["SENTINEL_CLIENT_IP_HEADER"],
        proxy_hops=int(env["SENTINEL_PROXY_HOPS"]),
        rate_limit_per_window=2,
    )

    def via_cloudflare(ip: str, edge: str, fake: dict[str, str] | None = None) -> dict[str, str]:
        # Cloudflare ajoute à X-Forwarded-For et RÉÉCRIT CF-Connecting-IP.
        headers = dict(fake or {})
        forwarded = headers.pop("X-Forwarded-For", None)
        headers["X-Forwarded-For"] = ", ".join(x for x in (forwarded, ip, edge) if x)
        headers["CF-Connecting-IP"] = ip
        return headers

    fake = {"X-Forwarded-For": SMOKE_FAKE_IP, "True-Client-IP": SMOKE_FAKE_IP}
    assert _post(client, via_cloudflare(CLIENT, EDGES[0]), "a") == 201
    assert _post(client, via_cloudflare(CLIENT, EDGES[1]), "b") == 201
    assert _post(client, via_cloudflare(CLIENT, EDGES[2]), "c") == 429
    assert _post(client, via_cloudflare(CLIENT, EDGES[0], fake), "d") == 429
    assert _post(client, via_cloudflare(OTHER, EDGES[1]), "e") == 201
