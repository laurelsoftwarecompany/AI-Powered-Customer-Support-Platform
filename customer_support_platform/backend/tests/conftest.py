"""Shared test fixtures.

Runs integration tests against a temporary copy of the database (test_customer_support.db)
so that running tests does not pollute the active development database with dummy tickets.
"""
from __future__ import annotations

import shutil
from pathlib import Path
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database.connection import get_db
from app.database.models import KnowledgeChunk

BACKEND_DIR = Path(__file__).resolve().parent.parent
REAL_DB = BACKEND_DIR / "customer_support.db"
TEST_DB = BACKEND_DIR / "test_customer_support.db"

test_engine = create_engine(
    f"sqlite:///{TEST_DB.as_posix()}",
    connect_args={"check_same_thread": False},
)
TestingSessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=test_engine,
)


@pytest.fixture(scope="session", autouse=True)
def setup_test_db():
    """Copy the real database to an isolated test db before testing, remove after."""
    if REAL_DB.exists():
        shutil.copyfile(REAL_DB, TEST_DB)
        from app.api.auth import password_hash
        from app.database.models.user import User, UserRole
        session = TestingSessionLocal()
        try:
            sarah = session.query(User).filter(User.email == "sarah@example.com").first()
            if not sarah:
                sarah = User(
                    name="Sarah Connor",
                    email="sarah@example.com",
                    password_hash=password_hash.hash("customer1234"),
                    role=UserRole.CUSTOMER,
                    is_active=True
                )
                session.add(sarah)
            james = session.query(User).filter(User.email == "james@example.com").first()
            if not james:
                james = User(
                    name="James Holden",
                    email="james@example.com",
                    password_hash=password_hash.hash("customer1234"),
                    role=UserRole.CUSTOMER,
                    is_active=True
                )
                session.add(james)
            session.commit()
        finally:
            session.close()
    yield
    if TEST_DB.exists():
        try:
            TEST_DB.unlink()
        except Exception:
            pass


@pytest.fixture()
def db():
    session = TestingSessionLocal()
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


@pytest.fixture()
def client():
    """TestClient fixture with get_db overridden to point to the isolated test database."""
    from fastapi.testclient import TestClient
    from app.main import app

    def override_get_db():
        session = TestingSessionLocal()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    test_client = TestClient(app)
    yield test_client
    app.dependency_overrides.pop(get_db, None)


@pytest.fixture(autouse=True)
def reset_rate_limits():
    """Ensure rate limit buckets are reset between test runs."""
    from app.middleware import _limiter

    _limiter.reset()
    yield
    _limiter.reset()
