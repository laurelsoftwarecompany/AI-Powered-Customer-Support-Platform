
from datetime import datetime

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models.ticket import (
    Ticket,
    TicketStatus,
    TicketPriority,
)
from app.database.models.ticket_message import TicketMessage
from app.database.models.conversation import Conversation
from app.database.models.message import Message
from app.database.models.user import User, UserRole
from app.api.auth import get_current_user
from app.websocket_manager import manager as ws_manager
from app.services.ai_service import generate_ai_response
from app.services.knowledge_service import retrieve_context
import logging

logger = logging.getLogger(__name__)


router = APIRouter(
    prefix="/tickets",
    tags=["Tickets"]
)


def get_or_create_ai_user(db: Session) -> User:
    ai = db.query(User).filter(User.email == "ai@laurel.test").first()
    if not ai:
        ai = User(
            name="Laurel AI Assistant",
            email="ai@laurel.test",
            password_hash="!system_ai_bot!",
            role=UserRole.AGENT,
            is_active=True
        )
        db.add(ai)
        db.flush()
    return ai


# ============================================================
# REQUEST SCHEMAS
# ============================================================

class TicketCreate(BaseModel):
    subject: str = Field(..., min_length=1, max_length=255)
    description: str = Field(..., min_length=1)
    category: str = Field(..., min_length=1, max_length=100)
    priority: TicketPriority = TicketPriority.MEDIUM
    conversation_id: int | None = None


class TicketMessageCreate(BaseModel):
    content: str = Field(..., min_length=1)


class TicketUpdate(BaseModel):
    status: TicketStatus | None = None
    priority: TicketPriority | None = None
    assigned_agent_id: int | None = None


ALLOWED_STATUS_TRANSITIONS: dict[TicketStatus, set[TicketStatus]] = {
    TicketStatus.OPEN: {
        TicketStatus.OPEN,
        TicketStatus.IN_PROGRESS,
        TicketStatus.WAITING_FOR_CUSTOMER,
        TicketStatus.RESOLVED,
        TicketStatus.CLOSED,
    },
    TicketStatus.IN_PROGRESS: {
        TicketStatus.IN_PROGRESS,
        TicketStatus.WAITING_FOR_CUSTOMER,
        TicketStatus.RESOLVED,
        TicketStatus.OPEN,
        TicketStatus.CLOSED,
    },
    TicketStatus.WAITING_FOR_CUSTOMER: {
        TicketStatus.WAITING_FOR_CUSTOMER,
        TicketStatus.IN_PROGRESS,
        TicketStatus.RESOLVED,
        TicketStatus.OPEN,
        TicketStatus.CLOSED,
    },
    TicketStatus.RESOLVED: {
        TicketStatus.RESOLVED,
        TicketStatus.CLOSED,
        TicketStatus.OPEN,
    },
    TicketStatus.CLOSED: {
        TicketStatus.CLOSED,
    },
}


# ============================================================
# CUSTOMER — CREATE TICKET
# ============================================================

