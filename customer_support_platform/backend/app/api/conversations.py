from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models.conversation import Conversation
from app.database.models.ticket import Ticket, TicketStatus, TicketPriority
from app.database.models.ticket_message import TicketMessage
from app.database.models.user import User, UserRole
from app.api.auth import get_current_user


router = APIRouter(
    prefix="/conversations",
    tags=["Conversations"]
)


# ============================================================
# CUSTOMER — CREATE CONVERSATION
# ============================================================

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

@router.patch("/{conversation_id}/takeover")
def takeover_conversation(
    conversation_id: int,
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

    return {
        "message": "Conversation successfully transferred to human support",
        "conversation": conversation,
        "ticket": ticket
    }


# ============================================================
# CUSTOMER — REQUEST LIVE AGENT HANDOFF
# ============================================================

@router.post("/{conversation_id}/request-agent")
def request_live_agent(
    conversation_id: int,
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

    conversation.ai_active = False
    conversation.status = "human_support"
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
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.CUSTOMER:
        raise HTTPException(
            status_code=403,
            detail="Only customers can request live agent sessions"
        )

    conversation = (
        db.query(Conversation)
        .filter(Conversation.customer_id == current_user.id)
        .order_by(Conversation.updated_at.desc())
        .first()
    )

    if not conversation:
        conversation = Conversation(
            customer_id=current_user.id,
            status="human_support",
            ai_active=False
        )
        db.add(conversation)
        db.flush()
    else:
        conversation.ai_active = False
        conversation.status = "human_support"
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

    return {
        "message": "Live agent session active",
        "conversation": conversation,
        "ticket": ticket
    }