"""Application FastAPI : santé et réception des signalements (/v1)."""

import datetime
import logging
from typing import Annotated

from fastapi import APIRouter, Depends, FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session
from starlette.exceptions import HTTPException as StarletteHTTPException

from .anonymize import ANONYMIZER_VERSION, anonymize
from .config import Settings, get_settings
from .db import get_session, make_sessionmaker
from .middleware import SecurityMiddleware
from .models import Report
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
    limiter: RateLimiter = request.app.state.rate_limiter
    # L'adresse ne sert qu'ici, en mémoire, sous forme d'empreinte salée.
    client = request.client.host if request.client else "inconnu"
    decision = limiter.hit(client)
    if not decision.allowed:
        return JSONResponse(
            {"detail": "trop de signalements, réessayez plus tard"},
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            headers={"Retry-After": str(decision.retry_after)},
        )

    row = Report(
        text=anonymize(report.text),  # AVANT tout stockage
        verdict=report.verdict,
        probability=report.probability,
        language=report.language,
        source=report.source,
        app_version=report.app_version,
        received_on=datetime.datetime.now(datetime.UTC).date(),
        anonymizer_version=ANONYMIZER_VERSION,
    )
    try:
        session.add(row)
        session.commit()
    except SQLAlchemyError as exc:
        session.rollback()
        # Seulement le type : le message SQL contiendrait le texte.
        log.error("enregistrement impossible: %s", type(exc).__name__)
        return JSONResponse(
            {"detail": "erreur interne"}, status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
    log.info("signalement reçu")
    return ReportCreated(id=row.id)


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
        SecurityMiddleware, max_body_bytes=settings.max_body_bytes, docs_enabled=docs
    )
    return app
