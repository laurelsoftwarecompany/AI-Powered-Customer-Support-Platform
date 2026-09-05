from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class Conversation(Base):
    __tablename__ = "conversations"

    # The mobile app resumes "my newest conversation"; agents list newest-first.
    __table_args__ = (
        Index("ix_conversations_customer_updated", "customer_id", "updated_at"),
        Index("ix_conversations_updated", "updated_at"),
    )

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True
    )

    customer_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
        index=True
    )

    status: Mapped[str] = mapped_column(
        String(50),
        default="active",
        nullable=False
    )

    ai_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False
    )

    customer = relationship(
        "User",
        foreign_keys=[customer_id]
    )

    messages = relationship(
        "Message",
        back_populates="conversation",
        cascade="all, delete-orphan"
    )