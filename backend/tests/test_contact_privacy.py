from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from backend.app.main import app
from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.services.users import UserService


client = TestClient(app)


def _identity(*, admin: bool = False) -> dict[str, str]:
    with SessionLocal() as db:
        user = UserService.create(
            db,
            email=f"privacy_{uuid.uuid4().hex}@example.com",
            password="StrongPass1!",
            is_superuser=admin,
            role="admin" if admin else "user",
            email_verified=True,
        )
        token = create_access_token(subject=user.id, is_admin=admin, role=user.role)
        return {"Authorization": f"Bearer {token}"}


def test_public_experts_omit_contact_value() -> None:
    owner = _identity()
    admin = _identity(admin=True)
    secret = f"secret-{uuid.uuid4().hex}@example.com"

    created = client.post(
        "/api/v1/marketplace/",
        headers=owner,
        json={
            "listing_type": "service",
            "title": "Verified immigration expert",
            "description": "Helps newcomers with residence permits and paperwork in Switzerland.",
            "category": "legal",
            "canton": "ZH",
            "price_info": "CHF 120/hour",
            "contact_type": "email",
            "contact_value": secret,
            "author_name": "Expert Owner",
            "image_urls": [],
        },
    )
    assert created.status_code == 201, created.text
    listing_id = created.json()["id"]

    approved = client.patch(
        f"/api/v1/admin/marketplace/{listing_id}/approve",
        headers=admin,
        json={
            "is_expert": True,
            "expert_specialty": "relocation",
            "expert_languages": ["uk", "en"],
            "expert_bio": "Licensed advisor",
        },
    )
    assert approved.status_code == 200, approved.text
    assert approved.json()["contact_value"] == secret

    public = client.get("/api/v1/experts/")
    assert public.status_code == 200, public.text
    experts = public.json()
    match = next((row for row in experts if row["id"] == listing_id), None)
    assert match is not None
    assert "contact_value" not in match
    assert secret not in public.text


def test_public_event_detail_omits_contact_value() -> None:
    owner = _identity()
    admin = _identity(admin=True)
    secret = f"+4179{uuid.uuid4().hex[:7]}"
    starts = (datetime.now(timezone.utc) + timedelta(days=7)).replace(microsecond=0)

    created = client.post(
        "/api/v1/events/",
        headers=owner,
        json={
            "title": "Community meetup in Zurich",
            "description": "A public community meetup for newcomers in Zurich city centre.",
            "category": "community",
            "canton": "ZH",
            "city": "Zurich",
            "venue_name": "Community Hub",
            "address": "Bahnhofstrasse 1",
            "starts_at": starts.isoformat().replace("+00:00", "Z"),
            "is_free": True,
            "contact_type": "phone",
            "contact_value": secret,
            "organizer_name": "Sweezy Host",
        },
    )
    assert created.status_code == 201, created.text
    event_id = created.json()["id"]

    approved = client.patch(f"/api/v1/admin/events/{event_id}/approve", headers=admin, json={})
    assert approved.status_code == 200, approved.text
    assert approved.json()["contact_value"] == secret

    public = client.get(f"/api/v1/events/{event_id}")
    assert public.status_code == 200, public.text
    body = public.json()
    assert "contact_value" not in body
    assert secret not in public.text

    mine = client.get("/api/v1/events/my", headers=owner)
    assert mine.status_code == 200, mine.text
    own = next((row for row in mine.json() if row["id"] == event_id), None)
    assert own is not None
    assert own["contact_value"] == secret