@router.post("/")
def create_ticket(
    ticket_data: TicketCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        # 1. Create the Ticket
        ticket = Ticket(
            customer_id=current_user.id,
            conversation_id=ticket_data.conversation_id,
            subject=ticket_data.subject,
            description=ticket_data.description,
            category=ticket_data.category,
            priority=ticket_data.priority,
            status=TicketStatus.OPEN
        )

        db.add(ticket)
        db.flush()

        # 2. Ensure dedicated Conversation exists for this ticket
        conv = None
        if ticket_data.conversation_id:
            conv = (
                db.query(Conversation)
                .filter(Conversation.id == ticket_data.conversation_id)
                .first()
            )
            if conv:
                conv.ticket_id = ticket.id
                conv.ai_active = True
                conv.status = "active"
                conv.updated_at = datetime.utcnow()

        if not conv:
            conv = Conversation(
                customer_id=current_user.id,
                status="active",
                ai_active=True,
                ticket_id=ticket.id
            )
            db.add(conv)
            db.flush()
            ticket.conversation_id = conv.id

        # 3. Create the customer's initial message in both TicketMessage and Message
        initial_message = TicketMessage(
            ticket_id=ticket.id,
            sender_id=current_user.id,
            sender_type="customer",
            content=ticket_data.description,
            is_internal=False
        )
        db.add(initial_message)

        initial_conv_msg = Message(
            conversation_id=conv.id,
            sender_type="customer",
            content=ticket_data.description
        )
        db.add(initial_conv_msg)

        # 4. AI First Responder triage & initial grounding
        ai_ticket_msg = None
        ai_conv_msg = None
        kb_context, kb_sources = None, []
        try:
            kb_context, kb_sources = retrieve_context(
                db, f"{ticket_data.subject}\n{ticket_data.description}"
            )
        except Exception as kb_err:
            logger.warning("KB retrieval failed for new ticket: %s", kb_err)

        try:
            ai_result = generate_ai_response(
                message=(
                    f"New support ticket opened by customer.\n"
                    f"Subject: {ticket_data.subject}\n"
                    f"Category: {ticket_data.category}\n"
                    f"Details: {ticket_data.description}\n"
                    f"Please act as the AI First Responder for Laurel Software: acknowledge the issue, "
                    f"provide relevant troubleshooting or next steps based on documentation, and let "
                    f"them know a support specialist is on standby if needed."
                ),
                conversation_history=[],
                context=kb_context,
            )
            ai_text = ai_result.get(
                "response",
                "Hello! Thank you for opening this ticket. I am reviewing your request and a support specialist is on standby to assist."
            )

            ai_conv_msg = Message(
                conversation_id=conv.id,
                sender_type="ai",
                content=ai_text,
                intent=ai_result.get("intent"),
                confidence=ai_result.get("confidence"),
                sources=kb_sources or None,
            )
            db.add(ai_conv_msg)

            ai_user = get_or_create_ai_user(db)
            ai_ticket_msg = TicketMessage(
                ticket_id=ticket.id,
                sender_id=ai_user.id,
                sender_type="ai",
                content=ai_text,
                sources=kb_sources or None,
                is_internal=False,
            )
            db.add(ai_ticket_msg)
        except Exception as ai_err:
            logger.error("AI first responder generation failed: %s", ai_err)

        db.commit()
        db.refresh(ticket)
        db.refresh(initial_message)
        if ai_ticket_msg:
            db.refresh(ai_ticket_msg)

        # 5. Broadcast real-time events via WebSocket
        _ws_broadcast_ticket(
            background_tasks,
            ticket_id=ticket.id,
            conversation_id=conv.id,
            event="new_message",
            message=_ticket_msg_payload(initial_message),
        )
        if ai_ticket_msg:
            _ws_broadcast_ticket(
                background_tasks,
                ticket_id=ticket.id,
                conversation_id=conv.id,
                event="new_message",
                message=_ticket_msg_payload(ai_ticket_msg),
            )

        return {
            "ticket": ticket,
            "message": initial_message,
            "ai_message": ai_ticket_msg,
            "conversation_id": conv.id
        }
    except Exception as exc:
        db.rollback()
        logger.error("Failed to create ticket: %s", exc)
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create ticket: {exc}"
        ) from exc


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
    background_tasks: BackgroundTasks,
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

    conversation = None
    if ticket.conversation_id:
        conversation = (
            db.query(Conversation)
            .filter(Conversation.id == ticket.conversation_id)
            .first()
        )
        if conversation:
            conv_message = Message(
                conversation_id=conversation.id,
                sender_type=sender_type,
                content=message_data.content,
            )
            db.add(conv_message)

            # An agent reply does NOT silence the AI - only an explicit
            # takeover does. Otherwise one "we are looking into it" leaves the
            # customer with no one answering until that agent comes back.
            conversation.updated_at = datetime.utcnow()

    # ---------------------------------------------------------
    # CASE 1: AGENT / ADMIN REPLIES
    # ---------------------------------------------------------
    # Replying does NOT take the conversation off the AI - that is what the
    # explicit Takeover endpoint is for. Otherwise a single "we're looking
    # into it" leaves the customer with nobody answering until the agent
    # comes back, which is exactly the dead-end this used to create.
    if sender_type in {"agent", "admin"}:
        if ticket.status == TicketStatus.OPEN:
            ticket.status = TicketStatus.IN_PROGRESS

        if not ticket.assigned_agent_id and current_user.role == UserRole.AGENT:
            ticket.assigned_agent_id = current_user.id

        ticket.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(ticket_message)
        db.refresh(ticket)
        if conversation:
            db.refresh(conversation)

        # Broadcast message and takeover status change via WebSocket
        _ws_broadcast_ticket(
            background_tasks,
            ticket_id=ticket_id,
            conversation_id=ticket.conversation_id,
            event="new_message",
            message=_ticket_msg_payload(ticket_message),
        )
        _ws_broadcast_ticket(
            background_tasks,
            ticket_id=ticket_id,
            conversation_id=ticket.conversation_id,
            event="status_change",
            ai_active=conversation.ai_active if conversation else True,
            status=conversation.status if conversation else "active",
            assigned_agent_id=ticket.assigned_agent_id,
        )
        return ticket_message

    # ---------------------------------------------------------
    # CASE 2: CUSTOMER REPLIES
    # ---------------------------------------------------------
    if ticket.status in {TicketStatus.RESOLVED, TicketStatus.CLOSED}:
        ticket.status = TicketStatus.OPEN

    ticket.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(ticket_message)

    # Broadcast customer's message immediately
    _ws_broadcast_ticket(
        background_tasks,
        ticket_id=ticket_id,
        conversation_id=ticket.conversation_id,
        event="new_message",
        message=_ticket_msg_payload(ticket_message),
    )

    # If AI is still the active first responder, generate response
    ai_active = conversation.ai_active if conversation else True
    if ai_active:
        # Build short sliding history from recent messages
        recent_msgs = (
            db.query(TicketMessage)
            .filter(
                TicketMessage.ticket_id == ticket.id,
                TicketMessage.is_internal == False
            )
            .order_by(TicketMessage.created_at.desc())
            .limit(10)
            .all()
        )
        history = [
            {"sender_type": m.sender_type, "content": m.content}
            for m in reversed(recent_msgs)
        ]

        kb_context, kb_sources = None, []
        try:
            kb_context, kb_sources = retrieve_context(db, message_data.content)
        except Exception as kb_err:
            logger.warning("KB retrieval failed for ticket reply: %s", kb_err)

        try:
            ai_result = generate_ai_response(
                message=message_data.content,
                conversation_history=history,
                context=kb_context,
            )
            ai_text = ai_result.get("response", "Thank you for the update. Our support specialists will review this.")

            ai_user = get_or_create_ai_user(db)
            ai_ticket_msg = TicketMessage(
                ticket_id=ticket.id,
                sender_id=ai_user.id,
                sender_type="ai",
                content=ai_text,
                sources=kb_sources or None,
                is_internal=False,
            )
            db.add(ai_ticket_msg)

            if conversation:
                ai_conv_msg = Message(
                    conversation_id=conversation.id,
                    sender_type="ai",
                    content=ai_text,
                    intent=ai_result.get("intent"),
                    confidence=ai_result.get("confidence"),
                    sources=kb_sources or None,
                )
                db.add(ai_conv_msg)
                conversation.updated_at = datetime.utcnow()

            db.commit()
            db.refresh(ai_ticket_msg)

            _ws_broadcast_ticket(
                background_tasks,
                ticket_id=ticket_id,
                conversation_id=ticket.conversation_id,
                event="new_message",
                message=_ticket_msg_payload(ai_ticket_msg),
            )
        except Exception as ai_err:
            logger.error("AI reply on ticket failed: %s", ai_err)

    return ticket_message


