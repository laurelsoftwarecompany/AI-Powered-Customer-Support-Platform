from functools import cached_property
from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parent.parent
DEFAULT_SQLITE_PATH = (BACKEND_DIR / "customer_support.db").resolve().as_posix()


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
    )

    # ------------------------------------------------------------------
    # Database
    # ------------------------------------------------------------------
    # Defaults to a local SQLite file anchored to backend root.
    # Point at PostgreSQL (with pgvector) for production:
    #   postgresql+psycopg2://user:pass@host:5432/customer_support
    DATABASE_URL: str = f"sqlite:///{DEFAULT_SQLITE_PATH}"

    @field_validator("DATABASE_URL", mode="after")
    @classmethod
    def resolve_sqlite_path(cls, v: str) -> str:
        if v.startswith("sqlite:///./"):
            rel = v.removeprefix("sqlite:///./")
            abs_path = (BACKEND_DIR / rel).resolve().as_posix()
            return f"sqlite:///{abs_path}"
        return v

    # ------------------------------------------------------------------
    # Auth
    # ------------------------------------------------------------------
    JWT_SECRET_KEY: str = "dev-secret-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # ------------------------------------------------------------------
    # AI provider:  mock | gemini | groq | openrouter | openai | anthropic
    #   mock -> deterministic canned answers, no API key required
    #   gemini / groq / openrouter / openai -> OpenAI-compatible, set the key
    #   anthropic -> uses the anthropic SDK
    # ------------------------------------------------------------------
    AI_PROVIDER: str = "mock"
    AI_MODEL: str = ""  # blank -> per-provider default (see ai_service.PROVIDER_DEFAULTS)
    OPENROUTER_API_KEY: str = ""
    OPENAI_API_KEY: str = ""
    ANTHROPIC_API_KEY: str = ""
    GEMINI_API_KEY: str = ""
    GROQ_API_KEY: str = ""

    # ------------------------------------------------------------------
    # RAG
    # ------------------------------------------------------------------
    EMBEDDING_MODEL: str = "BAAI/bge-small-en-v1.5"  # fastembed, 384-dim, local
    RAG_TOP_K: int = 4
    RAG_MIN_SCORE: float = 0.5  # ignore retrieved chunks below this cosine score
    CONFIDENCE_THRESHOLD: float = 0.70

    # ------------------------------------------------------------------
    # CORS (comma-separated origins)
    # ------------------------------------------------------------------
    CORS_ORIGINS: str = (
        "http://localhost:3000,http://127.0.0.1:3000,"
        "http://localhost:5500,http://127.0.0.1:5500"
    )

    @cached_property
    def cors_origins_list(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.CORS_ORIGINS.split(",")
            if origin.strip()
        ]

    @cached_property
    def is_sqlite(self) -> bool:
        return self.DATABASE_URL.startswith("sqlite")


settings = Settings()
