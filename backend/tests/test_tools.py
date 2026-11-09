"""Outils : rétention et revue (touches simulées), export CSV pour ml/train.py."""

import csv
import datetime as dt
import uuid
from collections.abc import Iterator
from pathlib import Path

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session, sessionmaker

from app.__main__ import migrate
from app.db import make_sessionmaker
from app.models import Language, Report, ReviewStatus, Source, UserFeedback, Verdict
from tools import retention, review
from tools._db import ToolError, database_url

TODAY = dt.date(2026, 11, 9)


@pytest.fixture
def sessions(db_url: str) -> Iterator[sessionmaker[Session]]:
    migrate(db_url)
    maker = make_sessionmaker(db_url)
    yield maker
    maker.kw["bind"].dispose()


def add(
    maker: sessionmaker[Session],
    text: str,
    status: ReviewStatus = ReviewStatus.nouveau,
    days_ago: int = 0,
    count: int = 1,
    exported: bool = False,
    language: Language = Language.fr,
) -> None:
    with maker() as session:
        session.add(
            Report(
                id=uuid.uuid4(),
                text=text,
                verdict=Verdict.arnaque,
                probability=0.9,
                language=language,
                source=Source.inconnue,
                app_version="1.0.0",
                user_feedback=UserFeedback.arnaque,
                received_on=TODAY - dt.timedelta(days=days_ago),
                review_status=status,
                anonymizer_version=1,
                fingerprint=uuid.uuid4().hex,
                count=count,
                exported_on=TODAY if exported else None,
            )
        )
        session.commit()


def texts(maker: sessionmaker[Session]) -> dict[str, ReviewStatus]:
    with maker() as session:
        return {r.text: r.review_status for r in session.scalars(select(Report))}


# --- Rétention ---------------------------------------------------------------


def test_retention(sessions: sessionmaker[Session]) -> None:
    add(sessions, "rejete-vieux", ReviewStatus.rejete, days_ago=200)
    add(sessions, "rejete-recent", ReviewStatus.rejete, days_ago=100)
    add(sessions, "pas-arnaque-vieux", ReviewStatus.pas_arnaque, days_ago=200)
    add(sessions, "pas-arnaque-exporte", ReviewStatus.pas_arnaque, days_ago=200, exported=True)
    add(sessions, "nouveau-tres-vieux", ReviewStatus.nouveau, days_ago=400)
    add(sessions, "nouveau-vieux", ReviewStatus.nouveau, days_ago=200)
    add(sessions, "arnaque-tres-vieille", ReviewStatus.arnaque_confirmee, days_ago=900)

    with sessions() as session:
        dry = retention.purge(session, TODAY, dry_run=True)
    assert (dry.unused, dry.never_reviewed) == (2, 1)
    assert len(texts(sessions)) == 7  # simulation : rien supprimé

    with sessions() as session:
        done = retention.purge(session, TODAY)
    assert done == dry
    assert set(texts(sessions)) == {
        "rejete-recent",
        "pas-arnaque-exporte",  # utilisé pour l'entraînement
        "nouveau-vieux",
        "arnaque-tres-vieille",
    }


def test_retention_durees_configurables(sessions: sessionmaker[Session]) -> None:
    add(sessions, "rejete-10j", ReviewStatus.rejete, days_ago=10)
    add(sessions, "nouveau-10j", ReviewStatus.nouveau, days_ago=10)
    with sessions() as session:
        result = retention.purge(session, TODAY, rejected_days=5, new_days=30)
    assert (result.unused, result.never_reviewed) == (1, 0)
    with sessions() as session, pytest.raises(ToolError):
        retention.purge(session, TODAY, rejected_days=0)


def test_retention_ligne_de_commande(
    sessions: sessionmaker[Session], db_url: str, capsys: pytest.CaptureFixture[str]
) -> None:
    add(sessions, "vieux", ReviewStatus.rejete, days_ago=3000)
    retention.main(["--database-url", db_url, "--dry-run"])
    assert "1 rejetés" in capsys.readouterr().out
    retention.main(["--database-url", db_url])
    assert texts(sessions) == {}


