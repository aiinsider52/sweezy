from __future__ import annotations

import uuid

from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.services.users import UserService


client = TestClient(app)


def identity(*, admin: bool = False) -> tuple[dict[str, str], str]:
    with SessionLocal() as db:
        user = UserService.create(
            db, email=f"moderation_{uuid.uuid4().hex}@example.test", password="StrongPass1!",
            role="admin" if admin else "user", is_superuser=admin, email_verified=True,
        )
        token = create_access_token(subject=user.id, is_admin=admin, role=user.role)
        return {"Authorization": f"Bearer {token}"}, user.id


def test_social_profile_waits_for_admin_approval() -> None:
    owner, owner_id = identity(); viewer, _ = identity(); admin, _ = identity(admin=True)
    created = client.put("/api/v1/friends/profile/me", headers=owner, json={
        "display_name": "Review Person", "canton": "ZH", "city": "Zürich",
        "bio": "I enjoy hiking, language exchange and meeting people around Zürich.",
        "interests": ["hiking", "languages"], "languages": ["DE", "EN"],
        "meetup_formats": ["coffee"], "guidelines_accepted": True,
        "is_visible": True, "open_to_friends": True,
    })
    assert created.status_code == 200, created.text
    assert created.json()["moderation_status"] == "pending"
    before_visible = client.get("/api/v1/friends/profiles", headers=viewer).json()["total"]
    assert not any(item["user_id"] == owner_id for item in client.get("/api/v1/friends/profiles", headers=viewer).json()["items"])

    queue = client.get("/api/v1/admin/profile-moderation?status=pending", headers=admin)
    assert queue.status_code == 200, queue.text
    assert any(item["kind"] == "social" and item["user_id"] == owner_id for item in queue.json())

    approved = client.patch(f"/api/v1/admin/profile-moderation/social/{owner_id}/approve", headers=admin, json={})
    assert approved.status_code == 200, approved.text
    assert approved.json()["moderation_status"] == "approved"
    after = client.get("/api/v1/friends/profiles", headers=viewer).json()
    assert after["total"] == before_visible + 1
    assert any(item["user_id"] == owner_id for item in after["items"])


def test_professional_profile_rejection_and_resubmission() -> None:
    owner, owner_id = identity(); viewer, _ = identity(); admin, _ = identity(admin=True)
    payload = {
        "display_name": "Business Person", "headline": "Founder in Zürich", "company_name": "Alpine",
        "role": "founder", "industry": "Technology", "canton": "ZH", "city": "Zürich",
        "bio": "Building useful products and looking for thoughtful long-term partnerships.",
        "skills": ["Product"], "languages": ["DE"], "goals": ["partners"],
        "is_visible": True, "open_to_connections": True,
    }
    created = client.put("/api/v1/network/profile/me", headers=owner, json=payload)
    assert created.status_code == 200, created.text
    assert created.json()["moderation_status"] == "pending"
    assert not any(item["user_id"] == owner_id for item in client.get("/api/v1/network/profiles", headers=viewer).json()["items"])

    rejected = client.patch(f"/api/v1/admin/profile-moderation/professional/{owner_id}/reject", headers=admin, json={"reason": "Clarify company details"})
    assert rejected.status_code == 200, rejected.text
    mine = client.get("/api/v1/network/profile/me", headers=owner).json()
    assert mine["moderation_status"] == "rejected"
    assert mine["moderation_reason"] == "Clarify company details"

    resubmitted = client.put("/api/v1/network/profile/me", headers=owner, json={**payload, "company_name": "Alpine Labs AG"})
    assert resubmitted.status_code == 200
    assert resubmitted.json()["moderation_status"] == "pending"
