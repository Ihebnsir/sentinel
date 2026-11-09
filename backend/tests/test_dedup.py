"""Anti-spam : doublons comptés (une ligne + compteur) et limite globale."""

import datetime as dt
import hashlib
from collections.abc import Callable
from typing import Any

from fastapi.testclient import TestClient

from app.fingerprint import fingerprint, normalize

from .conftest import FINGERPRINT_KEY, valid_report

Rows = Callable[[], list[dict[str, Any]]]


def _send(client: TestClient, text: str, **changes: object) -> Any:
    return client.post("/v1/reports", json=valid_report(text=text, **changes))


def test_meme_texte_une_ligne_et_un_compteur(client: TestClient, rows: Rows) -> None:
    first = _send(client, "Colis bloqué : poste-tn.xyz/a")
    second = _send(client, "Colis bloqué : poste-tn.xyz/a", user_feedback="arnaque")
    assert first.status_code == second.status_code == 201
    # Même identifiant : c'est le même signalement.
    assert first.json() == second.json()
    (row,) = rows()
    assert row["count"] == 2


def test_normalisation_majuscules_espaces(client: TestClient, rows: Rows) -> None:
    _send(client, "Votre COLIS est bloqué")
    _send(client, "  votre   colis\nest bloqué ")
    (row,) = rows()
    assert row["count"] == 2


def test_meme_texte_apres_anonymisation(client: TestClient, rows: Rows) -> None:
    # Seul le numéro change : après anonymisation, c'est le même message.
    _send(client, "Appelez le 98 123 456 pour votre colis")
    _send(client, "Appelez le 22 333 444 pour votre colis")
    (row,) = rows()
    assert row["count"] == 2
    assert row["text"] == "Appelez le [TEL] pour votre colis"


def test_textes_differents_deux_lignes(client: TestClient, rows: Rows) -> None:
    _send(client, "Message un")
    _send(client, "Message deux")
    assert sorted(r["count"] for r in rows()) == [1, 1]


def test_empreinte_salee(client: TestClient, rows: Rows) -> None:
    _send(client, "Texte à empreinte")
    (row,) = rows()
    plain = hashlib.sha256(normalize("Texte à empreinte").encode()).hexdigest()
    assert row["fingerprint"] != plain  # pas un simple SHA-256 du texte
    assert row["fingerprint"] == fingerprint("Texte à empreinte", FINGERPRINT_KEY.encode())
    assert fingerprint("x", b"cle-a") != fingerprint("x", b"cle-b")


def test_limite_globale(make_client: Callable[..., TestClient], rows: Rows) -> None:
    client = make_client(global_daily_limit=2, rate_limit_per_window=100)
    assert _send(client, "Un").status_code == 201
    assert _send(client, "Deux").status_code == 201
    third = _send(client, "Trois")
    assert third.status_code == 429
    # Réessayer demain (au plus 24 h).
    assert 1 <= int(third.headers["Retry-After"]) <= 86_400
    assert len(rows()) == 2


def test_limite_globale_compte_seulement_aujourd_hui(
    make_client: Callable[..., TestClient], sql: Callable[..., Any]
) -> None:
    client = make_client(global_daily_limit=1, rate_limit_per_window=100)
    assert _send(client, "Hier").status_code == 201
    yesterday = dt.datetime.now(dt.UTC).date() - dt.timedelta(days=1)
    # Texte ISO : accepté par SQLite et PostgreSQL (colonne DATE).
    sql("UPDATE reports SET received_on = :d", {"d": yesterday.isoformat()})
    assert _send(client, "Aujourd'hui").status_code == 201
