"""API de signalements volontaires de messages d'arnaque.

Seule route utile : POST /v1/reports. Le texte est anonymisé avant d'être
écrit ; ni adresse IP, ni identifiant d'appareil, ni heure précise ne sont
stockés. Aucun journal des requêtes (voir README).
"""

import datetime as dt

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.orm import sessionmaker
from starlette.middleware.cors import CORSMiddleware

from .anonymize import ANONYMIZER_VERSION, anonymize
from .config import Settings
from .db import make_engine
from .middleware import (
    BodySizeLimitMiddleware,
    RateLimitMiddleware,
    SecurityHeadersMiddleware,
)
from .models import Report
from .ratelimit import RateLimiter
from .schemas import ReportAccepted, ReportIn


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings.from_env()
    dev = settings.is_development
    app = FastAPI(
        title="Sentinel – signalements",
        # Documentation interactive seulement en développement.
        docs_url="/docs" if dev else None,
        redoc_url=None,
        openapi_url="/openapi.json" if dev else None,
    )
    engine = make_engine(settings.database_url)
    sessions = sessionmaker(engine)
    limiter = RateLimiter(
        settings.rate_limit,
        settings.rate_window_seconds,
        settings.rate_max_clients,
    )
    app.state.engine = engine
    app.state.limiter = limiter

    # Le dernier ajouté enveloppe les autres : en-têtes partout, puis CORS,
    # limite de débit (avant de lire le corps), taille du corps.
    app.add_middleware(BodySizeLimitMiddleware, max_bytes=settings.max_body_bytes)
    app.add_middleware(RateLimitMiddleware, limiter=limiter)
    # CORS fermé : aucune origine web autorisée (l'app mobile n'en a pas besoin).
    app.add_middleware(CORSMiddleware, allow_origins=[], allow_methods=[])
    app.add_middleware(SecurityHeadersMiddleware)

    @app.exception_handler(RequestValidationError)
    async def invalid_report(request: Request, exc: RequestValidationError) -> JSONResponse:
        # Sans renvoyer les valeurs reçues (elles peuvent contenir le texte).
        errors = [
            {"champ": ".".join(str(p) for p in e["loc"]), "type": e["type"]}
            for e in exc.errors()
        ]
        return JSONResponse(status_code=422, content={"detail": errors})

    @app.post("/v1/reports", status_code=201, response_model=ReportAccepted)
    def create_report(report: ReportIn) -> ReportAccepted:
        with sessions.begin() as session:
            session.add(
                Report(
                    text=anonymize(report.text),
                    verdict=report.verdict,
                    language=report.language,
                    app_version=report.app_version,
                    received_on=dt.datetime.now(dt.UTC).date(),
                    anonymizer_version=ANONYMIZER_VERSION,
                )
            )
        return ReportAccepted()

    @app.get("/v1/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    return app
