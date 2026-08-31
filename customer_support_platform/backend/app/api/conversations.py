from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models.conversation import Conversation
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

    db.commit()
    db.refresh(conversation)

    return {
        "message": "Conversation successfully transferred to human support",
        "conversation": conversation
    }