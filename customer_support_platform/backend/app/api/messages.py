from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models.message import Message
from app.database.models.conversation import Conversation
from app.database.models.user import User, UserRole
from app.api.auth import get_current_user
from app.services.ai_service import generate_ai_response


router = APIRouter(
    prefix="/conversations",
    tags=["Messages"]
)


# ============================================================
# SEND MESSAGE
# ============================================================

@router.post("/{conversation_id}/messages")
def send_message(
    conversation_id: int,
    content: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):

    # --------------------------------------------------
    # 1. Find conversation
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

        # If AI has been taken over by a human,
        # don't generate another AI response.
        if not conversation.ai_active:

            customer_message = Message(
                conversation_id=conversation_id,
                sender_type="customer",
                content=content
            )

            db.add(customer_message)

            conversation.updated_at = customer_message.created_at

            db.commit()
            db.refresh(customer_message)

            return {
                "customer_message": customer_message,
                "ai_message": None,
                "message": "Message sent to human support"
            }

    # --------------------------------------------------
    # 3. AGENT / ADMIN MESSAGE
    # --------------------------------------------------

    elif current_user.role in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:

        # Human response
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
        conversation.updated_at = human_message.created_at

        db.commit()
        db.refresh(human_message)

        return {
            "human_message": human_message
        }

    else:
        raise HTTPException(
            status_code=403,
            detail="You do not have permission to send messages"
        )

    # --------------------------------------------------
    # 4. GET PREVIOUS MESSAGES
    # --------------------------------------------------

    previous_messages = (
        db.query(Message)
        .filter(
            Message.conversation_id == conversation_id
        )
        .order_by(
            Message.created_at.asc()
        )
        .all()
    )

    conversation_history = []

    for msg in previous_messages:

        conversation_history.append({
            "sender_type": msg.sender_type,
            "content": msg.content
        })

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
    # 6. GENERATE AI RESPONSE
    # --------------------------------------------------

    ai_result = generate_ai_response(
        message=content,
        conversation_history=conversation_history
    )

    # --------------------------------------------------
    # 7. SAVE AI RESPONSE
    # --------------------------------------------------

    ai_message = Message(
        conversation_id=conversation_id,
        sender_type="ai",
        content=ai_result["response"],
        intent=ai_result["intent"],
        confidence=ai_result["confidence"]
    )

    db.add(ai_message)

    conversation.updated_at = customer_message.created_at

    db.commit()
    db.refresh(ai_message)

    # --------------------------------------------------
    # 8. RETURN
    # --------------------------------------------------

    return {
        "customer_message": customer_message,
        "ai_message": ai_message
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
    # 1. Find conversation
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
    # 2. Authorization
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
    # 3. Get messages
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