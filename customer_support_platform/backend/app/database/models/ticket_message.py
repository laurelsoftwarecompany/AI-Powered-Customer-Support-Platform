from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Text, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class TicketMessage(Base):
    __tablename__ = "ticket_messages"

    # A ticket thread is always read as "this ticket, oldest first".
    __table_args__ = (
        Index("ix_ticket_messages_ticket_created", "ticket_id", "created_at"),
    )

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True
    )

    ticket_id: Mapped[int] = mapped_column(
        ForeignKey("tickets.id"),
        nullable=False,
        index=True
    )

    sender_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
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

    is_internal: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False
    )

    ticket = relationship(
        "Ticket",
        back_populates="messages"
    )

    sender = relationship(
        "User"
    )

