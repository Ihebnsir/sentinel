"""Middleware ASGI : taille maximale, en-têtes de sécurité, erreurs et journal
d'accès SANS adresse IP ni contenu."""

import json
import logging
import time

from starlette.types import ASGIApp, Message, Receive, Scope, Send

access_log = logging.getLogger("sentinel.access")
error_log = logging.getLogger("sentinel.error")

_STRICT_CSP = "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"
# /docs (mode dev seulement) charge Swagger UI depuis un CDN.
_DOCS_CSP = (
    "default-src 'none'; script-src https://cdn.jsdelivr.net 'unsafe-inline'; "
    "style-src https://cdn.jsdelivr.net 'unsafe-inline'; "
    "img-src https://fastapi.tiangolo.com data:; connect-src 'self'; frame-ancestors 'none'"
)
_DOCS_PATHS = ("/docs", "/docs/oauth2-redirect", "/openapi.json")


def _security_headers(path: str, docs_enabled: bool) -> list[tuple[bytes, bytes]]:
    csp = _DOCS_CSP if docs_enabled and path in _DOCS_PATHS else _STRICT_CSP
    return [
        (b"x-content-type-options", b"nosniff"),
        (b"x-frame-options", b"DENY"),
        (b"referrer-policy", b"no-referrer"),
        (b"content-security-policy", csp.encode()),
        (b"cross-origin-resource-policy", b"same-origin"),
        (b"cross-origin-opener-policy", b"same-origin"),
        (b"permissions-policy", b"camera=(), microphone=(), geolocation=()"),
        (b"cache-control", b"no-store"),
        # HSTS : le navigateur n'utilise plus que HTTPS pendant 2 ans
        # (ignoré en HTTP simple, donc sans effet en local).
        (b"strict-transport-security", b"max-age=63072000; includeSubDomains"),
    ]


async def _send_json(send: Send, status: int, body: dict) -> None:
    payload = json.dumps(body).encode()
    await send(
        {
            "type": "http.response.start",
            "status": status,
            "headers": [
                (b"content-type", b"application/json"),
                (b"content-length", str(len(payload)).encode()),
            ],
        }
    )
    await send({"type": "http.response.body", "body": payload})


class SecurityMiddleware:
    def __init__(
        self,
        app: ASGIApp,
        max_body_bytes: int,
        docs_enabled: bool,
        require_https: bool = False,
    ) -> None:
        self.app = app
        self.max_body_bytes = max_body_bytes
        self.docs_enabled = docs_enabled
        self.require_https = require_https

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        start = time.perf_counter()
        path: str = scope["path"]
        status_holder = {"status": 0, "started": False}
        extra_headers = _security_headers(path, self.docs_enabled)

        async def send_wrapper(message: Message) -> None:
            if message["type"] == "http.response.start":
                status_holder["status"] = message["status"]
                status_holder["started"] = True
                headers = [(k, v) for k, v in message.get("headers", []) if k.lower() != b"server"]
                message = {**message, "headers": headers + extra_headers}
            await send(message)

        try:
            if self.require_https and _plain_http(scope):
                # L'hébergeur redirige déjà HTTP vers HTTPS ; second filet.
                # Pas de redirection : un POST redirigé renverrait le texte
                # en clair une seconde fois.
                await _send_json(send_wrapper, 400, {"detail": "HTTPS obligatoire"})
                return
            body = await self._read_body(scope, receive)
            if body is None:
                await _send_json(send_wrapper, 413, {"detail": "requête trop grande"})
                return
            await self.app(scope, _replay(body, receive), send_wrapper)
        except Exception as exc:  # dernier filet, sans détail
            # Seulement le type : le message pourrait contenir le texte reçu.
            error_log.error("erreur interne: %s", type(exc).__name__)
            if not status_holder["started"]:
                await _send_json(send_wrapper, 500, {"detail": "erreur interne"})
        finally:
            # Ni IP, ni paramètres de l'URL, ni contenu.
            access_log.info(
                "%s %s %s %.0fms",
                scope["method"],
                path[:64],
                status_holder["status"],
                (time.perf_counter() - start) * 1000,
            )

    async def _read_body(self, scope: Scope, receive: Receive) -> bytes | None:
        """Corps complet, ou None s'il dépasse la limite (annoncée ou réelle)."""
        for name, value in scope.get("headers", []):
            if name == b"content-length":
                try:
                    if int(value) > self.max_body_bytes:
                        return None
                except ValueError:
                    return None
        chunks: list[bytes] = []
        size = 0
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                break
            chunk = message.get("body", b"")
            size += len(chunk)
            if size > self.max_body_bytes:
                return None
            chunks.append(chunk)
            if not message.get("more_body", False):
                break
        return b"".join(chunks)


def _plain_http(scope: Scope) -> bool:
    """True si le proxy de confiance signale une requête reçue en HTTP.
    Sans l'en-tête (contrôle de santé interne de l'hébergeur) : accepté."""
    for name, value in scope.get("headers", []):
        if name == b"x-forwarded-proto":
            # Dernière valeur : celle ajoutée par le proxy le plus proche.
            return value.decode("latin-1").split(",")[-1].strip().lower() != "https"
    return False


def _replay(body: bytes, original: Receive) -> Receive:
    """Rejoue le corps déjà lu, puis rend la main au vrai canal."""
    sent = False

    async def receive() -> Message:
        nonlocal sent
        if not sent:
            sent = True
            return {"type": "http.request", "body": body, "more_body": False}
        return await original()

    return receive
