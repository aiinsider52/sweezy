from __future__ import annotations

import uuid

from fastapi.testclient import TestClient

from backend.app.main import app
from backend.app.core.security import create_access_token
from backend.app.core.database import SessionLocal
from backend.app.models.user import User
from backend.app.services.auth_email_codes import AuthEmailCodeService
from backend.app.services.oauth_id_tokens import VerifiedOAuthIdentity


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


def _issue_code(email: str, purpose: str) -> str:
    with SessionLocal() as db:
        user = db.query(User).filter(User.email == email.lower()).one()
        return AuthEmailCodeService.issue_code(db, user=user, purpose=purpose, ttl_minutes=15)


# --- Auth tests --------------------------------------------------------------


def test_register_and_login_success():
    email = _unique_email()
    password = "StrongPass1!"

    # Register new user
    res = client.post("/api/v1/auth/register", json={"email": email, "password": password})
    assert res.status_code == 201
    data = res.json()
    assert data["email"] == email
    assert data["status"] == "verification_required"

    # Login is blocked until email verification
    res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert res.status_code == 403
    assert res.json()["detail"]["code"] == "EMAIL_NOT_VERIFIED"

    code = _issue_code(email, AuthEmailCodeService.VERIFY_EMAIL)
    res = client.post("/api/v1/auth/verify-email/confirm", json={"email": email, "code": code})
    assert res.status_code == 200
    tokens = res.json()
    assert "access_token" in tokens
    assert "refresh_token" in tokens

    # Login with same credentials now works
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

    # Second registration with same email should re-send verification while still unverified
    res = client.post("/api/v1/auth/register", json={"email": email, "password": password})
    assert res.status_code == 201
    assert res.json()["status"] == "verification_required"


def test_login_invalid_credentials_returns_401():
    email = _unique_email()
    password = "StrongPass1!"

    # create user
    res = client.post("/api/v1/auth/register", json={"email": email, "password": password})
    assert res.status_code == 201

    code = _issue_code(email, AuthEmailCodeService.VERIFY_EMAIL)
    res = client.post("/api/v1/auth/verify-email/confirm", json={"email": email, "code": code})
    assert res.status_code == 200

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

    verify_code = _issue_code(email, AuthEmailCodeService.VERIFY_EMAIL)
    res = client.post("/api/v1/auth/verify-email/confirm", json={"email": email, "code": verify_code})
    assert res.status_code == 200

    res = client.post("/api/v1/auth/password/forgot", json={"email": email})
    assert res.status_code == 200

    reset_code = _issue_code(email, AuthEmailCodeService.RESET_PASSWORD)

    # Reset password
    res = client.post(
        "/api/v1/auth/password/reset",
        json={"email": email, "code": reset_code, "password": new_password},
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


def test_password_reset_with_invalid_code_fails():
    res = client.post(
        "/api/v1/auth/password/reset",
        json={"email": _unique_email(), "code": "123456", "password": "AnotherPass1!"},
    )
    assert res.status_code == 400


def test_google_oauth_creates_user_and_can_sign_in_again(monkeypatch):
    email = _unique_email()

    def fake_verify(_: str) -> VerifiedOAuthIdentity:
        return VerifiedOAuthIdentity(
            provider="google",
            subject="google-sub-1",
            email=email,
            email_verified=True,
            name="OAuth User",
            claims={},
        )

    monkeypatch.setattr(
        "backend.app.routers.auth.OAuthIDTokenService.verify_google_id_token",
        fake_verify,
    )

    res = client.post("/api/v1/auth/oauth/google", json={"id_token": "fake-google-token", "full_name": "OAuth User"})
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "authenticated"
    assert data["email"] == email
    assert data["access_token"]
    assert data["refresh_token"]

    with SessionLocal() as db:
        user = db.query(User).filter(User.email == email.lower()).one()
        assert user.google_sub == "google-sub-1"
        assert user.password_login_enabled is False
        assert user.email_verified is True

    res_repeat = client.post("/api/v1/auth/oauth/google", json={"id_token": "fake-google-token"})
    assert res_repeat.status_code == 200
    repeat_data = res_repeat.json()
    assert repeat_data["status"] == "authenticated"
    assert repeat_data["email"] == email


def test_google_oauth_existing_password_user_requires_link_and_can_confirm(monkeypatch):
    email = _unique_email()
    password = "StrongPass1!"

    res = client.post("/api/v1/auth/register", json={"email": email, "password": password})
    assert res.status_code == 201
    code = _issue_code(email, AuthEmailCodeService.VERIFY_EMAIL)
    verify_res = client.post("/api/v1/auth/verify-email/confirm", json={"email": email, "code": code})
    assert verify_res.status_code == 200

    def fake_verify(_: str) -> VerifiedOAuthIdentity:
        return VerifiedOAuthIdentity(
            provider="google",
            subject="google-link-sub",
            email=email,
            email_verified=True,
            name="Linked User",
            claims={},
        )

    monkeypatch.setattr(
        "backend.app.routers.auth.OAuthIDTokenService.verify_google_id_token",
        fake_verify,
    )

    link_required = client.post("/api/v1/auth/oauth/google", json={"id_token": "fake-google-token"})
    assert link_required.status_code == 200
    link_data = link_required.json()
    assert link_data["status"] == "link_required"
    assert link_data["link_token"]

    confirm = client.post(
        "/api/v1/auth/oauth/link/confirm",
        json={
            "email": email,
            "password": password,
            "link_token": link_data["link_token"],
        },
    )
    assert confirm.status_code == 200
    confirm_data = confirm.json()
    assert confirm_data["status"] == "authenticated"
    assert confirm_data["email"] == email
    assert confirm_data["access_token"]
    assert confirm_data["refresh_token"]

    with SessionLocal() as db:
        user = db.query(User).filter(User.email == email.lower()).one()
        assert user.google_sub == "google-link-sub"


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


