from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models.message import Message
from app.database.models.conversation import Conversation
from app.database.models.user import User, UserRole
from app.database.models.ticket import Ticket, TicketStatus, TicketPriority
from app.database.models.ticket_message import TicketMessage
from app.api.auth import get_current_user
from app.services.ai_service import generate_ai_response
from app.services.knowledge_service import retrieve_context


router = APIRouter(
    prefix="/conversations",
    tags=["Messages"]
)


# ============================================================
# REQUEST MODEL
# ============================================================

class MessageCreate(BaseModel):
    content: str = Field(
        ...,
        min_length=1,
        max_length=5000
    )


# ============================================================
# SEND MESSAGE
# ============================================================

@router.post("/{conversation_id}/messages")
def send_message(
    conversation_id: int,
    message_data: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):

    content = message_data.content.strip()

    if not content:
        raise HTTPException(
            status_code=400,
            detail="Message cannot be empty"
        )

    # --------------------------------------------------
    # 1. FIND CONVERSATION
    # --------------------------------------------------

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

    # --------------------------------------------------
    # 2. CUSTOMER MESSAGE
    # --------------------------------------------------

    if current_user.role == UserRole.CUSTOMER:

        # Customer can only access own conversation
        if conversation.customer_id != current_user.id:
            raise HTTPException(
                status_code=403,
                detail="You do not have access to this conversation"
            )

        # --------------------------------------------------
        # HUMAN SUPPORT HAS TAKEN OVER
        # --------------------------------------------------

        if not conversation.ai_active:

            customer_message = Message(
                conversation_id=conversation_id,
                sender_type="customer",
                content=content
            )

            db.add(customer_message)

            # Mirror to linked ticket if exists so ticket thread is updated
            if conversation.ticket_id:
                ticket_msg = TicketMessage(
                    ticket_id=conversation.ticket_id,
                    sender_id=current_user.id,
                    sender_type="customer",
                    content=content,
                    is_internal=False
                )
                db.add(ticket_msg)
                ticket = db.query(Ticket).filter(Ticket.id == conversation.ticket_id).first()
                if ticket:
                    ticket.updated_at = datetime.utcnow()

            conversation.updated_at = datetime.utcnow()

            db.commit()
            db.refresh(customer_message)

            return {
                "customer_message": customer_message,
                "ai_message": None,
                "escalated": False,
                "message": "Message sent to human support"
            }

    # --------------------------------------------------
    # 3. AGENT / ADMIN MESSAGE
    # --------------------------------------------------

    elif current_user.role in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:

        human_message = Message(
            conversation_id=conversation_id,
            sender_type=(
                "agent"
                if current_user.role == UserRole.AGENT
                else "admin"
            ),
            content=content
        )

        db.add(human_message)

        # Human has control of conversation
        conversation.ai_active = False
        conversation.status = "human_support"
        conversation.updated_at = datetime.utcnow()

        # Mirror to linked ticket if exists so agent reply appears on ticket
        if conversation.ticket_id:
            ticket_msg = TicketMessage(
                ticket_id=conversation.ticket_id,
                sender_id=current_user.id,
                sender_type=(
                    "agent"
                    if current_user.role == UserRole.AGENT
                    else "admin"
                ),
                content=content,
                is_internal=False
            )
            db.add(ticket_msg)
            ticket = db.query(Ticket).filter(Ticket.id == conversation.ticket_id).first()
            if ticket:
                ticket.updated_at = datetime.utcnow()

        db.commit()
        db.refresh(human_message)

        return {
            "human_message": human_message,
            "message": "Message sent to customer"
        }

    else:

        raise HTTPException(
            status_code=403,
            detail="You do not have permission to send messages"
        )

    # --------------------------------------------------
    # 4. GET PREVIOUS MESSAGES (Bounded Sliding Window)
    # --------------------------------------------------

    recent_messages = (
        db.query(Message)
        .filter(
            Message.conversation_id == conversation_id
        )
        .order_by(
            Message.created_at.desc()
        )
        .limit(10)
        .all()
    )

    conversation_history = [
        {
            "sender_type": msg.sender_type,
            "content": msg.content
        }
        for msg in reversed(recent_messages)
    ]

    # --------------------------------------------------
    # 5. SAVE CUSTOMER MESSAGE
    # --------------------------------------------------

    customer_message = Message(
        conversation_id=conversation_id,
        sender_type="customer",
        content=content
    )

    db.add(customer_message)

    db.commit()
    db.refresh(customer_message)

    # --------------------------------------------------
    # 6. RETRIEVE KNOWLEDGE-BASE CONTEXT (RAG)
    # --------------------------------------------------
    # Search the knowledge base for passages relevant to this message and
    # hand them to the model as grounding. Retrieval failures must never
    # block a reply, so fall back to an un-grounded answer.

    try:
        kb_context, kb_sources = retrieve_context(db, content)
    except Exception as exc:  # noqa: BLE001
        print(f"KB retrieval failed: {exc}")
        kb_context, kb_sources = None, []

    # --------------------------------------------------
    # 7. GENERATE AI RESPONSE
    # --------------------------------------------------

    ai_result = generate_ai_response(
        message=content,
        conversation_history=conversation_history,
        context=kb_context,
    )

    # --------------------------------------------------
    # 8. SAVE AI RESPONSE (with the articles it cited)
    # --------------------------------------------------

    ai_message = Message(
        conversation_id=conversation_id,
        sender_type="ai",
        content=ai_result["response"],
        intent=ai_result["intent"],
        confidence=ai_result["confidence"],
        sources=kb_sources or None,
    )

    db.add(ai_message)

    # --------------------------------------------------
    # 9. CHECK AI CONFIDENCE
    # --------------------------------------------------

    should_escalate = ai_result.get(
        "should_escalate",
        False
    )

    if should_escalate:

        # ----------------------------------------------
        # AI HANDS CONVERSATION TO HUMAN
        # ----------------------------------------------

        conversation.ai_active = False
        conversation.status = "human_support"
        conversation.updated_at = datetime.utcnow()

        # ----------------------------------------------
        # CREATE SUPPORT TICKET
        # ----------------------------------------------

        ticket = Ticket(
            customer_id=current_user.id,
            conversation_id=conversation.id,
            subject=f"AI Escalation: {ai_result['intent']}",
            description=content,
            category=ai_result["intent"],
            priority=TicketPriority.MEDIUM,
            status=TicketStatus.OPEN
        )

        db.add(ticket)

        db.flush()

        conversation.ticket_id = ticket.id

        # ----------------------------------------------
        # ADD CUSTOMER MESSAGE TO TICKET
        # ----------------------------------------------

        ticket_message = TicketMessage(
            ticket_id=ticket.id,
            sender_id=current_user.id,
            sender_type="customer",
            content=content,
            is_internal=False
        )

        db.add(ticket_message)

        db.commit()

        db.refresh(ai_message)
        db.refresh(ticket)

        return {
            "customer_message": customer_message,
            "ai_message": ai_message,
            "sources": kb_sources,
            "ticket": ticket,
            "escalated": True,
            "message": (
                "Your request has been escalated to human support."
            )
        }

    # --------------------------------------------------
    # 10. NORMAL AI RESPONSE
    # --------------------------------------------------

    conversation.updated_at = datetime.utcnow()

    db.commit()

    db.refresh(ai_message)

    return {
        "customer_message": customer_message,
        "ai_message": ai_message,
        "sources": kb_sources,
        "escalated": False
    }


# ============================================================
# GET CONVERSATION MESSAGES
# ============================================================

@router.get("/{conversation_id}/messages")
def get_messages(
    conversation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):

    # --------------------------------------------------
    # 1. FIND CONVERSATION
    # --------------------------------------------------

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

    # --------------------------------------------------
    # 2. AUTHORIZATION
    # --------------------------------------------------

    if current_user.role == UserRole.CUSTOMER:

        if conversation.customer_id != current_user.id:
            raise HTTPException(
                status_code=403,
                detail="You do not have access to this conversation"
            )

    elif current_user.role not in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:

        raise HTTPException(
            status_code=403,
            detail="You do not have permission to view this conversation"
        )

    # --------------------------------------------------
    # 3. GET MESSAGES
    # --------------------------------------------------

    messages = (
        db.query(Message)
        .filter(
            Message.conversation_id == conversation_id
        )
        .order_by(
            Message.created_at.asc()
        )
        .all()
    )

    return messages