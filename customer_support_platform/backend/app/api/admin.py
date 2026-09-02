from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session


from app.database.models.message import Message
from app.api.auth import get_current_user
from app.database.connection import get_db
from app.database.models.user import User, UserRole
from app.database.models.ticket import (
    Ticket,
    TicketStatus,
    TicketPriority,
)
from app.database.models.conversation import Conversation
router = APIRouter(
    prefix="/admin",
    tags=["Admin"]
)


# ============================================================
# ADMIN — GET ALL USERS
# ============================================================

@router.get("/users")
def get_all_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Only administrators can view users"
        )

    users = (
        db.query(User)
        .order_by(User.created_at.desc())
        .all()
    )

    return [
        {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "role": user.role,
            "is_active": user.is_active,
            "created_at": user.created_at,
            "updated_at": user.updated_at
        }
        for user in users
    ]


# ============================================================
# ADMIN — GET SINGLE USER
# ============================================================

@router.get("/users/{user_id}")
def get_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Only administrators can view users"
        )

    user = (
        db.query(User)
        .filter(User.id == user_id)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )

    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "role": user.role,
        "is_active": user.is_active,
        "created_at": user.created_at,
        "updated_at": user.updated_at
    }


# ============================================================
# ADMIN — ACTIVATE / DEACTIVATE USER
# ============================================================

@router.patch("/users/{user_id}/status")
def update_user_status(
    user_id: int,
    is_active: bool,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Only administrators can change user status"
        )

    user = (
        db.query(User)
        .filter(User.id == user_id)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )

    if user.id == current_user.id and not is_active:
        raise HTTPException(
            status_code=400,
            detail="Administrators cannot deactivate their own account"
        )

    user.is_active = is_active

    db.commit()
    db.refresh(user)

    return {
        "message": "User status updated successfully",
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "role": user.role,
            "is_active": user.is_active
        }
    }


# ============================================================
# ADMIN — CHANGE USER ROLE
# ============================================================

@router.patch("/users/{user_id}/role")
def update_user_role(
    user_id: int,
    role: UserRole,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Only administrators can change user roles"
        )

    user = (
        db.query(User)
        .filter(User.id == user_id)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )

    if user.id == current_user.id and role != UserRole.ADMIN:
        raise HTTPException(
            status_code=400,
            detail="Administrators cannot remove their own administrator role"
        )

    user.role = role

    db.commit()
    db.refresh(user)

    return {
        "message": "User role updated successfully",
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "role": user.role,
            "is_active": user.is_active
        }
    }
    
    # ============================================================
# ADMIN — GET ALL AGENTS
# ============================================================

@router.get("/agents")
def get_all_agents(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Only administrators can view agents"
        )

    agents = (
        db.query(User)
        .filter(User.role == UserRole.AGENT)
        .order_by(User.created_at.desc())
        .all()
    )

    return [
        {
            "id": agent.id,
            "name": agent.name,
            "email": agent.email,
            "role": agent.role,
            "is_active": agent.is_active,
            "created_at": agent.created_at,
            "updated_at": agent.updated_at
        }
        for agent in agents
    ]
    
    # ============================================================
# ADMIN — GET AGENT DETAILS
# ============================================================

@router.get("/agents/{agent_id}")
def get_agent_details(
    agent_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Only administrators can view agent details"
        )

    agent = (
        db.query(User)
        .filter(
            User.id == agent_id,
            User.role == UserRole.AGENT
        )
        .first()
    )

    if not agent:
        raise HTTPException(
            status_code=404,
            detail="Agent not found"
        )

    assigned_tickets = (
        db.query(Ticket)
        .filter(
            Ticket.assigned_agent_id == agent.id
        )
        .count()
    )

    return {
        "id": agent.id,
        "name": agent.name,
        "email": agent.email,
        "role": agent.role,
        "is_active": agent.is_active,
        "assigned_tickets": assigned_tickets,
        "created_at": agent.created_at,
        "updated_at": agent.updated_at
    }
    
    
    # ============================================================
# ADMIN — TICKET MANAGEMENT
# ============================================================

@router.get("/tickets")
def get_admin_tickets(
    status: TicketStatus | None = None,
    priority: TicketPriority | None = None,
    category: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Only administrators can manage tickets"
        )

    query = db.query(Ticket)

    if status is not None:
        query = query.filter(Ticket.status == status)

    if priority is not None:
        query = query.filter(Ticket.priority == priority)

    if category is not None:
        query = query.filter(Ticket.category == category)

    return (
        query
        .order_by(Ticket.updated_at.desc())
        .all()
    )
    
    
    # ============================================================
