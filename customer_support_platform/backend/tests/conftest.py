"""Shared test fixtures.

The retrieval tests run against whatever knowledge base is in the local
database, so they need `python -m app.seed --fresh --kaggle` (or `--fresh`)
to have been run first. If the KB is empty they skip rather than fail.
"""
from __future__ import annotations

import pytest

from app.database.connection import SessionLocal
from app.database.models import KnowledgeChunk


@pytest.fixture()
def db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture()
def kb_ready(db):
    """Skip a test unless the knowledge base has embedded chunks to search."""
    embedded = (
        db.query(KnowledgeChunk)
        .filter(KnowledgeChunk.embedding.isnot(None))
        .count()
    )
    if embedded == 0:
        pytest.skip("knowledge base not seeded - run: python -m app.seed --fresh --kaggle")
    return embedded


@pytest.fixture()
def mock_provider(monkeypatch):
    """Force deterministic mock AI regardless of the .env provider."""
    from app.config import settings

    monkeypatch.setattr(settings, "AI_PROVIDER", "mock")
