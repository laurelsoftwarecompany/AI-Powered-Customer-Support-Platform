"""
End-to-end API test of the customer -> AI message flow with RAG.

Uses FastAPI's TestClient against the local database in `mock` provider mode,
so no API key or network is needed. Needs a seeded KB for the sources checks.
"""
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.config import settings

pytestmark = pytest.mark.usefixtures("mock_provider")

CUSTOMER = {"username": "sarah@example.com", "password": "customer1234"}


@pytest.fixture()
def client():
    with TestClient(app) as c:
        yield c


@pytest.fixture()
def customer_token(client):
    r = client.post("/api/v1/auth/login", data=CUSTOMER)
    if r.status_code != 200:
        pytest.skip("demo customer not seeded - run: python -m app.seed --fresh --kaggle")
    return r.json()["access_token"]


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _new_conversation(client, token):
    r = client.post("/api/v1/conversations/", headers=_auth(token))
    assert r.status_code == 200, r.text
    return r.json()["id"]


def test_ai_answers_and_cites_sources(client, customer_token, kb_ready):
    cid = _new_conversation(client, customer_token)
    r = client.post(
        f"/api/v1/conversations/{cid}/messages",
        headers=_auth(customer_token),
        json={"content": "How do I reset my password? I'm locked out."},
    )
    assert r.status_code == 200, r.text
    body = r.json()

    assert body["ai_message"]["sender_type"] == "ai"
    assert body["ai_message"]["content"].strip()
    assert body["ai_message"]["intent"]

    sources = body["sources"]
    assert sources, "expected retrieved sources for a password question"
    assert all(s["score"] >= settings.RAG_MIN_SCORE for s in sources)
    assert all({"document_id", "title", "score", "snippet"} <= set(s) for s in sources)


def test_sources_are_persisted_on_the_message(client, customer_token, kb_ready):
    cid = _new_conversation(client, customer_token)
    client.post(
        f"/api/v1/conversations/{cid}/messages",
        headers=_auth(customer_token),
        json={"content": "Where is my order, it hasn't arrived?"},
    )
    r = client.get(f"/api/v1/conversations/{cid}/messages", headers=_auth(customer_token))
    assert r.status_code == 200
    ai_messages = [m for m in r.json() if m["sender_type"] == "ai"]
    assert ai_messages
    assert ai_messages[-1]["sources"], "sources should be stored on the AI message"


def test_complaint_escalates_and_opens_a_ticket(client, customer_token):
    cid = _new_conversation(client, customer_token)
    r = client.post(
        f"/api/v1/conversations/{cid}/messages",
        headers=_auth(customer_token),
        json={"content": "This is unacceptable, I want to speak to a manager."},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["escalated"] is True
    assert body["ticket"]["id"]
    assert body["ticket"]["category"] == "complaint"

    # conversation has handed off to a human
    conv = client.get(f"/api/v1/conversations/{cid}", headers=_auth(customer_token)).json()
    assert conv["ai_active"] is False


def test_message_content_is_required(client, customer_token):
    cid = _new_conversation(client, customer_token)
    r = client.post(
        f"/api/v1/conversations/{cid}/messages",
        headers=_auth(customer_token),
        json={"content": "   "},
    )
    assert r.status_code == 400


def test_other_customers_cannot_post_to_a_conversation(client, customer_token):
    cid = _new_conversation(client, customer_token)
    other = client.post(
        "/api/v1/auth/login", data={"username": "james@example.com", "password": "customer1234"}
    )
    if other.status_code != 200:
        pytest.skip("second demo customer not seeded")
    other_token = other.json()["access_token"]
    r = client.post(
        f"/api/v1/conversations/{cid}/messages",
        headers=_auth(other_token),
        json={"content": "let me in"},
    )
    assert r.status_code == 403
