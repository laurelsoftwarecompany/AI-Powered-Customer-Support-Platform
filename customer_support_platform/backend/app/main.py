from fastapi import FastAPI

from app.api.users import router as users_router
from app.api.auth import router as auth_router
from app.api.conversations import router as conversations_router


app = FastAPI(
    title="AI Customer Support Platform",
    version="1.0.0"
)

app.include_router(users_router)
app.include_router(auth_router)
app.include_router(conversations_router)


@app.get("/")
def root():
    return {
        "message": "Backend is running"
    }


@app.get("/health")
def health():
    return {
        "status": "healthy"
    }