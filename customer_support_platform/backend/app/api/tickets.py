
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models.ticket import (
    Ticket,
    TicketStatus,
    TicketPriority,
)
from app.database.models.ticket_message import TicketMessage
from app.database.models.user import User, UserRole
from app.api.auth import get_current_user


router = APIRouter(
    prefix="/tickets",
    tags=["Tickets"]
)


# ============================================================
# REQUEST SCHEMAS
# ============================================================

class TicketCreate(BaseModel):
    subject: str = Field(..., min_length=1, max_length=255)
    description: str = Field(..., min_length=1)
    category: str = Field(..., min_length=1, max_length=100)
    priority: TicketPriority = TicketPriority.MEDIUM


class TicketMessageCreate(BaseModel):
    content: str = Field(..., min_length=1)


class TicketUpdate(BaseModel):
    status: TicketStatus | None = None
    priority: TicketPriority | None = None
    assigned_agent_id: int | None = None


# ============================================================
# CUSTOMER — CREATE TICKET
# ============================================================

@router.post("/")
def create_ticket(
    ticket_data: TicketCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ticket = Ticket(
        customer_id=current_user.id,
        subject=ticket_data.subject,
        description=ticket_data.description,
        category=ticket_data.category,
        priority=ticket_data.priority,
        status=TicketStatus.OPEN
    )

    db.add(ticket)
    db.commit()
    db.refresh(ticket)

    # Create the first ticket message from the customer
    initial_message = TicketMessage(
        ticket_id=ticket.id,
        sender_id=current_user.id,
        sender_type="customer",
        content=ticket_data.description,
        is_internal=False
    )

    db.add(initial_message)
    db.commit()
    db.refresh(initial_message)

    return {
        "ticket": ticket,
        "message": initial_message
    }


# ============================================================
# CUSTOMER — GET MY TICKETS
# ============================================================

@router.get("/my")
def get_my_tickets(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    tickets = (
        db.query(Ticket)
        .filter(Ticket.customer_id == current_user.id)
        .order_by(Ticket.updated_at.desc())
        .all()
    )

    return tickets


# ============================================================
# GET SINGLE TICKET
# ============================================================

@router.get("/{ticket_id}")
def get_ticket(
    ticket_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ticket = (
        db.query(Ticket)
        .filter(Ticket.id == ticket_id)
        .first()
    )

    if not ticket:
        raise HTTPException(
            status_code=404,
            detail="Ticket not found"
        )

    # Customer can only see their own ticket
    if (
        current_user.role == UserRole.CUSTOMER
        and ticket.customer_id != current_user.id
    ):
        raise HTTPException(
            status_code=403,
            detail="You do not have access to this ticket"
        )

    return ticket


# ============================================================
# GET TICKET MESSAGES
# ============================================================

@router.get("/{ticket_id}/messages")
def get_ticket_messages(
    ticket_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ticket = (
        db.query(Ticket)
        .filter(Ticket.id == ticket_id)
        .first()
    )

    if not ticket:
        raise HTTPException(
            status_code=404,
            detail="Ticket not found"
        )

    # Customer access check
    if (
        current_user.role == UserRole.CUSTOMER
        and ticket.customer_id != current_user.id
    ):
        raise HTTPException(
            status_code=403,
            detail="You do not have access to this ticket"
        )

    query = (
        db.query(TicketMessage)
        .filter(TicketMessage.ticket_id == ticket_id)
    )

    # Customers should not see internal notes
    if current_user.role == UserRole.CUSTOMER:
        query = query.filter(
            TicketMessage.is_internal == False
        )

    messages = (
        query
        .order_by(TicketMessage.created_at.asc())
        .all()
    )

    return messages


# ============================================================
# ADD MESSAGE TO TICKET
# ============================================================

@router.post("/{ticket_id}/messages")
def add_ticket_message(
    ticket_id: int,
    message_data: TicketMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ticket = (
        db.query(Ticket)
        .filter(Ticket.id == ticket_id)
        .first()
    )

    if not ticket:
        raise HTTPException(
            status_code=404,
            detail="Ticket not found"
        )

    # Customer can only reply to their own ticket
    if (
        current_user.role == UserRole.CUSTOMER
        and ticket.customer_id != current_user.id
    ):
        raise HTTPException(
            status_code=403,
            detail="You do not have access to this ticket"
        )

    # Determine sender type
    if current_user.role == UserRole.CUSTOMER:
        sender_type = "customer"
    elif current_user.role == UserRole.AGENT:
        sender_type = "agent"
    else:
        sender_type = "admin"

    ticket_message = TicketMessage(
        ticket_id=ticket.id,
        sender_id=current_user.id,
        sender_type=sender_type,
        content=message_data.content,
        is_internal=False
    )

    db.add(ticket_message)

    # If customer replies to a resolved/closed ticket,
    # reopen it.
    if current_user.role == UserRole.CUSTOMER:
        if ticket.status in {
            TicketStatus.RESOLVED,
            TicketStatus.CLOSED
        }:
            ticket.status = TicketStatus.OPEN

    ticket.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(ticket_message)

    return ticket_message


# ============================================================
# AGENT / ADMIN — UPDATE TICKET
# ============================================================

@router.patch("/{ticket_id}")
def update_ticket(
    ticket_id: int,
    ticket_data: TicketUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Only agents/admins can update ticket management fields
    if current_user.role not in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:
        raise HTTPException(
            status_code=403,
            detail="Only agents and administrators can update tickets"
        )

    ticket = (
        db.query(Ticket)
        .filter(Ticket.id == ticket_id)
        .first()
    )

    if not ticket:
        raise HTTPException(
            status_code=404,
            detail="Ticket not found"
        )

    if ticket_data.status is not None:
        ticket.status = ticket_data.status

    if ticket_data.priority is not None:
        ticket.priority = ticket_data.priority

    if ticket_data.assigned_agent_id is not None:

        agent = (
            db.query(User)
            .filter(
                User.id == ticket_data.assigned_agent_id,
                User.role == UserRole.AGENT
            )
            .first()
        )

        if not agent:
            raise HTTPException(
                status_code=400,
                detail="Assigned user is not a valid support agent"
            )

        ticket.assigned_agent_id = agent.id

    ticket.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(ticket)

    return ticket


# ============================================================
# AGENT / ADMIN — GET ALL TICKETS
# ============================================================

@router.get("/")
def get_all_tickets(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role not in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:
        raise HTTPException(
            status_code=403,
            detail="Only agents and administrators can view all tickets"
        )

    tickets = (
        db.query(Ticket)
        .order_by(Ticket.updated_at.desc())
        .all()
    )

    return tickets


# ============================================================
# AGENT / ADMIN — ADD INTERNAL NOTE
# ============================================================

@router.post("/{ticket_id}/internal-notes")
def add_internal_note(
    ticket_id: int,
    message_data: TicketMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role not in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:
        raise HTTPException(
            status_code=403,
            detail="Only agents and administrators can add internal notes"
        )

    ticket = (
        db.query(Ticket)
        .filter(Ticket.id == ticket_id)
        .first()
    )

    if not ticket:
        raise HTTPException(
            status_code=404,
            detail="Ticket not found"
        )

    internal_message = TicketMessage(
    ticket_id=ticket.id,
    sender_id=current_user.id,
    sender_type=(
        "agent"
        if current_user.role == UserRole.AGENT
        else "admin"
    ),
    content=message_data.content,
    is_internal=True
)

    db.add(internal_message)

    ticket.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(internal_message)

    return internal_message
