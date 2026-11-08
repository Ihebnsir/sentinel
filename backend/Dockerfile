# Image du backend Sentinel : deux étapes, utilisateur non-root.
# Image de base épinglée par version ET par empreinte (digest).
ARG PYTHON_IMAGE=python:3.14.8-slim-trixie@sha256:fbecd461fc72d21b2143c6eaba25143738079154a6d0ea3da3aec724f50eed4a

# --- Étape 1 : dépendances dans un venv -----------------------------------
FROM ${PYTHON_IMAGE} AS build
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
RUN python -m venv /opt/venv
COPY requirements.txt /tmp/requirements.txt
# --no-deps : uniquement les versions épinglées, rien d'autre.
RUN /opt/venv/bin/pip install --no-deps -r /tmp/requirements.txt

# --- Étape 2 : image finale, sans outils de build -------------------------
FROM ${PYTHON_IMAGE}
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/opt/venv/bin:$PATH \
    SENTINEL_ENV=prod \
    SENTINEL_HOST=0.0.0.0 \
    SENTINEL_PORT=8000 \
    SENTINEL_DATABASE_URL=sqlite:////data/sentinel.db

RUN groupadd --system --gid 10001 sentinel \
    && useradd --system --uid 10001 --gid sentinel --no-create-home --shell /usr/sbin/nologin sentinel \
    && mkdir /data && chown sentinel:sentinel /data

WORKDIR /srv
COPY --from=build /opt/venv /opt/venv
COPY alembic.ini ./
COPY migrations ./migrations
COPY app ./app

USER sentinel
VOLUME ["/data"]
EXPOSE 8000

# Pas de curl dans l'image : la vérification utilise Python.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/v1/health', timeout=2).status == 200 else 1)"]

# Migrations (alembic upgrade head), puis serveur.
CMD ["python", "-m", "app"]
