"""Hardening from the Nov 2026 audit: AI body limit, per-feature free-use counters, and refunds
that only give back free uses that were actually spent."""

import uuid
from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.models import PremiumUsage, User
from backend.app.routers.ai import _refund_free_use
from backend.app.services.users import UserService

client = TestClient(app)


def _user(premium: bool = False) -> tuple[dict[str, str], str]:
    with SessionLocal() as db:
        user = UserService.create(db, email=f"harden_{uuid.uuid4().hex}@example.com", password="StrongPass1!", email_verified=True)
        if premium:
            user.subscription_status = "premium"
            user.subscription_expire_at = datetime.now(timezone.utc) + timedelta(days=30)
            db.add(user)
            db.commit()
        token = create_access_token(subject=user.id, is_admin=False, role=user.role)
        return {"Authorization": f"Bearer {token}"}, user.id


def test_ai_rejects_oversized_bodies_before_parsing():
    headers, _ = _user()
    huge = {"text": "x" * (300 * 1024), "language": "uk", "country": "CH", "today": "2026-11-24"}
    response = client.post("/api/v1/ai/letter-explain", headers=headers, json=huge)
    assert response.status_code == 413
    assert response.json()["detail"]["code"] == "payload_too_large"


def test_entitlements_report_free_uses_left_per_feature():
    headers, user_id = _user()
    with SessionLocal() as db:
        db.add(PremiumUsage(user_id=user_id, feature="letter_explain", free_uses=1))
        db.add(PremiumUsage(user_id=user_id, feature="interview_turns", free_uses=20))
        db.commit()
    response = client.get("/api/v1/subscriptions/entitlements", headers=headers)
    assert response.status_code == 200, response.text
    left = response.json()["free_uses_remaining"]
    assert left["letter_explain"] == 2
    assert left["career_kit"] == 3
    assert left["interview_turns"] == 0


def test_refund_never_banks_uses_for_plus_members():
    _, user_id = _user(premium=True)
    with SessionLocal() as db:
        db.add(PremiumUsage(user_id=user_id, feature="letter_explain", free_uses=2))
        db.commit()
        user = db.get(User, user_id)
        _refund_free_use(db, user, "letter_explain")
        usage = db.query(PremiumUsage).filter_by(user_id=user_id, feature="letter_explain").one()
        assert usage.free_uses == 2


def test_refund_gives_back_a_spent_free_use():
    _, user_id = _user()
    with SessionLocal() as db:
        db.add(PremiumUsage(user_id=user_id, feature="letter_explain", free_uses=2))
        db.commit()
        user = db.get(User, user_id)
        _refund_free_use(db, user, "letter_explain")
        usage = db.query(PremiumUsage).filter_by(user_id=user_id, feature="letter_explain").one()
        assert usage.free_uses == 1


def test_account_deletion_removes_rows_that_cascade_and_unlinks_the_rest():
    from backend.app.models.job import JobAlert
    from backend.app.models.notification import NotificationPreference
    from backend.app.services.users import _user_foreign_keys

    headers, user_id = _user()
    with SessionLocal() as db:
        db.add(JobAlert(user_id=user_id, name="Pflege", keywords="pflege zürich"))
        db.add(NotificationPreference(user_id=user_id))
        db.commit()

    response = client.delete("/api/v1/auth/me", headers=headers)
    assert response.status_code in (200, 204), response.text

    with SessionLocal() as db:
        for table, column, rule in _user_foreign_keys():
            remaining = db.execute(table.select().where(column == user_id)).first()
            assert remaining is None, f"{table.name}.{column.name} still points at the deleted user"


def test_password_reset_revokes_existing_sessions():
    from datetime import timedelta as _td

    from backend.app.core.security import create_refresh_token

    headers, user_id = _user()
    old_refresh = create_refresh_token(user_id)
    assert client.get("/api/v1/subscriptions/entitlements", headers=headers).status_code == 200

    with SessionLocal() as db:
        user = db.get(User, user_id)
        # Same effect as a completed password reset; one second later than the tokens above.
        user.tokens_valid_after = datetime.now(timezone.utc) + _td(seconds=2)
        db.add(user)
        db.commit()

    assert client.get("/api/v1/subscriptions/entitlements", headers=headers).status_code == 401
    refreshed = client.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh})
    assert refreshed.status_code == 401


def test_token_issued_in_the_same_second_as_the_cutoff_stays_valid():
    from backend.app.core.security import token_is_revoked

    cutoff = datetime(2026, 11, 24, 3, 0, 0, 400_000, tzinfo=timezone.utc)
    assert token_is_revoked({"iat": int(cutoff.timestamp()) - 1}, cutoff)
    assert not token_is_revoked({"iat": int(cutoff.timestamp())}, cutoff)
    assert not token_is_revoked({"iat": 1}, None)


def test_account_deletion_erases_uploaded_images(tmp_path, monkeypatch):
    from io import BytesIO

    from backend.app.models.media_upload import MediaUpload
    from backend.app.services import media_storage

    storage = media_storage.LocalMediaStorage(tmp_path)
    monkeypatch.setattr(media_storage, "get_media_storage", lambda settings: storage)
    monkeypatch.setattr("backend.app.routers.media.get_media_storage", lambda settings: storage)

    headers, user_id = _user()
    uploaded = client.post(
        "/api/v1/media/upload",
        headers=headers,
        files={"file": ("photo.jpg", BytesIO(b"\xff\xd8\xffpayload"), "image/jpeg")},
    )
    assert uploaded.status_code == 201, uploaded.text
    key = uploaded.json()["filename"]
    assert (tmp_path / key).exists()
    with SessionLocal() as db:
        assert db.get(MediaUpload, key).user_id == user_id

    assert client.delete("/api/v1/auth/me", headers=headers).status_code in (200, 204)

    assert not (tmp_path / key).exists()
    with SessionLocal() as db:
        assert db.get(MediaUpload, key) is None


def test_data_export_returns_own_rows_without_secrets():
    from backend.app.models.job import JobAlert

    headers, user_id = _user()
    with SessionLocal() as db:
        db.add(JobAlert(user_id=user_id, name="Pflege", keywords="pflege zürich"))
        db.commit()

    response = client.get("/api/v1/auth/me/export", headers=headers)
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["account"]["id"] == user_id
    assert "hashed_password" not in body["account"]
    assert body["data"]["job_alerts"][0]["keywords"] == "pflege zürich"


def test_rate_limit_key_is_the_forwarded_client_not_the_proxy():
    from starlette.requests import Request

    from backend.app.core.rate_limit import client_address

    def request(headers: dict[str, str]) -> Request:
        return Request({
            "type": "http",
            "headers": [(k.lower().encode(), v.encode()) for k, v in headers.items()],
            "client": ("10.0.0.7", 443),
        })

    assert client_address(request({"X-Forwarded-For": "203.0.113.9, 10.0.0.7"})) == "203.0.113.9"
    assert client_address(request({"X-Forwarded-For": "198.51.100.4"})) == "198.51.100.4"
    assert client_address(request({})) == "10.0.0.7"
