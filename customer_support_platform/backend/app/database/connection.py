from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.config import settings


# PostgreSQL database connection
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
)


# Database session
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


# FastAPI database dependency
def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()
