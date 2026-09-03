from datetime import datetime

from sqlalchemy import JSON, DateTime, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True
    )

    conversation_id: Mapped[int] = mapped_column(
        ForeignKey("conversations.id"),
        nullable=False,
        index=True
    )

    sender_type: Mapped[str] = mapped_column(
        String(30),
        nullable=False
    )

    content: Mapped[str] = mapped_column(
        Text,
        nullable=False
    )

    intent: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True
    )

    confidence: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    # Knowledge-base articles the AI grounded this answer in (RAG).
    # List of {document_id, title, score, snippet}; null for non-AI messages
    # and AI answers where retrieval found nothing above RAG_MIN_SCORE.
    sources: Mapped[list | None] = mapped_column(
        JSON(none_as_null=True),
        nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False
    )

    conversation = relationship(
        "Conversation",
        back_populates="messages"
    )