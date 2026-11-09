"""Rétention : supprime les signalements devenus inutiles.

- « rejete » et « pas_arnaque » jamais exportés (exported_on vide), reçus il y
  a plus de 183 jours (6 mois) ;
- « nouveau » jamais revus, reçus il y a plus de 365 jours (12 mois).
Les « arnaque_confirmee » et les « pas_arnaque » exportés vers ml/data sont
gardés (ils servent à l'entraînement).

Usage (depuis backend/, rôle « revue ») :
    python -m tools.retention --dry-run   # compte seulement
    python -m tools.retention             # supprime
Durées : --rejected-days / --new-days, ou SENTINEL_RETENTION_REJECTED_DAYS /
SENTINEL_RETENTION_NEW_DAYS.
"""

import argparse
import datetime
import os
from dataclasses import dataclass

from sqlalchemy import and_, delete, func, or_, select
from sqlalchemy.orm import Session

from app.models import Report, ReviewStatus

from ._db import ToolError, fail, sessions

DEFAULT_REJECTED_DAYS = 183
DEFAULT_NEW_DAYS = 365


@dataclass(frozen=True)
class Purge:
    unused: int  # rejetés ou pas_arnaque non utilisés
    never_reviewed: int  # nouveaux jamais revus

    @property
    def total(self) -> int:
        return self.unused + self.never_reviewed


def _conditions(today: datetime.date, rejected_days: int, new_days: int):
    unused = and_(
        Report.review_status.in_([ReviewStatus.rejete, ReviewStatus.pas_arnaque]),
        Report.exported_on.is_(None),
        Report.received_on < today - datetime.timedelta(days=rejected_days),
    )
    never_reviewed = and_(
        Report.review_status == ReviewStatus.nouveau,
        Report.received_on < today - datetime.timedelta(days=new_days),
    )
    return unused, never_reviewed


def purge(
    session: Session,
    today: datetime.date,
    rejected_days: int = DEFAULT_REJECTED_DAYS,
    new_days: int = DEFAULT_NEW_DAYS,
    dry_run: bool = False,
) -> Purge:
    if rejected_days < 1 or new_days < 1:
        raise ToolError("les durées doivent être d'au moins 1 jour")
    unused, never_reviewed = _conditions(today, rejected_days, new_days)

    def count(condition) -> int:
        return session.scalar(select(func.count()).select_from(Report).where(condition)) or 0

    result = Purge(count(unused), count(never_reviewed))
    if not dry_run and result.total:
        session.execute(delete(Report).where(or_(unused, never_reviewed)))
        session.commit()
    return result


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Rétention des signalements")
    parser.add_argument("--database-url", help="sinon DATABASE_URL")
    parser.add_argument(
        "--rejected-days",
        type=int,
        default=int(os.environ.get("SENTINEL_RETENTION_REJECTED_DAYS", DEFAULT_REJECTED_DAYS)),
    )
    parser.add_argument(
        "--new-days",
        type=int,
        default=int(os.environ.get("SENTINEL_RETENTION_NEW_DAYS", DEFAULT_NEW_DAYS)),
    )
    parser.add_argument("--dry-run", action="store_true", help="compter sans supprimer")
    args = parser.parse_args(argv)
    try:
        with sessions(args.database_url)() as session:
            today = datetime.datetime.now(datetime.UTC).date()
            result = purge(session, today, args.rejected_days, args.new_days, args.dry_run)
    except ToolError as error:
        fail(error)
        return
    verb = "à supprimer" if args.dry_run else "supprimés"
    print(
        f"{result.unused} rejetés / pas_arnaque non utilisés {verb} ; "
        f"{result.never_reviewed} jamais revus {verb}."
    )


if __name__ == "__main__":
    main()
