import pytest
from app.database.models.ticket import Ticket, TicketStatus
from app.database.models.conversation import Conversation
from app.database.models.message import Message
from app.database.models.ticket_message import TicketMessage


def _login(client, email, password):
    r = client.post("/api/v1/auth/login", data={"username": email, "password": password})
    assert r.status_code == 200
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_customer_request_live_agent(client, db):
    customer_headers = _login(client, "sarah@example.com", "customer1234")
    # 1. Create a conversation
    resp = client.post("/api/v1/conversations/", headers=customer_headers)
    assert resp.status_code == 200
    conv_id = resp.json()["id"]

    # 2. Request live agent handoff
    resp = client.post(f"/api/v1/conversations/{conv_id}/request-agent", headers=customer_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["conversation"]["status"] == "human_support"
    assert data["conversation"]["ai_active"] is False
    assert data["ticket"] is not None
    ticket_id = data["ticket"]["id"]
    assert data["conversation"]["ticket_id"] == ticket_id

    # 3. Customer sends message in live chat -> verify it mirrors into ticket
    resp = client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        headers=customer_headers,
        json={"content": "Hello human agent, I need urgent help!"}
    )
    assert resp.status_code == 200
    assert resp.json()["message"] == "Message sent to human support"

    # Verify mirrored into ticket_messages
    ticket_msgs = db.query(TicketMessage).filter(TicketMessage.ticket_id == ticket_id).all()
    assert any("urgent help" in m.content for m in ticket_msgs)


def test_agent_reply_sync_to_conversation(client, db):
    customer_headers = _login(client, "sarah@example.com", "customer1234")
    agent_headers = _login(client, "agent@laurel.test", "agent1234")
    # 1. Create conversation and request agent
    conv_resp = client.post("/api/v1/conversations/", headers=customer_headers).json()
    conv_id = conv_resp["id"]
    req_resp = client.post(f"/api/v1/conversations/{conv_id}/request-agent", headers=customer_headers).json()
    ticket_id = req_resp["ticket"]["id"]

    # 2. Agent replies to the ticket
    reply_resp = client.post(
        f"/api/v1/tickets/{ticket_id}/messages",
        headers=agent_headers,
        json={"content": "Hello from support agent, I am here to help!"}
    )
    assert reply_resp.status_code == 200

    # 3. Verify that the agent reply was mirrored into the live conversation
    conv_msgs = client.get(f"/api/v1/conversations/{conv_id}/messages", headers=customer_headers).json()
    assert any("Hello from support agent" in m["content"] for m in conv_msgs)
