from fastapi import FastAPI

from app.api.users import router as users_router
from app.api.auth import router as auth_router
from app.api.conversations import router as conversations_router
from app.api.messages import router as messages_router
from app.api.tickets import router as tickets_router


app = FastAPI(
    title="AI Customer Support Platform",
    version="1.0.0"
)


app.include_router(users_router)
app.include_router(auth_router)
app.include_router(conversations_router)
app.include_router(messages_router)
app.include_router(tickets_router)

# ============================================================
# ROOT
# ============================================================

@app.get("/")
def root():
    return {
        "message": "AI Customer Support Platform Backend is running",
        "version": "1.0.0"
    }


# ============================================================
# HEALTH CHECK
# ============================================================

@app.get("/health")
def health():
    return {
        "status": "healthy"
    }
