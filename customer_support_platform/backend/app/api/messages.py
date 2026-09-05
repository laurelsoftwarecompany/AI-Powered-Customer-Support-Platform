from datetime import datetime

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
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
from app.websocket_manager import manager as ws_manager


router = APIRouter(
    prefix="/conversations",
    tags=["Messages"]
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
    background_tasks: BackgroundTasks,
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

        # Ask AI (ticket_id IS NULL) is a pure-AI surface: it answers every
        # time, whatever ai_active says. Only ticket-linked live
        # conversations can be routed to a human.
        if not conversation.ai_active and conversation.ticket_id is not None:

            customer_message = Message(
                conversation_id=conversation_id,
                sender_type="customer",
                sender_name=current_user.name,
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

            # Broadcast via WebSocket
            _ws_broadcast(
                background_tasks,
                conversation_id=conversation_id,
                ticket_id=conversation.ticket_id,
                event="new_message",
                message=_msg_payload(customer_message),
            )

            return {
                "customer_message": customer_message,
                "ai_message": None,
                "escalated": False,
                "message": "Message delivered to support specialists"
            }

    # --------------------------------------------------
    # 3. AGENT / ADMIN MESSAGE
    # --------------------------------------------------

    elif current_user.role in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:

        was_ai_active = conversation.ai_active

        human_message = Message(
            conversation_id=conversation_id,
            sender_type=(
                "agent"
                if current_user.role == UserRole.AGENT
                else "admin"
            ),
            sender_name=current_user.name or "Support Specialist",
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

        # Broadcast via WebSocket
        _ws_broadcast(
            background_tasks,
            conversation_id=conversation_id,
            ticket_id=conversation.ticket_id,
            event="new_message",
            message=_msg_payload(human_message),
        )

        # Broadcast takeover status change to both web and mobile if AI was previously active
        if was_ai_active:
            _ws_broadcast(
                background_tasks,
                conversation_id=conversation_id,
                ticket_id=conversation.ticket_id,
                event="status_change",
                status="human_support",
                ai_active=False,
            )

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
        sender_name=current_user.name,
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

    db.commit()
    db.refresh(customer_message)

    # Push the customer's own message straight away.
    _ws_broadcast(
        background_tasks,
        conversation_id=conversation_id,
        ticket_id=conversation.ticket_id,
        event="new_message",
        message=_msg_payload(customer_message),
    )

    # --------------------------------------------------
    # 6. RETRIEVE KNOWLEDGE-BASE CONTEXT (RAG)
    # --------------------------------------------------

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

    ai_content = ai_result["response"]
    should_escalate = ai_result.get("should_escalate", False)

    # --------------------------------------------------
    # 8. PROCESS BY CONVERSATION TYPE
    # --------------------------------------------------

    # CASE A: STANDALONE ASK AI (ticket_id is None)
    # Pure AI Assistant: Never auto-creates tickets or hands off
    if conversation.ticket_id is None:
        if should_escalate:
            ai_content += (
                "\n\n*(If you need personalized live assistance with your account or issue, "
                "please create a support ticket in the Live Agent section.)*"
            )

        ai_message = Message(
            conversation_id=conversation_id,
            sender_type="ai",
            sender_name="Laurel AI Assistant",
            content=ai_content,
            intent=ai_result["intent"],
            confidence=ai_result["confidence"],
            sources=kb_sources or None,
        )
        db.add(ai_message)
        conversation.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(ai_message)

        _ws_broadcast(
            background_tasks,
            conversation_id=conversation_id,
            ticket_id=None,
            event="new_message",
            message=_msg_payload(ai_message),
        )

        return {
            "customer_message": customer_message,
            "ai_message": ai_message,
            "sources": kb_sources,
            "escalated": False,
            "suggested_action": "create_ticket" if should_escalate else None,
        }

    # CASE B: TICKET LIVE CHAT (ticket_id is not None)
    # The AI acts as first responder on the ticket
    ai_message = Message(
        conversation_id=conversation_id,
        sender_type="ai",
        sender_name="Laurel AI Assistant",
        content=ai_content,
        intent=ai_result["intent"],
        confidence=ai_result["confidence"],
        sources=kb_sources or None,
    )
    db.add(ai_message)

    ai_user = get_or_create_ai_user(db)
    ai_ticket_msg = TicketMessage(
        ticket_id=conversation.ticket_id,
        sender_id=ai_user.id,
        sender_type="ai",
        content=ai_content,
        sources=kb_sources or None,
        is_internal=False,
    )
    db.add(ai_ticket_msg)

    conversation.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(ai_message)
    db.refresh(ai_ticket_msg)

    # Broadcast AI reply via WebSocket to both conversation and ticket
    _ws_broadcast(
        background_tasks,
        conversation_id=conversation_id,
        ticket_id=conversation.ticket_id,
        event="new_message",
        message=_msg_payload(ai_message),
    )

    return {
        "customer_message": customer_message,
        "ai_message": ai_message,
        "sources": kb_sources,
        "escalated": False,
        "ticket_id": conversation.ticket_id,
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

    def _format_sender(m: Message) -> str:
        if m.sender_name:
            return m.sender_name
        if m.sender_type == "ai":
            return "Laurel AI Assistant"
        if m.sender_type in ("agent", "admin"):
            return "Support Specialist"
        return "Customer"

    return [
        {
            "id": m.id,
            "conversation_id": m.conversation_id,
            "sender_type": m.sender_type,
            "sender_name": _format_sender(m),
            "content": m.content,
            "intent": m.intent,
            "confidence": m.confidence,
            "sources": m.sources,
            "created_at": m.created_at.isoformat() if m.created_at else None,
        }
        for m in messages
    ]


# ============================================================
# WEBSOCKET BROADCAST HELPERS
# ============================================================

def _msg_payload(msg: Message) -> dict:
    """Serialize a Message ORM object to a dict suitable for WS broadcast."""
    sender_name = getattr(msg, "sender_name", None)
    if not sender_name:
        if msg.sender_type == "ai":
            sender_name = "Laurel AI Assistant"
        elif msg.sender_type in ("agent", "admin"):
            sender_name = "Support Specialist"
        else:
            sender_name = "Customer"

    return {
        "id": msg.id,
        "conversation_id": msg.conversation_id,
        "sender_type": msg.sender_type,
        "sender_name": sender_name,
        "content": msg.content,
        "intent": getattr(msg, "intent", None),
        "confidence": getattr(msg, "confidence", None),
        "sources": getattr(msg, "sources", None),
        "created_at": msg.created_at.isoformat() if msg.created_at else None,
    }


def _ws_broadcast(
    background_tasks: BackgroundTasks,
    *,
    conversation_id: int | None,
    ticket_id: int | None,
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