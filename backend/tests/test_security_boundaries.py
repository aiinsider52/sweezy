from __future__ import annotations

from io import BytesIO
import uuid

import pytest
from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token, create_refresh_token, decode_token
from backend.app.main import app
from backend.app.services.users import UserService


client = TestClient(app)


def _authenticated_headers(*, is_admin: bool = False) -> dict[str, str]:
    with SessionLocal() as db:
        user = UserService.create(
            db,
            email=f"security_{uuid.uuid4().hex}@example.com",
            password="StrongPass1!",
            is_superuser=is_admin,
            role="admin" if is_admin else "viewer",
            email_verified=True,
        )
        token = create_access_token(subject=user.id, is_admin=is_admin, role=user.role)
    return {"Authorization": f"Bearer {token}"}


def test_refresh_token_cannot_cross_access_boundary() -> None:
    refresh_token = create_refresh_token(subject=str(uuid.uuid4()))
    with pytest.raises(ValueError):
        decode_token(refresh_token)


def test_admin_claim_requires_persisted_superuser() -> None:
    headers = _authenticated_headers(is_admin=False)
    token = headers["Authorization"].removeprefix("Bearer ")
    payload = decode_token(token)
    forged_role_token = create_access_token(subject=payload["sub"], is_admin=True, role="admin")
    response = client.post(
        "/api/v1/guides/",
        headers={"Authorization": f"Bearer {forged_role_token}"},
        json={
            "title": "Blocked",
            "slug": f"blocked-{uuid.uuid4().hex}",
            "description": "Blocked",
            "content": "Blocked",
            "category": "testing",
            "is_published": True,
        },
    )
    assert response.status_code == 403


def test_media_upload_requires_authentication() -> None:
    response = client.post(
        "/api/v1/media/upload",
        files={"file": ("photo.jpg", BytesIO(b"\xff\xd8\xffpayload"), "image/jpeg")},
    )
    assert response.status_code in {401, 403}


def test_media_upload_rejects_unsafe_filename_and_validates_content() -> None:
    headers = _authenticated_headers()
    unsafe = client.post(
        "/api/v1/media/upload",
        headers=headers,
        files={"file": ("../../photo.jpg", BytesIO(b"\xff\xd8\xffpayload"), "image/jpeg")},
    )
    assert unsafe.status_code == 400

    invalid = client.post(
        "/api/v1/media/upload",
        headers=headers,
        files={"file": ("photo.jpg", BytesIO(b"not-an-image"), "image/jpeg")},
    )
    assert invalid.status_code == 415

    valid = client.post(
        "/api/v1/media/upload",
        headers=headers,
        files={"file": ("photo.jpg", BytesIO(b"\xff\xd8\xffpayload"), "image/jpeg")},
    )
    assert valid.status_code == 201
    body = valid.json()
    assert ".." not in body["filename"]
    assert "/" not in body["filename"]
    assert body["url"] == f"/media/{body['filename']}"


def test_telemetry_requires_consent_and_actor_identity() -> None:
    event = {
        "id": str(uuid.uuid4()),
        "ts": "2026-07-13T14:00:00Z",
        "level": "info",
        "source": "tests",
        "type": "retention_next_action_viewed",
        "meta": {"destination": "roadmap"},
    }
    unidentified_guest = client.post(
        "/api/v1/telemetry/batch",
        headers={"X-Analytics-Consent": "granted"},
        json={"events": [event]},
    )
    assert unidentified_guest.status_code == 422
    assert unidentified_guest.json()["detail"] == "guest_id required for guests"

    headers = _authenticated_headers()
    no_consent = client.post("/api/v1/telemetry/batch", headers=headers, json={"events": [event]})
    assert no_consent.status_code == 403

    accepted = client.post(
        "/api/v1/telemetry/batch",
        headers={**headers, "X-Analytics-Consent": "granted"},
        json={"events": [event]},
    )
    assert accepted.status_code == 200
    assert accepted.json() == {"accepted": 1}
