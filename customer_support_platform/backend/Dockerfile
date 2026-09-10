# AI-Powered Customer Support Platform - backend (FastAPI)
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    FASTEMBED_CACHE_PATH=/opt/fastembed

WORKDIR /app

# libgomp is required by onnxruntime (the fastembed backend); curl powers the
# container healthcheck.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Bake the embedding model into the image so the first question a customer
# asks doesn't wait on a ~30 MB download.
RUN python -c "from fastembed import TextEmbedding; TextEmbedding(model_name='BAAI/bge-small-en-v1.5')"

COPY . .

# Create non-root user and grant ownership
RUN groupadd -g 1001 appuser && useradd -u 1001 -g appuser -s /bin/bash -m appuser \
    && chown -R appuser:appuser /opt/fastembed /app

USER appuser
EXPOSE 8000

# Migrate, seed once if the database is empty, then serve.
CMD ["sh", "-c", "alembic upgrade head && python -m app.seed && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
