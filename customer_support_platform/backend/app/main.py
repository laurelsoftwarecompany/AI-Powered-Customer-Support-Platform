from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database.base import Base
from app.database.connection import engine
import app.database.models  # noqa: F401  (registers every model on Base.metadata)
from app.middleware import (
    RateLimitMiddleware,
    SecurityHeadersMiddleware,
    setup_error_handlers,
)

from app.api.users import router as users_router
from app.api.auth import router as auth_router
from app.api.conversations import router as conversations_router
from app.api.messages import router as messages_router
from app.api.tickets import router as tickets_router
from app.api.agents import router as agents_router
from app.api.admin import router as admin_router
from app.api.knowledge import router as knowledge_router
from app.api.ws_routes import router as ws_router


API_PREFIX = "/api/v1"


@asynccontextmanager
async def lifespan(app: FastAPI):
    # For zero-setup local dev on SQLite, create tables on boot.
    # PostgreSQL deployments run Alembic migrations instead.
    if settings.is_sqlite:
        Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="AI Customer Support Platform",
    version="1.0.0",
    lifespan=lifespan,
)

# ============================================================
# SECURITY & ERROR HANDLING MIDDLEWARE
# ============================================================

setup_error_handlers(app)

app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(RateLimitMiddleware)

# ============================================================
# CORS
# ============================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|.*\.onrender\.com|.*\.vercel\.app)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# API ROUTERS  (all under /api/v1)
# ============================================================

for router in (
    users_router,
    auth_router,
    conversations_router,
    messages_router,
    tickets_router,
    agents_router,
    admin_router,
    knowledge_router,
    ws_router,
):
    app.include_router(router, prefix=API_PREFIX)


# ============================================================
# ROOT / HEALTH
# ============================================================

@app.get("/")
def root():
    return {
        "message": "AI Customer Support Platform Backend is running",
        "version": "1.0.0",
        "docs": "/docs",
        "api_base": API_PREFIX,
    }


@app.get("/health")
@app.get("/api/v1/health")
def health():
    return {"status": "healthy"}
