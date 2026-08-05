from __future__ import annotations

import uuid

from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.models.incident import Incident
from backend.app.services.incidents import record_incident, redact
from backend.app.services.users import UserService

client = TestClient(app)


def _headers(*, admin: bool) -> dict[str, str]:
    with SessionLocal() as db:
        user = UserService.create(
            db,
            email=f"incident_{uuid.uuid4().hex}@example.com",
            password="StrongPass1!",
            is_superuser=admin,
            role="admin" if admin else "viewer",
            email_verified=True,
        )
        token = create_access_token(subject=user.id, is_admin=admin, role=user.role)
    return {"Authorization": f"Bearer {token}"}


def test_redaction_removes_credentials_and_email() -> None:
    value = redact({
        "authorization": "Bearer top-secret",
        "details": "Contact person@example.com using Bearer abc.def",
        "safe": "ok",
    })
    assert value["authorization"] == "[REDACTED]"
    assert "person@example.com" not in value["details"]
    assert "abc.def" not in value["details"]
    assert value["safe"] == "ok"


def test_record_incident_deduplicates(monkeypatch) -> None:
    monkeypatch.setattr("backend.app.services.incidents.send_telegram_message", lambda _: True)
    key = uuid.uuid4().hex
    first = record_incident(source="test", title="Failure", dedupe_key=key)
    second = record_incident(source="test", title="Failure", dedupe_key=key)
    assert first is not None and second is not None
    assert first.id == second.id
    assert second.occurrence_count == 2


def test_incident_api_is_admin_only_and_can_resolve(monkeypatch) -> None:
    monkeypatch.setattr("backend.app.services.incidents.send_telegram_message", lambda _: True)
    incident = record_incident(source="test", title="API incident", dedupe_key=uuid.uuid4().hex)
    assert incident is not None
    assert client.get("/api/v1/admin/incidents", headers=_headers(admin=False)).status_code == 403
    headers = _headers(admin=True)
    response = client.get("/api/v1/admin/incidents", headers=headers)
    assert response.status_code == 200
    update = client.patch(
        f"/api/v1/admin/incidents/{incident.id}",
        headers=headers,
        json={"status": "resolved"},
    )
    assert update.status_code == 200
    assert update.json()["status"] == "resolved"
    with SessionLocal() as db:
        assert db.get(Incident, incident.id).resolved_at is not None
