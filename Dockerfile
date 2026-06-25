# syntax=docker/dockerfile:1

# ---- Base image --------------------------------------------------------
FROM python:3.11-slim

# Prevent Python from writing .pyc files and buffering stdout/stderr —
# makes container logs show up immediately (important for `docker logs`
# and Azure Container Apps log streaming).
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# ---- Install dependencies first (layer caching) ------------------------
# Copying requirements.txt before the rest of the source means Docker
# only re-installs dependencies when requirements.txt actually changes,
# not on every code change — much faster rebuilds during development.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---- Copy application source -------------------------------------------
COPY . .

# ---- Run as a non-root user --------------------------------------------
RUN useradd --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Basic container-level health check (Azure Container Apps / Docker both
# respect this) hitting the /healthz route defined in app.py.
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8000/healthz').raise_for_status()" || exit 1

# gunicorn is the production WSGI server — never use `flask run` or the
# Flask dev server (app.run) in a container that's meant for production.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--timeout", "30", "app:app"]
