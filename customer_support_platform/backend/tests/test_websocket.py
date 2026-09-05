import pytest
from starlette.websockets import WebSocketDisconnect


def _get_token(client, email, password):
    r = client.post("/api/v1/auth/login", data={"username": email, "password": password})
    assert r.status_code == 200
    return r.json()["access_token"]


def test_ws_auth_rejected_without_token(client):
    """WebSocket should reject connections without a valid token."""
    with pytest.raises(WebSocketDisconnect) as exc_info:
        with client.websocket_connect("/api/v1/ws/conversations/1"):
            pass
    assert exc_info.value.code == 4001


def test_ws_auth_rejected_with_invalid_token(client):
    """WebSocket should reject connections with a garbage token."""
    with pytest.raises(WebSocketDisconnect) as exc_info:
        with client.websocket_connect("/api/v1/ws/conversations/1?token=invalid.token.here"):
            pass
    assert exc_info.value.code == 4001


def test_ws_conversation_connect_and_broadcast(client):
    """Connected client receives real-time broadcast when a message is sent."""
    token = _get_token(client, "sarah@example.com", "customer1234")
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Create a conversation
    conv_resp = client.post("/api/v1/conversations/", headers=headers)
    assert conv_resp.status_code == 200
    conv_id = conv_resp.json()["id"]

    # 2. Connect to WebSocket room
    with client.websocket_connect(f"/api/v1/ws/conversations/{conv_id}?token={token}") as ws:
        # 3. Send a message to the conversation
        msg_resp = client.post(
            f"/api/v1/conversations/{conv_id}/messages",
            headers=headers,
            json={"content": "Can I get help with my billing?"},
        )
        assert msg_resp.status_code == 200

        # 4. Read broadcast from WebSocket
        data = ws.receive_json()
        assert data["event"] == "new_message"
        assert data["conversation_id"] == conv_id
        assert data["message"]["content"] == "Can I get help with my billing?"


def test_ws_status_change_broadcast(client):
    """Client receives status_change broadcast when agent handoff is requested."""
    token = _get_token(client, "sarah@example.com", "customer1234")
    headers = {"Authorization": f"Bearer {token}"}
    agent_token = _get_token(client, "agent@laurel.test", "agent1234")
    agent_headers = {"Authorization": f"Bearer {agent_token}"}

    # 1. Live support runs in its own conversation - the customer's Ask AI
    #    thread stays 100% AI and is never converted into a support session.
    live = client.post(
        "/api/v1/conversations/live-agent/session", headers=headers
    ).json()
    conv_id = live["conversation"]["id"]

    # 2. Connect to WebSocket room
    with client.websocket_connect(f"/api/v1/ws/conversations/{conv_id}?token={token}") as ws:
        # 3. An agent explicitly takes over. That - not merely replying - is
        #    what moves a conversation off the AI.
        req_resp = client.patch(
            f"/api/v1/conversations/{conv_id}/takeover", headers=agent_headers
        )
        assert req_resp.status_code == 200

        # 4. Read status change from WebSocket
        data = ws.receive_json()
        assert data["event"] == "status_change"
        assert data["conversation_id"] == conv_id
        assert data["status"] == "human_support"
        assert data["ai_active"] is False


def test_ws_ticket_connect_and_broadcast(client):
    """Connected client receives real-time broadcast on ticket thread."""
    customer_token = _get_token(client, "sarah@example.com", "customer1234")
    agent_token = _get_token(client, "agent@laurel.test", "agent1234")
    customer_headers = {"Authorization": f"Bearer {customer_token}"}
    agent_headers = {"Authorization": f"Bearer {agent_token}"}

    # 1. Create ticket via conversation handoff
    conv_resp = client.post("/api/v1/conversations/", headers=customer_headers).json()
    conv_id = conv_resp["id"]
    req_resp = client.post(f"/api/v1/conversations/{conv_id}/request-agent", headers=customer_headers).json()
    ticket_id = req_resp["ticket"]["id"]

    # 2. Connect to ticket WebSocket room as agent
    with client.websocket_connect(f"/api/v1/ws/tickets/{ticket_id}?token={agent_token}") as ws:
        # 3. Agent sends reply
        reply_resp = client.post(
            f"/api/v1/tickets/{ticket_id}/messages",
            headers=agent_headers,
            json={"content": "I am working on this ticket right now."},
        )
        assert reply_resp.status_code == 200

        # 4. Read broadcast from WebSocket
        data = ws.receive_json()
        assert data["event"] == "new_message"
        assert data["ticket_id"] == ticket_id
        assert "working on this ticket" in data["message"]["content"]
