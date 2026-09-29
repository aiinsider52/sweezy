from __future__ import annotations

import uuid

from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.services.users import UserService

client = TestClient(app)


def _identity(*, admin: bool = False) -> dict[str, str]:
    with SessionLocal() as db:
        user = UserService.create(
            db,
            email=f"places_{uuid.uuid4().hex}@example.com",
            password="StrongPass1!",
            is_superuser=admin,
            role="admin" if admin else "user",
            email_verified=True,
        )
        token = create_access_token(subject=user.id, is_admin=admin, role=user.role)
    return {"Authorization": f"Bearer {token}"}


def _payload(**overrides: object) -> dict[str, object]:
    payload: dict[str, object] = {
        "name": f"  Ukrainian   Saturday School {uuid.uuid4().hex[:6]} ",
        "category": "school",
        "street": "Bahnhofstrasse 10",
        "postal_code": "8001",
        "city": "Zürich",
        "country_code": "ch",
        "website": "example.org/school",
        "note": "Lessons for kids every Saturday morning, I take my daughter there.",
    }
    payload.update(overrides)
    return payload


def test_suggestion_stays_private_until_approved() -> None:
    author = _identity()
    admin = _identity(admin=True)

    unauthenticated = client.post("/api/v1/places/suggestions", json=_payload())
    assert unauthenticated.status_code == 401

    created = client.post("/api/v1/places/suggestions", headers=author, json=_payload())
    assert created.status_code == 201, created.text
    body = created.json()
    assert body["status"] == "pending"
    assert body["name"].startswith("Ukrainian Saturday School")
    assert body["country_code"] == "CH"
    assert body["website"] == "https://example.org/school"

    mine = client.get("/api/v1/places/suggestions/me", headers=author).json()
    assert [item["id"] for item in mine] == [body["id"]]

    public = client.get("/api/v1/places/community?country=CH").json()
    assert body["id"] not in {item["id"] for item in public}

    queue = client.get("/api/v1/admin/places/suggestions", headers=admin)
    assert queue.status_code == 200
    assert body["id"] in {item["id"] for item in queue.json()}

    without_location = client.patch(
        f"/api/v1/admin/places/suggestions/{body['id']}", headers=admin, json={"status": "approved"}
    )
    assert without_location.status_code == 422

    approved = client.patch(
        f"/api/v1/admin/places/suggestions/{body['id']}",
        headers=admin,
        json={"status": "approved", "latitude": 47.3769, "longitude": 8.5417, "subdivision_code": "zh"},
    )
    assert approved.status_code == 200, approved.text
    assert approved.json()["status"] == "approved"

    public = client.get("/api/v1/places/community?country=CH").json()
    place = next(item for item in public if item["id"] == body["id"])
    assert place["latitude"] == 47.3769
    assert place["subdivision_code"] == "ZH"
    assert "note" not in place
    assert "user_id" not in place

    other_country = client.get("/api/v1/places/community?country=DE").json()
    assert body["id"] not in {item["id"] for item in other_country}


def test_rejection_needs_reason_and_only_admins_moderate() -> None:
    author = _identity()
    admin = _identity(admin=True)
    created = client.post("/api/v1/places/suggestions", headers=author, json=_payload(category="legal_aid")).json()

    forbidden = client.patch(
        f"/api/v1/admin/places/suggestions/{created['id']}", headers=author, json={"status": "rejected"}
    )
    assert forbidden.status_code == 403

    no_reason = client.patch(
        f"/api/v1/admin/places/suggestions/{created['id']}", headers=admin, json={"status": "rejected"}
    )
    assert no_reason.status_code == 422

    rejected = client.patch(
        f"/api/v1/admin/places/suggestions/{created['id']}",
        headers=admin,
        json={"status": "rejected", "rejection_reason": "Could not confirm the address."},
    )
    assert rejected.status_code == 200
    assert rejected.json()["rejection_reason"] == "Could not confirm the address."

    mine = client.get("/api/v1/places/suggestions/me", headers=author).json()
    assert mine[0]["status"] == "rejected"

    missing = client.patch("/api/v1/admin/places/suggestions/nope", headers=admin, json={"status": "approved"})
    assert missing.status_code == 404


def test_invalid_payloads_are_rejected() -> None:
    author = _identity()
    bad_category = client.post("/api/v1/places/suggestions", headers=author, json=_payload(category="casino"))
    assert bad_category.status_code == 422
    bad_country = client.post("/api/v1/places/suggestions", headers=author, json=_payload(country_code="FR"))
    assert bad_country.status_code == 422
    short_note = client.post("/api/v1/places/suggestions", headers=author, json=_payload(note="ok"))
    assert short_note.status_code == 422


def test_account_deletion_removes_unpublished_suggestions() -> None:
    from backend.app.models.place_suggestion import PlaceSuggestion
    from backend.app.models.user import User
    from backend.app.services.users import UserService

    author = _identity()
    pending = client.post("/api/v1/places/suggestions", headers=author, json=_payload()).json()
    with SessionLocal() as db:
        suggestion = db.get(PlaceSuggestion, pending["id"])
        user = db.get(User, suggestion.user_id)
        UserService.delete_account(db, user=user)
        db.commit()
    with SessionLocal() as db:
        assert db.get(PlaceSuggestion, pending["id"]) is None
