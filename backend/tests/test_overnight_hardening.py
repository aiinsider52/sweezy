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
