import pytest
from app.database.models import User, Ticket, Conversation


def _login(client, email, password):
    r = client.post("/api/v1/auth/login", data={"username": email, "password": password})
    assert r.status_code == 200, f"Login failed for {email}: {r.text}"
    token = r.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_rbac_and_idor_protection(client, db):
    admin_headers = _login(client, "admin@laurel.test", "admin1234")
    agent_headers = _login(client, "agent@laurel.test", "agent1234")
    sarah_headers = _login(client, "sarah@example.com", "customer1234")
    james_headers = _login(client, "james@example.com", "customer1234")

    sarah_user = db.query(User).filter(User.email == "sarah@example.com").first()
    james_user = db.query(User).filter(User.email == "james@example.com").first()
    james_ticket = db.query(Ticket).filter(Ticket.customer_id == james_user.id).first()
    james_conv = db.query(Conversation).filter(Conversation.customer_id == james_user.id).first()

    # 1. IDOR: Customer Sarah accessing Customer James's ticket
    if james_ticket:
        r = client.get(f"/api/v1/tickets/{james_ticket.id}", headers=sarah_headers)
        assert r.status_code == 403

        r = client.get(f"/api/v1/tickets/{james_ticket.id}/messages", headers=sarah_headers)
        assert r.status_code == 403

        r = client.post(
            f"/api/v1/tickets/{james_ticket.id}/messages",
            headers=sarah_headers,
            json={"content": "Malicious reply"},
        )
        assert r.status_code == 403

    # 2. IDOR: Customer Sarah accessing Customer James's conversation
    if james_conv:
        r = client.get(f"/api/v1/conversations/{james_conv.id}", headers=sarah_headers)
        assert r.status_code == 403

        r = client.get(f"/api/v1/conversations/{james_conv.id}/messages", headers=sarah_headers)
        assert r.status_code == 403

        r = client.post(
            f"/api/v1/conversations/{james_conv.id}/messages",
            headers=sarah_headers,
            json={"content": "Malicious message"},
        )
        assert r.status_code == 403

    # 3. Vertical RBAC: Customer trying Admin routes
    r = client.get("/api/v1/admin/users", headers=sarah_headers)
    assert r.status_code == 403

    r = client.get("/api/v1/admin/agents", headers=sarah_headers)
    assert r.status_code == 403

    r = client.get("/api/v1/admin/ai/analytics", headers=sarah_headers)
    assert r.status_code == 403

    # 4. Vertical RBAC: Customer trying Agent routes
    r = client.get("/api/v1/tickets/", headers=sarah_headers)
    assert r.status_code == 403

    r = client.post(
        "/api/v1/tickets/1/internal-notes",
        headers=sarah_headers,
        json={"content": "Illegal note"},
    )
    assert r.status_code == 403

    # 5. Vertical RBAC: Customer trying Knowledge Base management
    r = client.post(
        "/api/v1/knowledge/faqs",
        headers=sarah_headers,
        json={"question": "Can I hack?", "answer": "No."},
    )
    assert r.status_code == 403

    # 6. Data Isolation: Internal staff notes are hidden from customers
    client.post(
        "/api/v1/tickets/1/internal-notes",
        headers=agent_headers,
        json={"content": "SuperSecretInternalStaffDiscussion"},
    )
    cust_view = client.get("/api/v1/tickets/1/messages", headers=sarah_headers)
    assert cust_view.status_code == 200
    all_contents = [m.get("content") for m in cust_view.json()]
    assert "SuperSecretInternalStaffDiscussion" not in all_contents

    # 7. Staff creation via POST /users/ with JSON body
    import uuid
    new_agent_email = f"agent_{uuid.uuid4().hex[:6]}@laurel.test"
    create_agent_resp = client.post(
        "/api/v1/users/",
        headers=admin_headers,
        json={
            "name": "Alex Agent",
            "email": new_agent_email,
            "password": "AgentPassword123!",
            "role": "agent",
        },
    )
    assert create_agent_resp.status_code == 200
    assert create_agent_resp.json()["role"] == "agent"

    # 8. Customer cannot create staff
    fail_create = client.post(
        "/api/v1/users/",
        headers=sarah_headers,
        json={
            "name": "Hacker Agent",
            "email": "hacker@test.com",
            "password": "Password123!",
            "role": "admin",
        },
    )
    assert fail_create.status_code == 403
