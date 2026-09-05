import pytest
from app.database.models.ticket import TicketStatus, TicketPriority


def _login(client, email, password):
    r = client.post("/api/v1/auth/login", data={"username": email, "password": password})
    assert r.status_code == 200
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_ticket_creation_and_state_transitions(client):
    cust_headers = _login(client, "sarah@example.com", "customer1234")
    agent_headers = _login(client, "agent@laurel.test", "agent1234")

    # 1. Customer creates ticket (atomic creation)
    create_resp = client.post(
        "/api/v1/tickets/",
        headers=cust_headers,
        json={
            "subject": "App Crash on Checkout",
            "description": "Whenever I click Pay, the app closes.",
            "category": "technical_support",
            "priority": "high",
        },
    )
    assert create_resp.status_code == 200, create_resp.text
    ticket_data = create_resp.json()["ticket"]
    ticket_id = ticket_data["id"]
    assert ticket_data["status"] == "open"
    assert create_resp.json()["message"]["content"] == "Whenever I click Pay, the app closes."

    # 2. Agent transitions ticket to in_progress (valid transition)
    r = client.patch(
        f"/api/v1/tickets/{ticket_id}",
        headers=agent_headers,
        json={"status": "in_progress"},
    )
    assert r.status_code == 200
    assert r.json()["status"] == "in_progress"

    # 3. Agent transitions ticket to waiting_for_customer (valid transition)
    r = client.patch(
        f"/api/v1/tickets/{ticket_id}",
        headers=agent_headers,
        json={"status": "waiting_for_customer"},
    )
    assert r.status_code == 200
    assert r.json()["status"] == "waiting_for_customer"

    # 4. Agent transitions ticket to resolved (valid transition)
    r = client.patch(
        f"/api/v1/tickets/{ticket_id}",
        headers=agent_headers,
        json={"status": "resolved"},
    )
    assert r.status_code == 200
    assert r.json()["status"] == "resolved"

    # 5. Agent transitions ticket to closed (valid transition)
    r = client.patch(
        f"/api/v1/tickets/{ticket_id}",
        headers=agent_headers,
        json={"status": "closed"},
    )
    assert r.status_code == 200
    assert r.json()["status"] == "closed"

    # 6. Invalid transition: closed -> waiting_for_customer must be REJECTED (400)
    r = client.patch(
        f"/api/v1/tickets/{ticket_id}",
        headers=agent_headers,
        json={"status": "waiting_for_customer"},
    )
    assert r.status_code == 400
    assert "invalid status transition" in r.json()["detail"].lower()
