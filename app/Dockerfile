# =============================================================================
# Image applicative, build multi-stage, exécution en utilisateur non-root.
# Tier applicatif déployé sur ECS Fargate.
# =============================================================================

# -----------------------------------------------------------------------------
# Étape 1 : builder, installe les dépendances dans un préfixe isolé.
# -----------------------------------------------------------------------------
FROM python:3.12-slim AS builder

# Bonnes pratiques Python en conteneur : pas de .pyc, sortie non bufferisée.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# psycopg2-binary embarque ses propres libs, mais on garde gcc pour couvrir
# d'éventuelles dépendances à compiler.
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
# On installe dans /install pour ne copier que l'arborescence utile à l'étape finale.
RUN pip install --prefix=/install -r requirements.txt

# -----------------------------------------------------------------------------
# Étape 2 : runtime, image minimale, sans outils de build, non-root.
# -----------------------------------------------------------------------------
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# Crée un utilisateur non privilégié dédié à l'application.
RUN groupadd --gid 10001 appgroup \
    && useradd --uid 10001 --gid appgroup --no-create-home --shell /usr/sbin/nologin appuser

WORKDIR /app

# Récupère uniquement les dépendances déjà installées depuis l'étape builder.
COPY --from=builder /install /usr/local

# Copie le code applicatif avec le bon propriétaire.
COPY --chown=appuser:appgroup app.py .
COPY --chown=appuser:appgroup templates ./templates

# Bascule sur l'utilisateur non-root avant l'exécution.
USER appuser

EXPOSE 8000

# Health check intégré (complète le health check de l'ALB côté plateforme).
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0) if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status==200 else sys.exit(1)"

# Gunicorn : 2 workers, 4 threads, adapté à 0.25 vCPU / 512 Mo.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--threads", "4", "--timeout", "30", "--access-logfile", "-", "app:app"]
