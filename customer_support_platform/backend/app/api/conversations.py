from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models.conversation import Conversation
from app.api.auth import get_current_user
from app.database.models.user import User


router = APIRouter(
    prefix="/conversations",
    tags=["Conversations"]
)


@router.post("/")
def create_conversation(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    conversation = Conversation(
        customer_id=current_user.id,
        status="active",
        ai_active=True
    )

    db.add(conversation)
    db.commit()
    db.refresh(conversation)

    return conversation