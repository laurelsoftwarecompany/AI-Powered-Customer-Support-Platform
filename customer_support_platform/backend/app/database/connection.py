from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.config import settings


# SQLite needs check_same_thread=False to be used across FastAPI's
# threadpool; PostgreSQL takes no special connect args.
connect_args = (
    {"check_same_thread": False} if settings.is_sqlite else {}
)

engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    connect_args=connect_args,
)


SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()
