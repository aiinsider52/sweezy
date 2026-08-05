from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.models.analytics import AnalyticsEvent, AnalyticsSession
from backend.app.services.users import UserService


client = TestClient(app)


def _headers(*, admin: bool = False) -> dict[str, str]:
    with SessionLocal() as db:
        user = UserService.create(
            db,
            email=f"analytics_{uuid.uuid4().hex}@example.com",
            password="StrongPass1!",
            is_superuser=admin,
            role="admin" if admin else "viewer",
            email_verified=True,
        )
        token = create_access_token(subject=user.id, is_admin=admin, role=user.role)
    return {"Authorization": f"Bearer {token}"}


def _event(event_id: str | None = None, event_type: str = "screen_view", level: str = "info") -> dict:
    return {
        "id": event_id or uuid.uuid4().hex,
        "ts": datetime.now(timezone.utc).isoformat(),
        "level": level,
        "source": "tests",
        "type": event_type,
        "message": "safe message",
        "meta": {"screen": "home", "email": "must-be-removed@example.com"},
    }


def test_guest_ingestion_requires_consent_and_stores_sanitized_event() -> None:
    payload = {
        "session_id": uuid.uuid4().hex,
        "guest_id": uuid.uuid4().hex,
        "app_version": "2.1.0",
        "events": [_event()],
    }
    denied = client.post("/api/v1/telemetry/batch", json=payload)
    assert denied.status_code == 403

    accepted = client.post(
        "/api/v1/telemetry/batch",
        headers={"X-Analytics-Consent": "granted"},
        json=payload,
    )
    assert accepted.status_code == 200
    assert accepted.json() == {"accepted": 1}
    with SessionLocal() as db:
        row = db.get(AnalyticsEvent, payload["events"][0]["id"])
        assert row is not None
        assert row.user_id is None
        assert row.guest_id == payload["guest_id"]
        assert row.properties == {"screen": "home"}


def test_ingestion_is_idempotent_and_admin_aggregates_are_protected() -> None:
    headers = _headers()
    event = _event(event_type="signup_started")
    payload = {"session_id": uuid.uuid4().hex, "app_version": "2.2.0", "events": [event]}
    first = client.post(
        "/api/v1/telemetry/batch",
        headers={**headers, "X-Analytics-Consent": "granted"},
        json=payload,
    )
    second = client.post(
        "/api/v1/telemetry/batch",
        headers={**headers, "X-Analytics-Consent": "granted"},
        json=payload,
    )
    assert first.json() == {"accepted": 1}
    assert second.json() == {"accepted": 0}
    assert client.get("/api/v1/admin/analytics/overview", headers=headers).status_code == 403

    admin_headers = _headers(admin=True)
    for path in (
        "overview",
        "realtime",
        "active-users",
        "retention",
        "top-actions",
        "app-versions",
        "errors",
    ):
        response = client.get(f"/api/v1/admin/analytics/{path}", headers=admin_headers)
        assert response.status_code == 200, response.text
    funnel = client.get(
        "/api/v1/admin/analytics/funnels",
        headers=admin_headers,
        params=[("steps", "signup_started"), ("steps", "signup_completed")],
    )
    assert funnel.status_code == 200


def test_account_deletion_erases_authenticated_analytics() -> None:
    with SessionLocal() as db:
        user = UserService.create(
            db,
            email=f"analytics_delete_{uuid.uuid4().hex}@example.com",
            password="StrongPass1!",
            email_verified=True,
        )
        session = AnalyticsSession(
            client_session_id=uuid.uuid4().hex,
            user_id=user.id,
            started_at=datetime.now(timezone.utc),
            last_seen_at=datetime.now(timezone.utc),
        )
        db.add(session)
        db.flush()
        event = AnalyticsEvent(
            id=uuid.uuid4().hex,
            session_id=session.id,
            user_id=user.id,
            occurred_at=datetime.now(timezone.utc),
            source="tests",
            event_type="account_viewed",
        )
        db.add(event)
        db.commit()
        UserService.delete_account(db, user=user)
        assert db.get(AnalyticsEvent, event.id) is None
        assert db.get(AnalyticsSession, session.id) is None