# ============================================================
# AGENT / ADMIN — TAKE OVER TICKET LIVE CHAT
# ============================================================

@router.post("/{ticket_id}/takeover")
def takeover_ticket(
    ticket_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role not in {UserRole.AGENT, UserRole.ADMIN}:
        raise HTTPException(
            status_code=403,
            detail="Only agents and administrators can take over ticket live chat"
        )

    ticket = db.query(Ticket).filter(Ticket.id == ticket_id).first()
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")

    if ticket.status == TicketStatus.OPEN:
        ticket.status = TicketStatus.IN_PROGRESS
    if not ticket.assigned_agent_id and current_user.role == UserRole.AGENT:
        ticket.assigned_agent_id = current_user.id

    ticket.updated_at = datetime.utcnow()

    conversation = None
    if ticket.conversation_id:
        conversation = (
            db.query(Conversation)
            .filter(Conversation.id == ticket.conversation_id)
            .first()
        )
        if conversation:
            conversation.ai_active = False
            conversation.status = "human_support"
            conversation.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(ticket)
    if conversation:
        db.refresh(conversation)

    _ws_broadcast_ticket(
        background_tasks,
        ticket_id=ticket.id,
        conversation_id=ticket.conversation_id,
        event="status_change",
        ai_active=False,
        status="human_support",
        assigned_agent_id=ticket.assigned_agent_id,
    )

    return {
        "message": "Ticket successfully taken over by human agent",
        "ticket": ticket,
        "conversation": conversation,
    }


# ============================================================
# AGENT / ADMIN — HAND BACK TICKET CHAT TO AI ASSISTANT
# ============================================================

@router.post("/{ticket_id}/handback")
def handback_ticket(
    ticket_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role not in {UserRole.AGENT, UserRole.ADMIN}:
        raise HTTPException(
            status_code=403,
            detail="Only agents and administrators can hand back ticket chat to AI"
        )

    ticket = db.query(Ticket).filter(Ticket.id == ticket_id).first()
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")

    conversation = None
    if ticket.conversation_id:
        conversation = (
            db.query(Conversation)
            .filter(Conversation.id == ticket.conversation_id)
            .first()
        )
        if conversation:
            conversation.ai_active = True
            conversation.status = "active"
            conversation.updated_at = datetime.utcnow()

    ticket.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(ticket)
    if conversation:
        db.refresh(conversation)

    _ws_broadcast_ticket(
        background_tasks,
        ticket_id=ticket.id,
        conversation_id=ticket.conversation_id,
        event="status_change",
        ai_active=True,
        status="active",
        assigned_agent_id=ticket.assigned_agent_id,
    )

    return {
        "message": "Ticket live chat successfully returned to AI assistant",
        "ticket": ticket,
        "conversation": conversation,
    }


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
        allowed = ALLOWED_STATUS_TRANSITIONS.get(ticket.status, {ticket.status})
        if ticket_data.status not in allowed:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid status transition from {ticket.status.value} to {ticket_data.status.value}",
            )
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


# ============================================================
# WEBSOCKET BROADCAST HELPERS
# ============================================================

def _ticket_msg_payload(msg: TicketMessage) -> dict:
    """Serialize a TicketMessage ORM object for WS broadcast."""
    return {
        "id": msg.id,
        "ticket_id": msg.ticket_id,
        "sender_id": msg.sender_id,
        "sender_type": msg.sender_type,
        "content": msg.content,
        "is_internal": msg.is_internal,
        "sources": getattr(msg, "sources", None),
        "created_at": msg.created_at.isoformat() if msg.created_at else None,
    }


def _ws_broadcast_ticket(
    background_tasks: BackgroundTasks,
    *,
    ticket_id: int | None,
    conversation_id: int | None,
    event: str,
    message: dict | None = None,
    **extra: object,
) -> None:
    """Queue a WebSocket broadcast to run on the event loop after the response."""
    payload: dict = {
        "event": event,
        "conversation_id": conversation_id,
        "ticket_id": ticket_id,
        **extra,
    }
    if message is not None:
        payload["message"] = message

    # These endpoints are sync (`def`), so FastAPI runs them in a worker
    # thread where there is no running event loop - asyncio.get_running_loop()
    # raises there and the broadcast is lost. BackgroundTasks hands the
    # coroutine back to the main loop, and runs it after the response is sent.
    background_tasks.add_task(
        ws_manager.broadcast_conversation_and_ticket,
        conversation_id,
        ticket_id,
        payload,
    )
