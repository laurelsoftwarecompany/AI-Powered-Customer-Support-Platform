import io
import pytest


def _login(client, email, password):
    r = client.post("/api/v1/auth/login", data={"username": email, "password": password})
    assert r.status_code == 200
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_rate_limiting_on_auth_login(client):
    # Trigger 20 rapid login attempts to exceed limit of 15 req/minute
    statuses = []
    for _ in range(20):
        r = client.post(
            "/api/v1/auth/login",
            data={"username": "sarah@example.com", "password": "wrong_password"},
        )
        statuses.append(r.status_code)

    assert 429 in statuses, f"Expected 429 in statuses, got {set(statuses)}"


def test_oversized_file_upload_rejected(client):
    admin_headers = _login(client, "admin@laurel.test", "admin1234")

    # Construct an in-memory file slightly larger than 10MB (10.5 MB)
    large_data = b"x" * (11 * 1024 * 1024)
    file_payload = {"file": ("large_doc.txt", io.BytesIO(large_data), "text/plain")}

    r = client.post(
        "/api/v1/knowledge/documents",
        headers=admin_headers,
        files=file_payload,
    )
    assert r.status_code == 413
    assert "exceeds maximum allowed size" in r.json()["detail"].lower()


def test_empty_file_upload_rejected(client):
    admin_headers = _login(client, "admin@laurel.test", "admin1234")

    empty_payload = {"file": ("empty.txt", io.BytesIO(b""), "text/plain")}
    r = client.post(
        "/api/v1/knowledge/documents",
        headers=admin_headers,
        files=empty_payload,
    )
    assert r.status_code == 400
    assert "empty" in r.json()["detail"].lower()


def test_path_traversal_filename_sanitized(client):
    admin_headers = _login(client, "admin@laurel.test", "admin1234")

    traversal_payload = {
        "file": ("../../etc/malicious.txt", io.BytesIO(b"Safe knowledge content"), "text/plain")
    }
    r = client.post(
        "/api/v1/knowledge/documents",
        headers=admin_headers,
        files=traversal_payload,
    )
    assert r.status_code == 201
    doc_data = r.json()
    assert ".." not in doc_data["filename"]
    assert "malicious.txt" in doc_data["filename"]
