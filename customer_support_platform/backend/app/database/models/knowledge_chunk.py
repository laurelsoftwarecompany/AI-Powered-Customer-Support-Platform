from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class KnowledgeChunk(Base):
    __tablename__ = "knowledge_chunks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    document_id: Mapped[int] = mapped_column(
        ForeignKey("knowledge_documents.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    chunk_index: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    content: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    # 384-dim embedding (all-MiniLM-L6-v2) stored as a JSON array.
    # Nullable: a chunk exists as soon as a document is uploaded; the
    # embedding is filled in by the indexing pass (knowledge_service.reindex).
    # none_as_null=True so a missing embedding is SQL NULL (not JSON "null"),
    # which keeps `.is_(None)` / `.isnot(None)` filters correct.
    # Portable across SQLite and PostgreSQL; similarity search runs in Python.
    embedding: Mapped[list[float] | None] = mapped_column(
        JSON(none_as_null=True),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    document = relationship(
        "KnowledgeDocument",
        back_populates="chunks",
    )
