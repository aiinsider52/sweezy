from __future__ import annotations

from datetime import timedelta
import uuid

from fastapi.testclient import TestClient

from backend.app.main import app
from backend.app.core.security import create_access_token, create_refresh_token


client = TestClient(app)


def _unique_email() -> str:
    return f"test_{uuid.uuid4().hex}@example.com"


def _admin_headers() -> dict[str, str]:
    """
    Create a short‑lived admin JWT for calling protected CRUD endpoints.
    `get_current_admin` only checks the `is_admin` flag on the token, so we
    don't need a persisted admin user for these tests.
    """
    token = create_access_token(subject="admin@test.local", is_admin=True, role="admin")
    return {"Authorization": f"Bearer {token}"}


# --- Auth tests --------------------------------------------------------------


def test_register_and_login_success():
    email = _unique_email()
    password = "StrongPass1!"

    # Register new user
    res = client.post("/api/v1/auth/register", json={"email": email, "password": password})
    assert res.status_code == 201
    data = res.json()
    assert data["email"] == email
    assert data["is_active"] is True

    # Login with same credentials
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert res.status_code == 200
    tokens = res.json()
    assert "access_token" in tokens
    assert "refresh_token" in tokens


def test_register_duplicate_email_fails():
    email = _unique_email()
    password = "StrongPass1!"

    res = client.post("/api/v1/auth/register", json={"email": email, "password": password})
    assert res.status_code == 201

    # Second registration with same email should be rejected
    res = client.post("/api/v1/auth/register", json={"email": email, "password": password})
    assert res.status_code == 400
    body = res.json()
    assert body.get("detail") in ("Email already registered", body.get("detail"))


def test_login_invalid_credentials_returns_401():
    email = _unique_email()
    password = "StrongPass1!"

    # create user
    res = client.post("/api/v1/auth/register", json={"email": email, "password": password})
    assert res.status_code == 201

    # wrong password
    res = client.post("/api/v1/auth/login", json={"email": email, "password": "WrongPass1!"})
    assert res.status_code == 401


def test_forgot_password_always_ok_even_for_unknown_email():
    # Endpoint must not leak whether user exists
    res = client.post("/api/v1/auth/password/forgot", json={"email": _unique_email()})
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_password_reset_flow_changes_password():
    email = _unique_email()
    old_password = "OldPass1!"
    new_password = "NewPass1!"

    # Register user
    res = client.post("/api/v1/auth/register", json={"email": email, "password": old_password})
    assert res.status_code == 201

    # Manually issue reset token the same way the endpoint does
    token = create_refresh_token(subject=email, expires_delta=timedelta(hours=1))

    # Reset password
    res = client.post(
        "/api/v1/auth/password/reset",
        json={"token": token, "password": new_password},
    )
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}

    # Old password should no longer work
    res_old = client.post("/api/v1/auth/login", json={"email": email, "password": old_password})
    assert res_old.status_code == 401

    # New password should work
    res_new = client.post("/api/v1/auth/login", json={"email": email, "password": new_password})
    assert res_new.status_code == 200
    tokens = res_new.json()
    assert "access_token" in tokens


def test_password_reset_with_invalid_token_fails():
    res = client.post(
        "/api/v1/auth/password/reset",
        json={"token": "this-is-not-a-valid-token", "password": "AnotherPass1!"},
    )
    assert res.status_code == 400


# --- Guides CRUD + pagination tests -----------------------------------------


def test_guides_crud_and_pagination():
    headers = _admin_headers()

    # Create a new guide
    slug = f"test-guide-{uuid.uuid4().hex[:8]}"
    payload = {
        "title": "Test Guide",
        "slug": slug,
        "description": "Short description",
        "content": "Longer markdown content",
        "category": "testing",
        "is_published": True,
    }
    res = client.post("/api/v1/guides/", json=payload, headers=headers)
    assert res.status_code == 200
    guide = res.json()
    guide_id = guide["id"]
    assert guide["slug"] == slug

    # Fetch by id
    res = client.get(f"/api/v1/guides/{guide_id}")
    assert res.status_code == 200
    fetched = res.json()
    assert fetched["id"] == guide_id

    # List with limit (pagination)
    res = client.get("/api/v1/guides?limit=1&offset=0")
    assert res.status_code == 200
    items = res.json()
    assert isinstance(items, list)
    assert len(items) <= 1

    # Invalid limit should be rejected by validation
    res = client.get("/api/v1/guides?limit=5000")
    assert res.status_code == 422

    # Update guide
    res = client.put(
        f"/api/v1/guides/{guide_id}",
        json={"title": "Updated title"},
        headers=headers,
    )
    assert res.status_code == 200
    updated = res.json()
    assert updated["title"] == "Updated title"

    # Delete
    res = client.delete(f"/api/v1/guides/{guide_id}", headers=headers)
    assert res.status_code == 204

    # Subsequent fetch should 404
    res = client.get(f"/api/v1/guides/{guide_id}")
    assert res.status_code == 404


