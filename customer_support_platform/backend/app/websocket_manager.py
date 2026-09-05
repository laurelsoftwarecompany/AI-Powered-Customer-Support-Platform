"""
Central WebSocket connection manager.

Tracks active WebSocket connections per conversation or ticket and
broadcasts JSON messages to every connected client in a given room.
"""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime
from typing import Any

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class ConnectionManager:
    """Manages WebSocket connections grouped by conversation and ticket IDs."""

    def __init__(self) -> None:
        # conversation_id -> set of (WebSocket, user_id)
        self._conversation_connections: dict[int, set[tuple[WebSocket, int]]] = {}
        # ticket_id -> set of (WebSocket, user_id)
        self._ticket_connections: dict[int, set[tuple[WebSocket, int]]] = {}

    # ------------------------------------------------------------------
    # CONNECTION LIFECYCLE
    # ------------------------------------------------------------------

    async def connect_conversation(
        self, websocket: WebSocket, conversation_id: int, user_id: int
    ) -> None:
        await websocket.accept()
        room = self._conversation_connections.setdefault(conversation_id, set())
        room.add((websocket, user_id))
        logger.info(
            "WS connect: user %s joined conversation %s (%d active)",
            user_id,
            conversation_id,
            len(room),
        )

    async def connect_ticket(
        self, websocket: WebSocket, ticket_id: int, user_id: int
    ) -> None:
        await websocket.accept()
        room = self._ticket_connections.setdefault(ticket_id, set())
        room.add((websocket, user_id))
        logger.info(
            "WS connect: user %s joined ticket %s (%d active)",
            user_id,
            ticket_id,
            len(room),
        )

    def disconnect_conversation(
        self, websocket: WebSocket, conversation_id: int, user_id: int
    ) -> None:
        room = self._conversation_connections.get(conversation_id)
        if room:
            room.discard((websocket, user_id))
            if not room:
                del self._conversation_connections[conversation_id]
        logger.info(
            "WS disconnect: user %s left conversation %s", user_id, conversation_id
        )

    def disconnect_ticket(
        self, websocket: WebSocket, ticket_id: int, user_id: int
    ) -> None:
        room = self._ticket_connections.get(ticket_id)
        if room:
            room.discard((websocket, user_id))
            if not room:
                del self._ticket_connections[ticket_id]
        logger.info("WS disconnect: user %s left ticket %s", user_id, ticket_id)

    # ------------------------------------------------------------------
    # BROADCASTING
    # ------------------------------------------------------------------

    async def broadcast_conversation(
        self, conversation_id: int, data: dict[str, Any]
    ) -> None:
        """Push a JSON event to every client watching a conversation."""
        room = self._conversation_connections.get(conversation_id)
        if not room:
            return
        payload = _serialize(data)
        disconnected: list[tuple[WebSocket, int]] = []
        for ws, uid in room:
            try:
                await ws.send_text(payload)
            except Exception:
                disconnected.append((ws, uid))
        for item in disconnected:
            room.discard(item)
        if not room:
            self._conversation_connections.pop(conversation_id, None)

    async def broadcast_ticket(
        self, ticket_id: int, data: dict[str, Any]
    ) -> None:
        """Push a JSON event to every client watching a ticket."""
        room = self._ticket_connections.get(ticket_id)
        if not room:
            return
        payload = _serialize(data)
        disconnected: list[tuple[WebSocket, int]] = []
        for ws, uid in room:
            try:
                await ws.send_text(payload)
            except Exception:
                disconnected.append((ws, uid))
        for item in disconnected:
            room.discard(item)
        if not room:
            self._ticket_connections.pop(ticket_id, None)

    async def broadcast_conversation_and_ticket(
        self,
        conversation_id: int | None,
        ticket_id: int | None,
        data: dict[str, Any],
    ) -> None:
        """Broadcast to both conversation and ticket rooms (skips None IDs)."""
        tasks = []
        if conversation_id is not None:
            tasks.append(self.broadcast_conversation(conversation_id, data))
        if ticket_id is not None:
            tasks.append(self.broadcast_ticket(ticket_id, data))
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)

    # ------------------------------------------------------------------
    # STATS (useful for debugging / health checks)
    # ------------------------------------------------------------------

    @property
    def stats(self) -> dict[str, int]:
        conv_count = sum(len(r) for r in self._conversation_connections.values())
        ticket_count = sum(len(r) for r in self._ticket_connections.values())
        return {
            "conversation_rooms": len(self._conversation_connections),
            "conversation_connections": conv_count,
            "ticket_rooms": len(self._ticket_connections),
            "ticket_connections": ticket_count,
        }


def _serialize(data: dict[str, Any]) -> str:
    """JSON-serialize, converting datetime objects to ISO strings."""

    def _default(obj: Any) -> Any:
        if isinstance(obj, datetime):
            return obj.isoformat()
        raise TypeError(f"Object of type {type(obj)} is not JSON serializable")

    return json.dumps(data, default=_default)


# Singleton instance shared across the app
manager = ConnectionManager()