# ADMIN — SYSTEM STATISTICS
# ============================================================

@router.get("/dashboard/stats")
def get_admin_dashboard_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Only administrators can access system statistics"
        )

    # --------------------------------------------------------
    # USER STATISTICS
    # --------------------------------------------------------

    total_users = db.query(User).count()

    total_customers = (
        db.query(User)
        .filter(User.role == UserRole.CUSTOMER)
        .count()
    )

    total_agents = (
        db.query(User)
        .filter(User.role == UserRole.AGENT)
        .count()
    )

    active_users = (
        db.query(User)
        .filter(User.is_active == True)
        .count()
    )

    inactive_users = (
        db.query(User)
        .filter(User.is_active == False)
        .count()
    )

    # --------------------------------------------------------
    # TICKET STATISTICS
    # --------------------------------------------------------

    total_tickets = db.query(Ticket).count()

    open_tickets = (
        db.query(Ticket)
        .filter(Ticket.status == TicketStatus.OPEN)
        .count()
    )

    in_progress_tickets = (
        db.query(Ticket)
        .filter(Ticket.status == TicketStatus.IN_PROGRESS)
        .count()
    )

    waiting_tickets = (
        db.query(Ticket)
        .filter(Ticket.status == TicketStatus.WAITING_FOR_CUSTOMER)
        .count()
    )

    resolved_tickets = (
        db.query(Ticket)
        .filter(Ticket.status == TicketStatus.RESOLVED)
        .count()
    )

    closed_tickets = (
        db.query(Ticket)
        .filter(Ticket.status == TicketStatus.CLOSED)
        .count()
    )

    # --------------------------------------------------------
    # CONVERSATION STATISTICS
    # --------------------------------------------------------

    total_conversations = db.query(Conversation).count()

    ai_active_conversations = (
        db.query(Conversation)
        .filter(Conversation.ai_active == True)
        .count()
    )

    human_support_conversations = (
        db.query(Conversation)
        .filter(Conversation.ai_active == False)
        .count()
    )

    return {
        "users": {
            "total": total_users,
            "customers": total_customers,
            "agents": total_agents,
            "active": active_users,
            "inactive": inactive_users
        },
        "tickets": {
            "total": total_tickets,
            "open": open_tickets,
            "in_progress": in_progress_tickets,
            "waiting_for_customer": waiting_tickets,
            "resolved": resolved_tickets,
            "closed": closed_tickets
        },
        "conversations": {
            "total": total_conversations,
            "ai_active": ai_active_conversations,
            "human_support": human_support_conversations
        }
    }
    
    
    # ============================================================
# ADMIN — AI ANALYTICS
# ============================================================

@router.get("/ai/analytics")
def get_ai_analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Only administrators can access AI analytics"
        )

    # --------------------------------------------------------
    # AI MESSAGE STATISTICS
    # --------------------------------------------------------

    ai_messages = (
        db.query(Message)
        .filter(Message.sender_type == "ai")
        .all()
    )

    total_ai_messages = len(ai_messages)

    confidence_values = [
        message.confidence
        for message in ai_messages
        if message.confidence is not None
    ]

    average_confidence = (
        sum(confidence_values) / len(confidence_values)
        if confidence_values
        else 0
    )

    low_confidence_messages = sum(
        1
        for confidence in confidence_values
        if confidence < 0.70
    )

    # --------------------------------------------------------
    # INTENT DISTRIBUTION
    # --------------------------------------------------------

    intent_distribution = {}

    for message in ai_messages:
        if message.intent:
            intent_distribution[message.intent] = (
                intent_distribution.get(message.intent, 0) + 1
            )

    # --------------------------------------------------------
    # CONVERSATION STATISTICS
    # --------------------------------------------------------

    total_conversations = db.query(Conversation).count()

    ai_active_conversations = (
        db.query(Conversation)
        .filter(Conversation.ai_active == True)
        .count()
    )

    human_support_conversations = (
        db.query(Conversation)
        .filter(Conversation.ai_active == False)
        .count()
    )

    escalation_rate = (
        human_support_conversations / total_conversations
        if total_conversations
        else 0
    )

    return {
        "ai_messages": {
            "total": total_ai_messages,
            "average_confidence": round(average_confidence, 4),
            "low_confidence": low_confidence_messages
        },
        "intent_distribution": intent_distribution,
        "conversations": {
            "total": total_conversations,
            "ai_active": ai_active_conversations,
            "human_support": human_support_conversations,
            "escalation_rate": round(escalation_rate, 4)
        }
    }