def test_outils_refusent_postgres_sans_tls(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.delenv("SENTINEL_DATABASE_URL", raising=False)
    with pytest.raises(ToolError, match="DATABASE_URL"):
        database_url(None)
    with pytest.raises(ToolError, match="TLS") as error:
        database_url("postgresql://revue:secret123@h/db")
    assert "secret123" not in str(error.value)
    assert database_url("postgresql://r:p@h/db?sslmode=require").endswith("require")


# --- Revue -------------------------------------------------------------------


def scripted(keys: list[str]):
    answers = iter(keys)

    def ask(_prompt: str) -> str:
        try:
            return next(answers)
        except StopIteration:
            raise EOFError from None

    return ask


def test_revue_touches(sessions: sessionmaker[Session]) -> None:
    add(sessions, "souvent", count=9)
    add(sessions, "deux")
    add(sessions, "trois")
    add(sessions, "quatre")
    shown: list[str] = []
    with sessions() as session:
        # « x » : touche inconnue, redemandée.
        done = review.review(session, scripted(["a", "x", "p", "r", "s"]), shown.append)
    assert done == {"a": 1, "p": 1, "r": 1, "s": 1}
    statuses = texts(sessions)
    # Le plus signalé passe en premier.
    assert statuses["souvent"] == ReviewStatus.arnaque_confirmee
    assert sorted(s.value for t, s in statuses.items() if t != "souvent") == [
        "nouveau",
        "pas_arnaque",
        "rejete",
    ]
    screen = "\n".join(shown)
    assert "souvent" in screen and "9 fois" in screen
    assert "avis de l'utilisateur : arnaque" in screen
    assert "Touche inconnue" in screen


def test_revue_quitter_garde_les_decisions(sessions: sessionmaker[Session]) -> None:
    add(sessions, "un", count=2)
    add(sessions, "deux")
    with sessions() as session:
        review.review(session, scripted(["a", "q"]), lambda _: None)
    assert texts(sessions) == {
        "un": ReviewStatus.arnaque_confirmee,
        "deux": ReviewStatus.nouveau,
    }


def test_revue_vide(sessions: sessionmaker[Session]) -> None:
    shown: list[str] = []
    with sessions() as session:
        review.review(session, scripted([]), shown.append)
    assert shown == ["Aucun signalement à revoir."]


# --- Export ------------------------------------------------------------------


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as file:
        return list(csv.DictReader(file))


def test_export_sans_doublon_ni_ecrasement(sessions: sessionmaker[Session], tmp_path: Path) -> None:
    path = tmp_path / "messages_perso.csv"
    # Fichier existant (format de ml/train.py), une ligne déjà là.
    path.write_bytes(
        "text,label,langue,source\r\nDéjà là,1,fr,perso\r\nArnaque [TEL],1,fr,perso\r\n".encode()
    )
    add(sessions, "Arnaque [TEL]", ReviewStatus.arnaque_confirmee)  # déjà dans le CSV
    add(sessions, 'Vrai message, avec "guillemets"', ReviewStatus.pas_arnaque)
    add(sessions, "رسالة احتيال [CODE]", ReviewStatus.arnaque_confirmee, language=Language.ar)
    add(sessions, "Rejeté", ReviewStatus.rejete)
    add(sessions, "Pas revu", ReviewStatus.nouveau)

    with sessions() as session:
        assert review.export(session, path, TODAY) == 2
    lines = read_csv(path)
    assert lines[:2] == [
        {"text": "Déjà là", "label": "1", "langue": "fr", "source": "perso"},
        {"text": "Arnaque [TEL]", "label": "1", "langue": "fr", "source": "perso"},
    ]
    # Ordre des nouvelles lignes : jour de réception (puis identifiant).
    assert sorted(lines[2:], key=lambda r: r["label"]) == [
        {"text": 'Vrai message, avec "guillemets"', "label": "0", "langue": "fr", "source": "reel"},
        {"text": "رسالة احتيال [CODE]", "label": "1", "langue": "ar", "source": "reel"},
    ]
    assert b"\r\n" in path.read_bytes() and b"\n\n" not in path.read_bytes()

    # Les confirmés sont marqués « exportés » (gardés par la rétention).
    with sessions() as session:
        exported = {r.text: r.exported_on for r in session.scalars(select(Report))}
    assert exported["Arnaque [TEL]"] == TODAY
    assert exported["Rejeté"] is None and exported["Pas revu"] is None

    # Deuxième export : rien de nouveau.
    with sessions() as session:
        assert review.export(session, path, TODAY) == 0
    assert len(read_csv(path)) == 4


def test_export_fichier_absent_ou_sans_retour_final(
    sessions: sessionmaker[Session], tmp_path: Path
) -> None:
    add(sessions, "Arnaque", ReviewStatus.arnaque_confirmee)
    fresh = tmp_path / "neuf" / "messages_perso.csv"
    with sessions() as session:
        review.export(session, fresh, TODAY)
    assert read_csv(fresh) == [{"text": "Arnaque", "label": "1", "langue": "fr", "source": "reel"}]

    no_newline = tmp_path / "sans_retour.csv"
    no_newline.write_bytes(b"text,label,langue,source\r\nA,0,fr,perso")
    with sessions() as session:
        review.export(session, no_newline, TODAY)
    assert [r["text"] for r in read_csv(no_newline)] == ["A", "Arnaque"]


def test_export_au_format_de_train_py(sessions: sessionmaker[Session], tmp_path: Path) -> None:
    train = (review.REPO_DIR / "ml" / "train.py").read_text(encoding="utf-8")
    assert 'REQUIRED_COLUMNS = ["text", "label", "langue", "source"]' in train
    assert review.CSV_COLUMNS == ["text", "label", "langue", "source"]
    assert review.DEFAULT_CSV == review.REPO_DIR / "ml" / "data" / "messages_perso.csv"
