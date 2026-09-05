import uuid
import pytest


def test_register_and_login_flow(client):
    unique_email = f"user_{uuid.uuid4().hex[:8]}@example.com"

    # 1. Register with strong password
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={
            "name": "Jane Doe",
            "email": unique_email,
            "password": "StrongPassword123!",
        },
    )
    assert reg_resp.status_code == 200, reg_resp.text
    reg_data = reg_resp.json()
    assert "access_token" in reg_data
    assert reg_data["user"]["email"] == unique_email
    assert reg_data["user"]["role"] == "customer"

    # 2. Duplicate registration rejected
    dup_resp = client.post(
        "/api/v1/auth/register",
        json={
            "name": "Jane Doe",
            "email": unique_email,
            "password": "StrongPassword123!",
        },
    )
    assert dup_resp.status_code == 400
    assert "already registered" in dup_resp.json()["detail"].lower()

    # 3. Login with credentials
    login_resp = client.post(
        "/api/v1/auth/login",
        data={"username": unique_email, "password": "StrongPassword123!"},
    )
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 4. Access /auth/me
    me_resp = client.get("/api/v1/auth/me", headers=headers)
    assert me_resp.status_code == 200
    assert me_resp.json()["email"] == unique_email

    # 5. Access /auth/logout
    logout_resp = client.post("/api/v1/auth/logout", headers=headers)
    assert logout_resp.status_code == 200
    assert "logged out" in logout_resp.json()["message"].lower()


def test_register_weak_password_rejected(client):
    # Too short
    r = client.post(
        "/api/v1/auth/register",
        json={"name": "Weak", "email": "weak@test.com", "password": "short"},
    )
    assert r.status_code == 422

    # Missing uppercase
    r = client.post(
        "/api/v1/auth/register",
        json={"name": "Weak", "email": "weak@test.com", "password": "password123!"},
    )
    assert r.status_code == 422

    # Missing number
    r = client.post(
        "/api/v1/auth/register",
        json={"name": "Weak", "email": "weak@test.com", "password": "Password!"},
    )
    assert r.status_code == 422


def test_login_invalid_credentials_rejected(client):
    r = client.post(
        "/api/v1/auth/login",
        data={"username": "admin@laurel.test", "password": "WrongPassword999!"},
    )
    assert r.status_code == 401
    assert "invalid" in r.json()["detail"].lower()


def test_invalid_tokens_rejected(client):
    r = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer invalid.fake.token"})
    assert r.status_code == 401

    r = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer "})
    assert r.status_code == 401

    r = client.get("/api/v1/auth/me")
    assert r.status_code == 401
