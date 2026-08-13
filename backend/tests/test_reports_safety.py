from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token, get_password_hash
from backend.app.main import app
from backend.app.models.moderation import ModerationCase, ModerationNotification, UserSanction
from backend.app.models.social import SocialProfile
from backend.app.models.user import User


client = TestClient(app)


def _user(*, admin: bool = False) -> tuple[User, dict[str, str]]:
    with SessionLocal() as db:
        user = User(
            email=f"safety-{uuid4().hex}@example.com",
            hashed_password=get_password_hash("Password123!"),
            email_verified=True,
            is_superuser=admin,
            role="admin" if admin else "viewer",
        )
        db.add(user); db.commit(); db.refresh(user)
        token = create_access_token(subject=user.id, is_admin=admin, role=user.role)
        db.expunge(user)
        return user, {"Authorization": f"Bearer {token}"}


def _profile(user: User) -> None:
    with SessionLocal() as db:
        db.add(SocialProfile(user_id=user.id, display_name="Test Person", canton="ZH", city="Zürich", bio="Test profile for moderation", interests=["coffee"], languages=["de"], meetup_formats=["coffee"], availability=["weekend"], guidelines_accepted=True, moderation_status="approved"))
        db.commit()


def test_report_queue_warn_notification_and_history() -> None:
    subject, subject_headers = _user()
    reporter, reporter_headers = _user()
    _admin, admin_headers = _user(admin=True)
    _profile(subject)

    reported = client.post(f"/api/v1/friends/profiles/{subject.id}/report", headers=reporter_headers, json={"reason": "harassment", "details": "Repeated unwanted contact"})
    assert reported.status_code == 200, reported.text

    queue = client.get("/api/v1/admin/reports-safety?status=open&source_type=social_profile", headers=admin_headers)
    assert queue.status_code == 200, queue.text
    case = next(item for item in queue.json() if item["subject_user_id"] == subject.id)
    assert case["priority"] == "high"

    claimed = client.patch(f"/api/v1/admin/reports-safety/{case['id']}", headers=admin_headers, json={"status": "reviewing"})
    assert claimed.status_code == 200, claimed.text
    decided = client.post(f"/api/v1/admin/reports-safety/{case['id']}/decision", headers=admin_headers, json={"action": "warn", "comment": "Respect community boundaries."})
    assert decided.status_code == 200, decided.text
    assert decided.json()["status"] == "resolved"

    notifications = client.get("/api/v1/moderation/notifications", headers=subject_headers)
    assert notifications.status_code == 200, notifications.text
    assert any(item["kind"] == "warn" for item in notifications.json())
    reporter_notifications = client.get("/api/v1/moderation/notifications", headers=reporter_headers)
    assert any(item["kind"] == "report_result" for item in reporter_notifications.json())

    history = client.get(f"/api/v1/admin/reports-safety/users/{subject.id}/history", headers=admin_headers)
    assert history.status_code == 200, history.text
    assert history.json()["user"]["strike_count"] == 1


def test_suspend_blocks_api_and_expiry_restores_access() -> None:
    subject, subject_headers = _user()
    reporter, reporter_headers = _user()
    _admin, admin_headers = _user(admin=True)
    _profile(subject)
    client.post(f"/api/v1/friends/profiles/{subject.id}/report", headers=reporter_headers, json={"reason": "unsafe"})
    queue = client.get("/api/v1/admin/reports-safety?status=open&source_type=social_profile", headers=admin_headers).json()
    case = next(item for item in queue if item["subject_user_id"] == subject.id)
    response = client.post(f"/api/v1/admin/reports-safety/{case['id']}/decision", headers=admin_headers, json={"action": "suspend", "comment": "Temporary safety review.", "suspension_days": 2})
    assert response.status_code == 200, response.text
    blocked = client.get("/api/v1/moderation/notifications", headers=subject_headers)
    assert blocked.status_code == 403
    assert blocked.json()["detail"]["code"] == "account_suspended"

    with SessionLocal() as db:
        user = db.get(User, subject.id)
        user.safety_suspended_until = datetime.now(timezone.utc) - timedelta(minutes=1)
        sanction = db.query(UserSanction).filter_by(user_id=subject.id, action="suspend", status="active").one()
        sanction.expires_at = user.safety_suspended_until
        db.commit()
    restored = client.get("/api/v1/moderation/notifications", headers=subject_headers)
    assert restored.status_code == 200, restored.text


def test_five_unique_high_risk_reports_trigger_single_auto_hold() -> None:
    subject, _ = _user(); _profile(subject)
    for _ in range(5):
        _reporter, headers = _user()
        response = client.post(f"/api/v1/friends/profiles/{subject.id}/report", headers=headers, json={"reason": "unsafe"})
        assert response.status_code == 200
    with SessionLocal() as db:
        user = db.get(User, subject.id)
        assert user.safety_status == "suspended"
        assert db.query(UserSanction).filter_by(user_id=subject.id, action="suspend", status="active").count() == 1
        assert db.query(ModerationCase).filter_by(subject_user_id=subject.id).count() == 5
        assert db.query(ModerationNotification).filter_by(user_id=subject.id, kind="suspended").count() == 1
