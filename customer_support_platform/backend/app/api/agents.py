from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database.models.conversation import Conversation
from app.api.auth import get_current_user
from app.database.connection import get_db
from app.database.models.ticket import (
    Ticket,
    TicketStatus,
    TicketPriority,
)
from app.database.models.user import User, UserRole


router = APIRouter(
    prefix="/agents",
    tags=["Agents"]
)


# ============================================================
# AGENT — GET CURRENT PROFILE
# ============================================================

@router.get("/me")
def get_agent_profile(
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.AGENT:
        raise HTTPException(
            status_code=403,
            detail="Only support agents can access this endpoint"
        )

    return {
        "id": current_user.id,
        "name": current_user.name,
        "email": current_user.email,
        "role": current_user.role,
        "is_active": current_user.is_active,
        "created_at": current_user.created_at,
        "updated_at": current_user.updated_at
    }


# ============================================================
# AGENT — GET MY ASSIGNED TICKETS
# ============================================================

@router.get("/tickets")
def get_my_tickets(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.AGENT:
        raise HTTPException(
            status_code=403,
            detail="Only support agents can access assigned tickets"
        )

    tickets = (
        db.query(Ticket)
        .filter(
            Ticket.assigned_agent_id == current_user.id
        )
        .order_by(
            Ticket.updated_at.desc()
        )
        .all()
    )

    return tickets


# ============================================================
# AGENT — GET UNASSIGNED TICKET QUEUE
# ============================================================

@router.get("/tickets/unassigned")
def get_unassigned_tickets(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role not in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:
        raise HTTPException(
            status_code=403,
            detail="Only agents and administrators can view the unassigned ticket queue"
        )

    tickets = (
        db.query(Ticket)
        .filter(
            Ticket.assigned_agent_id.is_(None)
        )
        .order_by(
            Ticket.priority.desc(),
            Ticket.updated_at.desc()
        )
        .all()
    )

    return tickets

# ============================================================
# AGENT — CLAIM TICKET
# ============================================================

@router.post("/tickets/{ticket_id}/claim")
def claim_ticket(
    ticket_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.AGENT:
        raise HTTPException(
            status_code=403,
            detail="Only support agents can claim tickets"
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

    if ticket.assigned_agent_id is not None:
        raise HTTPException(
            status_code=409,
            detail="Ticket is already assigned to an agent"
        )

    ticket.assigned_agent_id = current_user.id

    db.commit()
    db.refresh(ticket)

    return {
        "message": "Ticket successfully assigned to you",
        "ticket": ticket
    }
    
    # ============================================================
# AGENT — FILTER MY TICKETS
# ============================================================

@router.get("/tickets/filter")
def filter_my_tickets(
    status: TicketStatus | None = None,
    priority: TicketPriority | None = None,
    category: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.AGENT:
        raise HTTPException(
            status_code=403,
            detail="Only support agents can filter assigned tickets"
        )

    query = (
        db.query(Ticket)
        .filter(Ticket.assigned_agent_id == current_user.id)
    )

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
# AGENT — SEARCH MY TICKETS
# ============================================================

@router.get("/tickets/search")
def search_my_tickets(
    q: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.AGENT:
        raise HTTPException(
            status_code=403,
            detail="Only support agents can search assigned tickets"
        )

    search_term = f"%{q}%"

    tickets = (
        db.query(Ticket)
        .filter(
            Ticket.assigned_agent_id == current_user.id,
            (
                Ticket.subject.ilike(search_term)
                | Ticket.description.ilike(search_term)
                | Ticket.category.ilike(search_term)
            )
        )
        .order_by(Ticket.updated_at.desc())
        .all()
    )

    return tickets

# ============================================================
# AGENT — DASHBOARD STATISTICS
# ============================================================

@router.get("/dashboard/stats")
def get_agent_dashboard_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.AGENT:
        raise HTTPException(
            status_code=403,
            detail="Only support agents can access dashboard statistics"
        )

    query = db.query(Ticket).filter(
        Ticket.assigned_agent_id == current_user.id
    )

    total_tickets = query.count()

    open_tickets = query.filter(
        Ticket.status == TicketStatus.OPEN
    ).count()

    in_progress_tickets = query.filter(
        Ticket.status == TicketStatus.IN_PROGRESS
    ).count()

    waiting_for_customer = query.filter(
        Ticket.status == TicketStatus.WAITING_FOR_CUSTOMER
    ).count()

    resolved_tickets = query.filter(
        Ticket.status == TicketStatus.RESOLVED
    ).count()

    closed_tickets = query.filter(
        Ticket.status == TicketStatus.CLOSED
    ).count()

    high_priority = query.filter(
        Ticket.priority == TicketPriority.HIGH
    ).count()

    urgent_priority = query.filter(
        Ticket.priority == TicketPriority.URGENT
    ).count()

    return {
        "agent": {
            "id": current_user.id,
            "name": current_user.name,
            "email": current_user.email
        },
        "tickets": {
            "total": total_tickets,
            "open": open_tickets,
            "in_progress": in_progress_tickets,
            "waiting_for_customer": waiting_for_customer,
            "resolved": resolved_tickets,
            "closed": closed_tickets
        },
        "priority": {
            "high": high_priority,
            "urgent": urgent_priority
        }
    }
    
    # ============================================================
# AGENT — HUMAN SUPPORT CONVERSATIONS
# ============================================================

@router.get("/conversations")
def get_human_support_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role not in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:
        raise HTTPException(
            status_code=403,
            detail="Only agents and administrators can access support conversations"
        )

    conversations = (
        db.query(Conversation)
        .filter(
            Conversation.ai_active == False,
            Conversation.status == "human_support"
        )
        .order_by(
            Conversation.updated_at.desc()
        )
        .all()
    )

    return conversations

# ============================================================
# AGENT — WORKLOAD
# ============================================================

@router.get("/workload")
def get_agent_workload(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role not in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:
        raise HTTPException(
            status_code=403,
            detail="Only agents and administrators can view agent workload"
        )

    agents = (
        db.query(User)
        .filter(
            User.role == UserRole.AGENT,
            User.is_active == True
        )
        .order_by(User.name.asc())
        .all()
    )

    workload = []

    for agent in agents:
        assigned_count = (
            db.query(Ticket)
            .filter(
                Ticket.assigned_agent_id == agent.id
            )
            .count()
        )

        workload.append({
            "agent_id": agent.id,
            "name": agent.name,
            "email": agent.email,
            "assigned_tickets": assigned_count
        })

    return workload

# ============================================================
# AGENT / ADMIN — ASSIGN TICKET
# ============================================================

@router.patch("/tickets/{ticket_id}/assign")
def assign_ticket(
    ticket_id: int,
    agent_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role not in {
        UserRole.AGENT,
        UserRole.ADMIN
    }:
        raise HTTPException(
            status_code=403,
            detail="Only agents and administrators can assign tickets"
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

    agent = (
        db.query(User)
        .filter(
            User.id == agent_id,
            User.role == UserRole.AGENT,
            User.is_active == True
        )
        .first()
    )

    if not agent:
        raise HTTPException(
            status_code=400,
            detail="Assigned user is not a valid active support agent"
        )

    ticket.assigned_agent_id = agent.id

    db.commit()
    db.refresh(ticket)

    return {
        "message": "Ticket successfully assigned",
        "ticket": ticket
    }