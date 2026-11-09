"""Application FastAPI : santé et réception des signalements (/v1)."""

import datetime
import logging
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy import func, select
from sqlalchemy.dialects import postgresql, sqlite
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session
from starlette.exceptions import HTTPException as StarletteHTTPException

from .anonymize import ANONYMIZER_VERSION, anonymize
from .client_ip import client_ip
from .config import Settings, get_settings
from .db import get_session, make_sessionmaker
from .fingerprint import fingerprint
from .middleware import SecurityMiddleware
from .models import Report, ReviewStatus
from .rate_limit import RateLimiter
from .schemas import Health, ReportCreated, ReportIn

log = logging.getLogger("sentinel.reports")

v1 = APIRouter(prefix="/v1")


@v1.get("/health", response_model=Health)
def health() -> Health:
    # Aucune information interne (version, base, machine).
    return Health(status="ok")


@v1.post(
    "/reports",
    status_code=status.HTTP_201_CREATED,
    response_model=ReportCreated,
    responses={413: {}, 422: {}, 429: {}},
)
def create_report(
    report: ReportIn, request: Request, session: Annotated[Session, Depends(get_session)]
) -> ReportCreated | JSONResponse:
    settings: Settings = request.app.state.settings
    limiter: RateLimiter = request.app.state.rate_limiter
    # L'adresse ne sert qu'ici, en mémoire, sous forme d'empreinte salée.
    decision = limiter.hit(client_ip(request, settings))
    if not decision.allowed:
        return _too_many(decision.retry_after)

    text = anonymize(report.text)  # AVANT tout stockage
    now = datetime.datetime.now(datetime.UTC)
    today = now.date()
    try:
        # Limite globale : nouvelles lignes du jour (les doublons n'en créent pas).
        received_today = session.scalar(
            select(func.count()).select_from(Report).where(Report.received_on == today)
        )
        if (received_today or 0) >= settings.global_daily_limit:
            log.warning("limite globale du jour atteinte")
            tomorrow = datetime.datetime.combine(
                today + datetime.timedelta(days=1), datetime.time(), datetime.UTC
            )
            return _too_many(max(1, int((tomorrow - now).total_seconds())))

        values = {
            "id": uuid.uuid4(),
            "text": text,
            "verdict": report.verdict,
            "probability": report.probability,
            "language": report.language,
            "source": report.source,
            "app_version": report.app_version,
            "user_feedback": report.user_feedback,
            "received_on": today,
            "review_status": ReviewStatus.nouveau,
            "anonymizer_version": ANONYMIZER_VERSION,
            "fingerprint": fingerprint(text, settings.fingerprint_secret),
            "count": 1,
        }
        # Même texte déjà reçu : une seule ligne, compteur + 1 (en une requête,
        # sans lire le texte : le rôle « app » n'en a pas le droit).
        insert = postgresql.insert if session.bind.dialect.name == "postgresql" else sqlite.insert
        statement = (
            insert(Report)
            .values(values)
            .on_conflict_do_update(
                index_elements=[Report.fingerprint],
                set_={"count": Report.count + 1},
            )
            .returning(Report.id)
        )
        report_id = session.execute(statement).scalar_one()
        session.commit()
    except SQLAlchemyError as exc:
        session.rollback()
        # Seulement le type : le message SQL contiendrait le texte.
        log.error("enregistrement impossible: %s", type(exc).__name__)
        return JSONResponse(
            {"detail": "erreur interne"}, status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
    log.info("signalement reçu")
    return ReportCreated(id=report_id)


def _too_many(retry_after: int) -> JSONResponse:
    return JSONResponse(
        {"detail": "trop de signalements, réessayez plus tard"},
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        headers={"Retry-After": str(retry_after)},
    )


async def _validation_error(_request: Request, exc: RequestValidationError) -> JSONResponse:
    # Ni « input » ni « ctx » : la réponse ne renvoie pas le texte reçu.
    errors = [
        {"loc": list(e.get("loc", ())), "type": e.get("type", ""), "msg": e.get("msg", "")}
        for e in exc.errors()
    ]
    return JSONResponse({"detail": errors}, status_code=status.HTTP_422_UNPROCESSABLE_CONTENT)


async def _http_error(_request: Request, exc: StarletteHTTPException) -> JSONResponse:
    return JSONResponse(
        {"detail": exc.detail}, status_code=exc.status_code, headers=getattr(exc, "headers", None)
    )


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    docs = settings.is_dev
    app = FastAPI(
        title="Sentinel API",
        version="1",
        # Documentation interactive : mode dev uniquement.
        docs_url="/docs" if docs else None,
        redoc_url=None,
        openapi_url="/openapi.json" if docs else None,
    )
    app.state.settings = settings
    app.state.sessionmaker = make_sessionmaker(settings.database_url)
    app.state.rate_limiter = RateLimiter(
        limit=settings.rate_limit_per_window,
        window_seconds=settings.rate_limit_window_seconds,
        max_keys=settings.rate_limit_max_keys,
    )
    app.include_router(v1)
    app.add_exception_handler(RequestValidationError, _validation_error)
    app.add_exception_handler(StarletteHTTPException, _http_error)
    # Pas de CORSMiddleware : aucune page web d'un autre site ne peut appeler
    # l'API depuis un navigateur. L'app mobile n'est pas concernée par CORS.
    app.add_middleware(
        SecurityMiddleware,
        max_body_bytes=settings.max_body_bytes,
        docs_enabled=docs,
        # HTTP refusé seulement si le proxy de confiance dit « http ».
        require_https=not settings.is_dev and settings.trust_proxy,
    )
    return app
