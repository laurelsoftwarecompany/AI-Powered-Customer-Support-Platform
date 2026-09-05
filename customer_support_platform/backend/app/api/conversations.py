from datetime import datetime

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models.conversation import Conversation
from app.database.models.ticket import Ticket, TicketStatus, TicketPriority
from app.database.models.ticket_message import TicketMessage
from app.database.models.user import User, UserRole
from app.api.auth import get_current_user
from app.websocket_manager import manager as ws_manager


router = APIRouter(
    prefix="/conversations",
    tags=["Conversations"]
)


# ============================================================
# CUSTOMER — CREATE CONVERSATION
# ============================================================

# The AI is the default first responder on every ticket conversation.
# Only an explicit agent takeover (the Takeover button, which sets
# status="human_support") silences it. An agent merely *replying* on the
# ticket must not: a single "we are looking into it" would otherwise leave
# the customer with nobody answering until that agent came back.
HUMAN_OWNED = "human_support"


def _human_has_taken_over(conversation: Conversation) -> bool:
    return conversation.status == HUMAN_OWNED


@router.post("/")
def create_conversation(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.CUSTOMER:
        raise HTTPException(
            status_code=403,
            detail="Only customers can create conversations"
        )

    conversation = Conversation(
        customer_id=current_user.id,
        status="active",
        ai_active=True
    )

    db.add(conversation)
    db.commit()
    db.refresh(conversation)

    return conversation


# ============================================================
# CUSTOMER — GET OR CREATE ACTIVE ASK AI CONVERSATION
# ============================================================

@router.get("/ask-ai")
def get_ask_ai_conversation(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.CUSTOMER:
        raise HTTPException(
            status_code=403,
            detail="Only customers can access Ask AI"
        )

    # Standalone Ask AI conversations always have ticket_id = None
    conv = (
        db.query(Conversation)
        .filter(
            Conversation.customer_id == current_user.id,
            Conversation.ticket_id.is_(None)
        )
        .order_by(Conversation.updated_at.desc())
        .first()
    )

    if not conv:
        conv = Conversation(
            customer_id=current_user.id,
            status="active",
            ai_active=True,
            ticket_id=None
        )
        db.add(conv)
        db.commit()
        db.refresh(conv)

    return conv


# ============================================================
# CUSTOMER — START FRESH ASK AI CONVERSATION (NEW CHAT)
# ============================================================

@router.post("/ask-ai/new")
def start_new_ask_ai_conversation(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.CUSTOMER:
        raise HTTPException(
            status_code=403,
            detail="Only customers can start Ask AI conversations"
        )

    conv = Conversation(
        customer_id=current_user.id,
        status="active",
        ai_active=True,
        ticket_id=None
    )
    db.add(conv)
    db.commit()
    db.refresh(conv)
    return conv


# ============================================================
# GET CONVERSATION FOR A SPECIFIC TICKET
# ============================================================

@router.get("/ticket/{ticket_id}")
def get_ticket_conversation(
    ticket_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ticket = db.query(Ticket).filter(Ticket.id == ticket_id).first()
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")

    if (
        current_user.role == UserRole.CUSTOMER
        and ticket.customer_id != current_user.id
    ):
        raise HTTPException(
            status_code=403,
            detail="You do not have access to this ticket"
        )

    conv = None
    if ticket.conversation_id:
        conv = (
            db.query(Conversation)
            .filter(Conversation.id == ticket.conversation_id)
            .first()
        )

    if conv:
        # Unless an agent has explicitly taken over, the AI is on duty here.
        if not _human_has_taken_over(conv) and not conv.ai_active:
            conv.ai_active = True
            conv.status = "active"
            db.commit()
            db.refresh(conv)
    else:
        conv = Conversation(
            customer_id=ticket.customer_id,
            status="active",
            ai_active=True,
            ticket_id=ticket.id
        )
        db.add(conv)
        db.flush()
        ticket.conversation_id = conv.id
        db.commit()
        db.refresh(conv)
        db.refresh(ticket)

    return {
        "conversation": conv,
        "ticket": ticket,
    }


# ============================================================
# CUSTOMER — GET MY CONVERSATIONS
# ============================================================

@router.get("/my")
def get_my_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.CUSTOMER:
        raise HTTPException(
            status_code=403,
            detail="Only customers can access their conversations"
        )

    conversations = (
        db.query(Conversation)
        .filter(
            Conversation.customer_id == current_user.id
        )
        .order_by(
            Conversation.updated_at.desc()
        )
        .all()
    )

    return conversations


# ============================================================
# AGENT / ADMIN — GET ALL CONVERSATIONS
# ============================================================

@router.get("/")
def get_all_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role not in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:
        raise HTTPException(
            status_code=403,
            detail="Only agents and administrators can view all conversations"
        )

    conversations = (
        db.query(Conversation)
        .order_by(
            Conversation.updated_at.desc()
        )
        .all()
    )

    return conversations


# ============================================================
# GET SINGLE CONVERSATION
# ============================================================

@router.get("/{conversation_id}")
def get_conversation(
    conversation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    conversation = (
        db.query(Conversation)
        .filter(
            Conversation.id == conversation_id
        )
        .first()
    )

    if not conversation:
        raise HTTPException(
            status_code=404,
            detail="Conversation not found"
        )

    # Customer can only access own conversations
    if (
        current_user.role == UserRole.CUSTOMER
        and conversation.customer_id != current_user.id
    ):
        raise HTTPException(
            status_code=403,
            detail="You do not have access to this conversation"
        )

    # Agents and admins can access conversations
    if current_user.role in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:
        return conversation

    return conversation


# ============================================================
# AGENT / ADMIN — TAKE OVER CONVERSATION
# ============================================================

# ============================================================
# LIVE-SUPPORT CONVERSATION RESOLUTION
# ============================================================
# Ask AI and Live Agent are deliberately separate threads.
#
#   Ask AI -> ticket_id IS NULL. 100% AI. Never adopted as a live thread,
#             never gets a ticket attached, never taken over by a human.
#   Live   -> always carries a ticket. Humans reply here.
#
# Routing live support through this helper is what stops a support session
# from swallowing the customer's Ask AI history.


def _live_conversation_for(db: Session, customer_id: int) -> Conversation:
    """The customer's live-support conversation, created if there isn't one.

    Only conversations that already carry a ticket are candidates, so the
    Ask AI thread can never be hijacked into live support.
    """
    conversation = (
        db.query(Conversation)
        .filter(
            Conversation.customer_id == customer_id,
            Conversation.ticket_id.isnot(None),
        )
        .order_by(Conversation.updated_at.desc())
        .first()
    )

    if conversation is None:
        conversation = Conversation(
            customer_id=customer_id,
            status="active",
            ai_active=True,
        )
        db.add(conversation)
        db.flush()

    return conversation


@router.patch("/{conversation_id}/takeover")
def takeover_conversation(
    conversation_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role not in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:
        raise HTTPException(
            status_code=403,
            detail="Only agents and administrators can take over conversations"
        )

    conversation = (
        db.query(Conversation)
        .filter(
            Conversation.id == conversation_id
        )
        .first()
    )

    if not conversation:
        raise HTTPException(
            status_code=404,
            detail="Conversation not found"
        )

    # The Ask AI assistant is a pure-AI surface and cannot be taken over -
    # silencing it would strand the customer mid-answer. Agents reply on the
    # customer's live support conversation or on the ticket instead.
    if conversation.ticket_id is None:
        raise HTTPException(
            status_code=400,
            detail=(
                "This is the customer's Ask AI thread, which always stays with "
                "the AI assistant. Reply on their live support conversation or "
                "their ticket instead."
            )
        )

    conversation.ai_active = False
    conversation.status = "human_support"
    conversation.updated_at = datetime.utcnow()

    # Link an escalation ticket if one isn't already assigned
    ticket = None
    if conversation.ticket_id:
        ticket = db.query(Ticket).filter(Ticket.id == conversation.ticket_id).first()

    if not ticket:
        ticket = Ticket(
            customer_id=conversation.customer_id,
            conversation_id=conversation.id,
            assigned_agent_id=current_user.id if current_user.role == UserRole.AGENT else None,
            subject=f"Live Chat Session #{conversation.id}",
            description=f"Agent {current_user.name} took over chat #{conversation.id}.",
            category="general_support",
            priority=TicketPriority.MEDIUM,
            status=TicketStatus.IN_PROGRESS
        )
        db.add(ticket)
        db.flush()
        conversation.ticket_id = ticket.id

    db.commit()
    db.refresh(conversation)
    if ticket:
        db.refresh(ticket)

    # Broadcast status change via WebSocket
    _ws_broadcast_status(
        background_tasks,
        conversation_id=conversation_id,
        ticket_id=conversation.ticket_id,
        status="human_support",
        ai_active=False,
    )

    return {
        "message": "Conversation successfully transferred to human support",
        "conversation": conversation,
        "ticket": ticket
    }


# ============================================================
# AGENT / ADMIN — HAND BACK TO AI ASSISTANT
# ============================================================

@router.patch("/{conversation_id}/handback")
@router.post("/{conversation_id}/handback")
def handback_conversation(
    conversation_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role not in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:
        raise HTTPException(
            status_code=403,
            detail="Only agents and administrators can hand back conversations to AI"
        )

    conversation = (
        db.query(Conversation)
        .filter(
            Conversation.id == conversation_id
        )
        .first()
    )

    if not conversation:
        raise HTTPException(
            status_code=404,
            detail="Conversation not found"
        )

    conversation.ai_active = True
    conversation.status = "active"
    conversation.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(conversation)

    # Broadcast status change via WebSocket
    _ws_broadcast_status(
        background_tasks,
        conversation_id=conversation_id,
        ticket_id=conversation.ticket_id,
        status="active",
        ai_active=True,
    )

    return {
        "message": "Conversation successfully returned to AI assistant",
        "conversation": conversation,
    }


# ============================================================
# CUSTOMER — REQUEST LIVE AGENT HANDOFF
# ============================================================

@router.post("/{conversation_id}/request-agent")
def request_live_agent(
    conversation_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    conversation = (
        db.query(Conversation)
        .filter(Conversation.id == conversation_id)
        .first()
    )

    if not conversation:
        raise HTTPException(
            status_code=404,
            detail="Conversation not found"
        )

    if current_user.role == UserRole.CUSTOMER and conversation.customer_id != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="You do not have access to this conversation"
        )

    # Asking for a human from inside Ask AI must not convert that thread -
    # the AI conversation stays intact and live support gets its own.
    if conversation.ticket_id is None:
        conversation = _live_conversation_for(db, conversation.customer_id)

    # The AI keeps answering while the customer waits, unless an agent has
    # already explicitly taken this conversation over.
    if not _human_has_taken_over(conversation):
        conversation.ai_active = True
        conversation.status = "active"
    conversation.updated_at = datetime.utcnow()

    ticket = None
    if conversation.ticket_id:
        ticket = db.query(Ticket).filter(Ticket.id == conversation.ticket_id).first()

    if not ticket:
        ticket = Ticket(
            customer_id=conversation.customer_id,
            conversation_id=conversation.id,
            subject=f"Live Support Request: Chat #{conversation.id}",
            description="Customer requested to connect with a live support agent.",
            category="general_support",
            priority=TicketPriority.HIGH,
            status=TicketStatus.OPEN
        )
        db.add(ticket)
        db.flush()

        initial_msg = TicketMessage(
            ticket_id=ticket.id,
            sender_id=current_user.id,
            sender_type="customer",
            content="Customer requested to speak with a human support specialist.",
            is_internal=False
        )
        db.add(initial_msg)

        conversation.ticket_id = ticket.id

    db.commit()
    db.refresh(conversation)
    if ticket:
        db.refresh(ticket)

    # Broadcast status change via WebSocket
    _ws_broadcast_status(
        background_tasks,
        conversation_id=conversation.id,
        ticket_id=conversation.ticket_id,
        status=conversation.status,
        ai_active=conversation.ai_active,
    )

    return {
        "message": "Connected to human support specialist",
        "conversation": conversation,
        "ticket": ticket
    }


# ============================================================
# CUSTOMER — GET OR CREATE LIVE AGENT SESSION (NAV PILL)
# ============================================================

@router.post("/live-agent/session")
def get_or_create_live_agent_session(
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.CUSTOMER:
        raise HTTPException(
            status_code=403,
            detail="Only customers can request live agent sessions"
        )

    # Never adopts the Ask AI thread - see _live_conversation_for().
    conversation = _live_conversation_for(db, current_user.id)

    if conversation.ticket_id:
        # Existing live thread: the AI stays on duty until an agent has
        # explicitly taken over.
        if not _human_has_taken_over(conversation):
            conversation.ai_active = True
            conversation.status = "active"
        conversation.updated_at = datetime.utcnow()

    ticket = None
    if conversation.ticket_id:
        ticket = db.query(Ticket).filter(Ticket.id == conversation.ticket_id).first()

    if not ticket:
        ticket = Ticket(
            customer_id=current_user.id,
            conversation_id=conversation.id,
            subject=f"Live Support Request: Chat #{conversation.id}",
            description="Customer connected with live support specialist.",
            category="general_support",
            priority=TicketPriority.HIGH,
            status=TicketStatus.OPEN
        )
        db.add(ticket)
        db.flush()

        initial_msg = TicketMessage(
            ticket_id=ticket.id,
            sender_id=current_user.id,
            sender_type="customer",
            content="Customer initiated live support specialist session.",
            is_internal=False
        )
        db.add(initial_msg)

        conversation.ticket_id = ticket.id

    db.commit()
    db.refresh(conversation)
    if ticket:
        db.refresh(ticket)

    # Broadcast status change via WebSocket
    _ws_broadcast_status(
        background_tasks,
        conversation_id=conversation.id,
        ticket_id=conversation.ticket_id,
        status=conversation.status,
        ai_active=conversation.ai_active,
    )

    return {
        "message": "Live agent session active",
        "conversation": conversation,
        "ticket": ticket
    }


# ============================================================
# WEBSOCKET BROADCAST HELPERS
# ============================================================

def _ws_broadcast_status(
    background_tasks: BackgroundTasks,
    *,
    conversation_id: int | None,
    ticket_id: int | None,
    status: str,
    ai_active: bool,
) -> None:
    """Queue a WebSocket status_change broadcast for after the response."""
    payload = {
        "event": "status_change",
        "conversation_id": conversation_id,
        "ticket_id": ticket_id,
        "status": status,
        "ai_active": ai_active,
    }

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