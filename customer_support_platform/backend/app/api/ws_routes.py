"""
WebSocket endpoints for real-time conversation and ticket updates.

Clients connect via:
  ws://<host>/api/v1/ws/conversations/{id}?token=<jwt>
  ws://<host>/api/v1/ws/tickets/{id}?token=<jwt>

JWT is validated on handshake; invalid tokens close the socket with 4001.
Once connected, the server pushes JSON events (new_message, status_change)
and the client can send a ping/heartbeat to keep the connection alive.
"""

from __future__ import annotations

import logging

import jwt as pyjwt
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.config import settings
from app.database.connection import SessionLocal
from app.database.models.user import User, UserRole
from app.database.models.conversation import Conversation
from app.database.models.ticket import Ticket
from app.websocket_manager import manager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ws", tags=["WebSocket"])

ALGORITHM = "HS256"


# ------------------------------------------------------------------
# JWT HELPER — validates the token passed as a query parameter
# ------------------------------------------------------------------

def _authenticate_ws(token: str | None, db: Session) -> User | None:
    """Return the User for a valid JWT, or None."""
    if not token:
        return None
    try:
        payload = pyjwt.decode(
            token, settings.JWT_SECRET_KEY, algorithms=[ALGORITHM]
        )
        user_id = payload.get("sub")
        if user_id is None:
            return None
        user = db.query(User).filter(User.id == int(user_id)).first()
        if user is None or not user.is_active:
            return None
        return user
    except Exception:
        return None


def _get_ws_db() -> Session:
    """Return a db session, respecting app.dependency_overrides[get_db] if set (e.g. in tests)."""
    from app.database.connection import get_db
    from app.main import app
    if get_db in app.dependency_overrides:
        override = app.dependency_overrides[get_db]
        gen = override()
        return next(gen)
    return SessionLocal()


# ------------------------------------------------------------------
# CONVERSATION WEBSOCKET
# ------------------------------------------------------------------

@router.websocket("/conversations/{conversation_id}")
async def ws_conversation(websocket: WebSocket, conversation_id: int):
    token = websocket.query_params.get("token")
    db: Session = _get_ws_db()

    try:
        user = _authenticate_ws(token, db)
        if user is None:
            await websocket.close(code=4001, reason="Authentication failed")
            return

        # Authorization: customers can only watch their own conversations
        conversation = (
            db.query(Conversation)
            .filter(Conversation.id == conversation_id)
            .first()
        )
        if not conversation:
            await websocket.close(code=4004, reason="Conversation not found")
            return

        if (
            user.role == UserRole.CUSTOMER
            and conversation.customer_id != user.id
        ):
            await websocket.close(code=4003, reason="Access denied")
            return

        await manager.connect_conversation(websocket, conversation_id, user.id)

        # Keep socket alive; we mostly push from server side.
        # Client can send heartbeat pings or ignore.
        try:
            while True:
                data = await websocket.receive_text()
                # Clients can send {"type": "ping"} for keepalive
                if data.strip():
                    logger.debug(
                        "WS recv from user %s on conv %s: %s",
                        user.id,
                        conversation_id,
                        data[:200],
                    )
        except WebSocketDisconnect:
            pass
        finally:
            manager.disconnect_conversation(websocket, conversation_id, user.id)

    finally:
        db.close()


# ------------------------------------------------------------------
# TICKET WEBSOCKET
# ------------------------------------------------------------------

@router.websocket("/tickets/{ticket_id}")
async def ws_ticket(websocket: WebSocket, ticket_id: int):
    token = websocket.query_params.get("token")
    db: Session = _get_ws_db()

    try:
        user = _authenticate_ws(token, db)
        if user is None:
            await websocket.close(code=4001, reason="Authentication failed")
            return

        ticket = db.query(Ticket).filter(Ticket.id == ticket_id).first()
        if not ticket:
            await websocket.close(code=4004, reason="Ticket not found")
            return

        if (
            user.role == UserRole.CUSTOMER
            and ticket.customer_id != user.id
        ):
            await websocket.close(code=4003, reason="Access denied")
            return

        await manager.connect_ticket(websocket, ticket_id, user.id)

        try:
            while True:
                data = await websocket.receive_text()
                if data.strip():
                    logger.debug(
                        "WS recv from user %s on ticket %s: %s",
                        user.id,
                        ticket_id,
                        data[:200],
                    )
        except WebSocketDisconnect:
            pass
        finally:
            manager.disconnect_ticket(websocket, ticket_id, user.id)

    finally:
        db.close()
