"""Revue des signalements, en ligne de commande (pas de page web d'admin).

Usage (depuis backend/, avec l'URL du rôle « revue » dans DATABASE_URL) :
    python -m tools.review            # revue des « nouveau », un par un
    python -m tools.review export     # confirmés → ml/data/messages_perso.csv

Touches : a = arnaque confirmée, p = pas une arnaque, r = rejeté (inutile,
spam, données perso), s = passer, q = quitter.
Chaque décision est enregistrée tout de suite : on peut quitter à tout moment.
"""

import argparse
import csv
import datetime
import sys
from collections.abc import Callable
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Report, ReviewStatus

from ._db import ToolError, fail, sessions

REPO_DIR = Path(__file__).resolve().parents[2]
DEFAULT_CSV = REPO_DIR / "ml" / "data" / "messages_perso.csv"
CSV_COLUMNS = ["text", "label", "langue", "source"]
SOURCE = "reel"

CHOICES = {
    "a": ReviewStatus.arnaque_confirmee,
    "p": ReviewStatus.pas_arnaque,
    "r": ReviewStatus.rejete,
}
LABELS = {ReviewStatus.arnaque_confirmee: "1", ReviewStatus.pas_arnaque: "0"}
PROMPT = "[a] arnaque  [p] pas une arnaque  [r] rejeter  [s] passer  [q] quitter > "


def pending(session: Session) -> list[Report]:
    """Les « nouveau », les plus signalés d'abord, puis les plus anciens."""
    query = (
        select(Report)
        .where(Report.review_status == ReviewStatus.nouveau)
        .order_by(Report.count.desc(), Report.received_on, Report.id)
    )
    return list(session.scalars(query))


def describe(report: Report, index: int, total: int) -> str:
    feedback = report.user_feedback.value if report.user_feedback else "non donné"
    return "\n".join(
        [
            "",
            f"─── {index}/{total} ── reçu le {report.received_on} ── {report.count} fois",
            report.text,
            f"verdict de l'app : {report.verdict.value} ({report.probability:.0%})",
            f"avis de l'utilisateur : {feedback} ── langue : {report.language.value}",
        ]
    )


def review(
    session: Session,
    ask: Callable[[str], str] = input,
    out: Callable[[str], None] = print,
) -> dict[str, int]:
    """Boucle de revue ; renvoie le nombre de décisions par touche."""
    reports = pending(session)
    done = {key: 0 for key in (*CHOICES, "s")}
    if not reports:
        out("Aucun signalement à revoir.")
        return done
    for index, report in enumerate(reports, start=1):
        out(describe(report, index, len(reports)))
        while True:
            try:
                key = ask(PROMPT).strip().lower()
            except EOFError:  # fin de l'entrée (Ctrl+Z / Ctrl+D)
                key = "q"
            if key in CHOICES or key in ("s", "q"):
                break
            out("Touche inconnue.")
        if key == "q":
            break
        if key in CHOICES:
            report.review_status = CHOICES[key]
            session.commit()  # décision enregistrée tout de suite
        done[key] += 1
    out(
        f"Fini : {done['a']} arnaques, {done['p']} pas des arnaques, "
        f"{done['r']} rejetés, {done['s']} passés."
    )
    return done


def _existing_texts(path: Path) -> set[str]:
    if not path.exists():
        return set()
    with path.open(encoding="utf-8", newline="") as file:
        return {row["text"] for row in csv.DictReader(file)}


def export(session: Session, path: Path, today: datetime.date) -> int:
    """Ajoute les confirmés au CSV (format de ml/train.py), sans doublon ni
    écrasement. Marque exported_on. Renvoie le nombre de lignes ajoutées."""
    query = (
        select(Report)
        .where(Report.review_status.in_(list(LABELS)))
        .order_by(Report.received_on, Report.id)
    )
    reports = list(session.scalars(query))
    known = _existing_texts(path)
    new_rows = []
    for report in reports:
        if report.text not in known:
            known.add(report.text)
            new_rows.append(
                {
                    "text": report.text,
                    "label": LABELS[report.review_status],
                    "langue": report.language.value,
                    "source": SOURCE,
                }
            )
        if report.exported_on is None:
            report.exported_on = today
    write_header = not path.exists() or path.stat().st_size == 0
    if new_rows or write_header:
        path.parent.mkdir(parents=True, exist_ok=True)
        # Le fichier finit-il par un retour à la ligne ? Sinon, on en ajoute un.
        needs_newline = not write_header and not path.read_bytes().endswith(b"\n")
        with path.open("a", encoding="utf-8", newline="") as file:
            if needs_newline:
                file.write("\r\n")
            writer = csv.DictWriter(file, fieldnames=CSV_COLUMNS, lineterminator="\r\n")
            if write_header:
                writer.writeheader()
            writer.writerows(new_rows)
    # Après l'écriture : si elle échoue, rien n'est marqué comme exporté.
    session.commit()
    return len(new_rows)


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Revue des signalements Sentinel")
    parser.add_argument("action", nargs="?", choices=["review", "export"], default="review")
    parser.add_argument("--database-url", help="sinon DATABASE_URL (rôle revue)")
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV, help="fichier d'export")
    args = parser.parse_args(argv)
    # Textes en arabe : la console Windows doit écrire en UTF-8.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    try:
        with sessions(args.database_url)() as session:
            if args.action == "export":
                today = datetime.datetime.now(datetime.UTC).date()
                added = export(session, args.csv, today)
                print(f"{added} ligne(s) ajoutée(s) à {args.csv}")
            else:
                review(session)
    except ToolError as error:
        fail(error)


if __name__ == "__main__":
    main()
