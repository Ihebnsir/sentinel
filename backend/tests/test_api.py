"""POST /v1/reports : validation stricte, limites, en-têtes, production."""

import json
from collections.abc import Callable

import pytest
from fastapi.testclient import TestClient

from tests.conftest import valid_report


def test_signalement_accepte_sans_identifiant(client: TestClient, rows: Callable) -> None:
    response = client.post("/v1/reports", json=valid_report())
    assert response.status_code == 201
    # Rien qui permette de relier l'envoi à une ligne de la base.
    assert response.json() == {"status": "recu"}
    assert len(rows()) == 1


@pytest.mark.parametrize("verdict", ["arnaque", "suspect", "rien"])
@pytest.mark.parametrize("language", ["fr", "en", "ar", "und"])
def test_valeurs_acceptees(client: TestClient, verdict: str, language: str) -> None:
    response = client.post(
        "/v1/reports", json=valid_report(verdict=verdict, language=language)
    )
    assert response.status_code == 201


@pytest.mark.parametrize("version", ["1.0.0", "12.3.45", "1.4.0+12", "999.999.999+123456"])
def test_versions_acceptees(client: TestClient, version: str) -> None:
    assert client.post("/v1/reports", json=valid_report(app_version=version)).status_code == 201


def test_texte_de_2000_caracteres_accepte(client: TestClient) -> None:
    assert client.post("/v1/reports", json=valid_report(text="a" * 2000)).status_code == 201


@pytest.mark.parametrize(
    "changes",
    [
        {"text": ""},
        {"text": "a" * 2001},
        {"text": 123},
        {"text": None},
        {"verdict": "ARNAQUE"},
        {"verdict": "peut-etre"},
        {"verdict": 1},
        {"language": "de"},
        {"language": "FR"},
        {"app_version": "1.0"},
        {"app_version": "v1.0.0"},
        {"app_version": "1.0.0-beta"},
        {"app_version": "1.0.0+12; DROP TABLE reports"},
        {"app_version": 100},
        # Champs en plus refusés : impossible d'envoyer un identifiant.
        {"device_id": "abc-123"},
        {"ip": "1.2.3.4"},
        {"user_id": 42},
    ],
)
def test_signalement_invalide_refuse(
    client: TestClient, rows: Callable, changes: dict[str, object]
) -> None:
    response = client.post("/v1/reports", json=valid_report(**changes))
    assert response.status_code == 422
    assert rows() == []


@pytest.mark.parametrize("missing", ["text", "verdict", "language", "app_version"])
def test_champ_manquant(client: TestClient, missing: str) -> None:
    report = valid_report()
    del report[missing]
    assert client.post("/v1/reports", json=report).status_code == 422


def test_erreur_ne_renvoie_pas_le_texte(client: TestClient) -> None:
    secret = "Mon numéro 22123456 " + "x" * 2000
    response = client.post("/v1/reports", json=valid_report(text=secret))
    assert response.status_code == 422
    assert "22123456" not in response.text
    assert response.json()["detail"][0]["champ"] == "body.text"


@pytest.mark.parametrize(
    "body",
    [b"pas du json", b"[]", b'"texte"', b"null", b'{"text": "a"'],
)
def test_corps_illisible(client: TestClient, body: bytes) -> None:
    response = client.post(
        "/v1/reports", content=body, headers={"content-type": "application/json"}
    )
    assert response.status_code == 422


def test_mauvais_type_de_contenu(client: TestClient) -> None:
    response = client.post(
        "/v1/reports",
        content=json.dumps(valid_report()),
        headers={"content-type": "text/plain"},
    )
    assert response.status_code == 422


def test_corps_trop_gros_annonce(client: TestClient, rows: Callable) -> None:
    big = json.dumps(valid_report(text="a" * 20_000))
    response = client.post(
        "/v1/reports", content=big, headers={"content-type": "application/json"}
    )
    assert response.status_code == 413
    assert rows() == []


