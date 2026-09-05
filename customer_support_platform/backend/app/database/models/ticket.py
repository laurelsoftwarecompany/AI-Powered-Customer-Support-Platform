from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base

import enum


class TicketStatus(str, enum.Enum):
    OPEN = "open"
    IN_PROGRESS = "in_progress"
    WAITING_FOR_CUSTOMER = "waiting_for_customer"
    RESOLVED = "resolved"
    CLOSED = "closed"


class TicketPriority(str, enum.Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    URGENT = "urgent"


class Ticket(Base):
    __tablename__ = "tickets"

    # Every list view is "my tickets, newest first" or "queue filtered by
    # status, newest first" - index the pairs those actually scan.
    __table_args__ = (
        Index("ix_tickets_customer_updated", "customer_id", "updated_at"),
        Index("ix_tickets_status_updated", "status", "updated_at"),
    )

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        index=True
    )

    customer_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
        index=True
    )

    assigned_agent_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id"),
        nullable=True,
        index=True
    )

    conversation_id: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        index=True
    )

    subject: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )

    description: Mapped[str] = mapped_column(
        Text,
        nullable=False
    )

    category: Mapped[str] = mapped_column(
        String(100),
        nullable=False
    )

    priority: Mapped[TicketPriority] = mapped_column(
        Enum(TicketPriority),
        default=TicketPriority.MEDIUM,
        nullable=False
    )

    status: Mapped[TicketStatus] = mapped_column(
        Enum(TicketStatus),
        default=TicketStatus.OPEN,
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
    nullable=False)

    customer = relationship(
        "User",
        foreign_keys=[customer_id]
    )

    assigned_agent = relationship(
        "User",
        foreign_keys=[assigned_agent_id]
    )

    messages = relationship(
        "TicketMessage",
        back_populates="ticket",
        cascade="all, delete-orphan"
    )
