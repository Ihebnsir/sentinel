"""API /v1 : santé, validation stricte, taille, en-têtes, mode production."""

import uuid
from collections.abc import Callable

import pytest
from fastapi.testclient import TestClient

from .conftest import valid_report


def test_sante_sans_info_interne(client: TestClient) -> None:
    response = client.get("/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert "server" not in response.headers


def test_signalement_valide(client: TestClient) -> None:
    response = client.post("/v1/reports", json=valid_report())
    assert response.status_code == 201
    body = response.json()
    assert list(body) == ["id"]
    assert uuid.UUID(body["id"]).version == 4


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("text", ""),
        ("text", "   \n "),
        ("text", "a" * 2001),
        ("text", "nul\x00caché"),
        ("text", 12345),
        ("verdict", "dangereux"),
        ("probability", 1.5),
        ("probability", -0.1),
        ("probability", "0.5"),
        ("language", "it"),
        ("source", "email"),
        ("app_version", "v1.0"),
        ("app_version", "1.0.0; DROP TABLE"),
        ("app_version", 1),
    ],
)
def test_valeurs_refusees(client: TestClient, field: str, value: object) -> None:
    response = client.post("/v1/reports", json=valid_report(**{field: value}))
    assert response.status_code == 422


def test_limites_du_texte_acceptees(client: TestClient) -> None:
    assert client.post("/v1/reports", json=valid_report(text="a")).status_code == 201
    # 2000 caractères arabes : la limite compte des caractères, pas des octets.
    arabic = "ب" * 2000
    assert client.post("/v1/reports", json=valid_report(text=arabic)).status_code == 201


def test_probabilite_entiere_acceptee(client: TestClient) -> None:
    assert client.post("/v1/reports", json=valid_report(probability=1)).status_code == 201


def test_champ_inconnu_refuse(client: TestClient) -> None:
    for extra in ({"device_id": "abc"}, {"ip": "1.2.3.4"}, {"review_status": "rejete"}):
        response = client.post("/v1/reports", json=valid_report(**extra))
        assert response.status_code == 422, extra


def test_champ_manquant_refuse(client: TestClient) -> None:
    report = valid_report()
    del report["source"]
    assert client.post("/v1/reports", json=report).status_code == 422


def test_erreur_ne_renvoie_pas_le_texte(client: TestClient) -> None:
    private = "texte-prive-98123456"
    response = client.post("/v1/reports", json=valid_report(text=private, verdict="x"))
    assert response.status_code == 422
    assert private not in response.text


def test_json_invalide(client: TestClient) -> None:
    response = client.post(
        "/v1/reports", content=b"{pas du json", headers={"content-type": "application/json"}
    )
    assert response.status_code == 422


def test_requete_trop_grande(client: TestClient) -> None:
    huge = b'{"text": "' + b"a" * 20_000 + b'"}'
    response = client.post(
        "/v1/reports", content=huge, headers={"content-type": "application/json"}
    )
    assert response.status_code == 413


def test_requete_trop_grande_sans_longueur(client: TestClient) -> None:
    # Corps envoyé par morceaux, sans Content-Length annoncé.
    def chunks():
        for _ in range(40):
            yield b"a" * 1000

    response = client.post(
        "/v1/reports", content=chunks(), headers={"content-type": "application/json"}
    )
    assert response.status_code == 413


def test_en_tetes_de_securite(client: TestClient) -> None:
    headers = client.get("/v1/health").headers
    assert headers["x-content-type-options"] == "nosniff"
    assert headers["x-frame-options"] == "DENY"
    assert headers["referrer-policy"] == "no-referrer"
    assert headers["content-security-policy"].startswith("default-src 'none'")
    assert headers["cache-control"] == "no-store"


def test_cors_ferme(client: TestClient) -> None:
    response = client.options(
        "/v1/reports",
        headers={"origin": "https://evil.example", "access-control-request-method": "POST"},
    )
    assert "access-control-allow-origin" not in response.headers
    response = client.post(
        "/v1/reports", json=valid_report(), headers={"origin": "https://evil.example"}
    )
    assert "access-control-allow-origin" not in response.headers


@pytest.mark.parametrize("path", ["/docs", "/redoc", "/openapi.json"])
def test_documentation_fermee_en_production(
    make_client: Callable[..., TestClient], path: str
) -> None:
    production = make_client(env="prod")
    assert production.get(path).status_code == 404


def test_documentation_ouverte_en_dev(make_client: Callable[..., TestClient]) -> None:
    dev = make_client(env="dev")
    assert dev.get("/docs").status_code == 200
    assert dev.get("/openapi.json").status_code == 200


def test_production_par_defaut(make_client: Callable[..., TestClient]) -> None:
    # Sans SENTINEL_ENV, la documentation est fermée.
    assert make_client().get("/openapi.json").status_code == 404


def test_route_inconnue(client: TestClient) -> None:
    assert client.get("/v2/reports").status_code == 404
    assert client.get("/v1/reports").status_code == 405
