from __future__ import annotations

import uuid

from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.services.users import UserService
from backend.app.models.user import User


client = TestClient(app)


def _user_headers(*, admin: bool = False) -> dict[str, str]:
    with SessionLocal() as db:
        user = UserService.create(
            db,
            email=f"market_{uuid.uuid4().hex}@example.com",
            password="StrongPass1!",
            is_superuser=admin,
            role="admin" if admin else "user",
            email_verified=True,
        )
        token = create_access_token(subject=user.id, is_admin=admin, role=user.role)
    return {"Authorization": f"Bearer {token}"}


def test_report_is_idempotent_and_block_hides_author() -> None:
    owner = _user_headers()
    viewer = _user_headers()
    admin = _user_headers(admin=True)

    created = client.post(
        "/api/v1/marketplace/",
        headers=owner,
        json={
            "listing_type": "service",
            "title": "Verified relocation help",
            "description": "Practical relocation support in Zurich with transparent pricing.",
            "category": "documents",
            "canton": "ZH",
            "price_info": "CHF 80/hour",
            "contact_type": "email",
            "contact_value": "helper@example.com",
            "author_name": "Helper",
            "image_urls": [],
        },
    )
    assert created.status_code == 201
    listing_id = created.json()["id"]

    approved = client.patch(
        f"/api/v1/admin/marketplace/{listing_id}/approve",
        headers=admin,
        json={"is_verified": True},
    )
    assert approved.status_code == 200
    assert approved.json()["last_moderated_at"] is not None

    report = client.post(
        f"/api/v1/marketplace/{listing_id}/report",
        headers=viewer,
        json={"reason": "misleading"},
    )
    assert report.status_code == 200

    duplicate = client.post(
        f"/api/v1/marketplace/{listing_id}/report",
        headers=viewer,
        json={"reason": "spam"},
    )
    assert duplicate.status_code == 200
    detail = client.get(f"/api/v1/marketplace/{listing_id}").json()
    assert detail["report_count"] == 1

    blocked = client.post(f"/api/v1/marketplace/{listing_id}/block", headers=viewer)
    assert blocked.status_code == 200
    viewer_feed = client.get("/api/v1/marketplace/", headers=viewer).json()["items"]
    assert listing_id not in {item["id"] for item in viewer_feed}
    public_feed = client.get("/api/v1/marketplace/").json()["items"]
    assert listing_id in {item["id"] for item in public_feed}


def test_marketplace_pro_dashboard_and_promotion() -> None:
    owner = _user_headers()
    admin = _user_headers(admin=True)
    created = client.post("/api/v1/marketplace/", headers=owner, json={
        "listing_type": "service", "title": "Pro service",
        "description": "Reliable local service with transparent conditions.",
        "category": "other", "canton": "ZH", "price_info": "CHF 80",
        "contact_type": "email", "contact_value": "owner@example.test",
        "author_name": "Owner", "image_urls": [],
    })
    assert created.status_code == 201
    listing_id = created.json()["id"]
    assert client.get("/api/v1/marketplace/pro/dashboard", headers=owner).status_code == 402
    assert client.patch(f"/api/v1/admin/marketplace/{listing_id}/approve", headers=admin, json={}).status_code == 200

    token = owner["Authorization"].split()[1]
    from backend.app.core.security import decode_token
    user_id = decode_token(token)["sub"]
    with SessionLocal() as db:
        user = db.get(User, user_id)
        user.subscription_status = "premium"
        db.add(user); db.commit()

    promoted = client.post(f"/api/v1/marketplace/{listing_id}/promote", headers=owner)
    assert promoted.status_code == 200
    assert promoted.json()["is_featured"] is True
    assert promoted.json()["featured_until"] is not None
    dashboard = client.get("/api/v1/marketplace/pro/dashboard", headers=owner)
    assert dashboard.status_code == 200
    assert dashboard.json()["publication_limit"] == 20