def test_corps_trop_gros_par_morceaux(client: TestClient, rows: Callable) -> None:
    # Sans Content-Length : envoi par morceaux, compté pendant la lecture.
    def chunks():
        yield b'{"text": "'
        for _ in range(20):
            yield b"a" * 1000
        yield b'", "verdict": "arnaque", "language": "fr", "app_version": "1.0.0"}'

    response = client.post(
        "/v1/reports", content=chunks(), headers={"content-type": "application/json"}
    )
    assert response.status_code == 413
    assert rows() == []


def test_content_length_invalide(client: TestClient) -> None:
    response = client.post(
        "/v1/reports",
        content=b"{}",
        headers={"content-type": "application/json", "content-length": "abc"},
    )
    assert response.status_code in (400, 413)


@pytest.mark.parametrize("method", ["get", "put", "delete", "patch"])
def test_autres_methodes_refusees(client: TestClient, method: str) -> None:
    assert getattr(client, method)("/v1/reports").status_code == 405


def test_limite_de_debit(make_client: Callable[..., TestClient], rows: Callable) -> None:
    client = make_client(rate_limit=3)
    codes = [client.post("/v1/reports", json=valid_report()).status_code for _ in range(5)]
    assert codes == [201, 201, 201, 429, 429]
    assert len(rows()) == 3
    # Le contrôle de santé n'est pas compté.
    assert client.get("/v1/health").status_code == 200


def test_limite_compte_aussi_les_requetes_invalides(
    make_client: Callable[..., TestClient],
) -> None:
    client = make_client(rate_limit=2)
    client.post("/v1/reports", json={})
    client.post("/v1/reports", json={})
    assert client.post("/v1/reports", json=valid_report()).status_code == 429


def test_reponse_429_avec_retry_after(make_client: Callable[..., TestClient]) -> None:
    client = make_client(rate_limit=1)
    client.post("/v1/reports", json=valid_report())
    response = client.post("/v1/reports", json=valid_report())
    assert response.status_code == 429
    assert response.headers["retry-after"] == "60"


def test_en_tetes_de_securite(client: TestClient) -> None:
    for response in (
        client.post("/v1/reports", json=valid_report()),
        client.post("/v1/reports", json={}),
        client.get("/v1/health"),
        client.get("/existe-pas"),
    ):
        headers = response.headers
        assert headers["x-content-type-options"] == "nosniff"
        assert headers["x-frame-options"] == "DENY"
        assert headers["referrer-policy"] == "no-referrer"
        assert headers["cache-control"] == "no-store"
        assert "default-src 'none'" in headers["content-security-policy"]
        assert "server" not in headers


def test_en_tetes_aussi_sur_413(client: TestClient) -> None:
    response = client.post(
        "/v1/reports",
        content=b"a" * 20_000,
        headers={"content-type": "application/json"},
    )
    assert response.status_code == 413
    assert response.headers["x-content-type-options"] == "nosniff"


def test_cors_ferme(client: TestClient) -> None:
    # Pré-vol d'un navigateur : refusé, aucune origine autorisée.
    preflight = client.options(
        "/v1/reports",
        headers={
            "origin": "https://site-quelconque.example",
            "access-control-request-method": "POST",
        },
    )
    assert preflight.status_code == 400
    assert "access-control-allow-origin" not in preflight.headers
    response = client.post(
        "/v1/reports",
        json=valid_report(),
        headers={"origin": "https://site-quelconque.example"},
    )
    assert "access-control-allow-origin" not in response.headers


def test_pas_de_documentation_en_production(client: TestClient) -> None:
    for path in ("/docs", "/redoc", "/openapi.json"):
        assert client.get(path).status_code == 404


def test_documentation_en_developpement(make_client: Callable[..., TestClient]) -> None:
    client = make_client(environment="development")
    assert client.get("/docs").status_code == 200
    assert client.get("/openapi.json").status_code == 200
    assert client.get("/redoc").status_code == 404
