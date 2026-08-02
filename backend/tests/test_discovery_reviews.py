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
            email=f"discovery_{uuid.uuid4().hex}@example.com",
            password="StrongPass1!",
            is_superuser=admin,
            role="admin" if admin else "user",
            email_verified=True,
        )
        token = create_access_token(subject=user.id, is_admin=admin, role=user.role)
    return {"Authorization": f"Bearer {token}"}


def test_discovery_review_lifecycle_and_public_aggregate() -> None:
    author = _identity()

    empty = client.get("/api/v1/discovery/matterhorn/reviews")
    assert empty.status_code == 200
    assert empty.json()["review_count"] == 0

    created = client.put(
        "/api/v1/discovery/matterhorn/reviews/me",
        headers=author,
        json={"rating": 5, "comment": "  Fantastic views and an easy train connection.  "},
    )
    assert created.status_code == 200, created.text
    assert created.json()["rating"] == 5
    assert created.json()["is_mine"] is True
    assert "@" not in created.json()["author_label"]

    updated = client.put(
        "/api/v1/discovery/matterhorn/reviews/me",
        headers=author,
        json={"rating": 4, "comment": "Beautiful, but arrive early to avoid crowds."},
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["id"] == created.json()["id"]

    page = client.get("/api/v1/discovery/matterhorn/reviews").json()
    assert page["review_count"] == 1
    assert page["average_rating"] == 4.0
    assert len(page["items"]) == 1

    summaries = client.get("/api/v1/discovery/ratings")
    assert summaries.status_code == 200
    assert len(summaries.json()) == 30
    matterhorn = next(item for item in summaries.json() if item["place_id"] == "matterhorn")
    assert matterhorn == {"place_id": "matterhorn", "average_rating": 4.0, "review_count": 1}

    mine = client.get("/api/v1/discovery/matterhorn/reviews/me", headers=author)
    assert mine.status_code == 200
    assert mine.json()["is_mine"] is True

    deleted = client.delete("/api/v1/discovery/matterhorn/reviews/me", headers=author)
    assert deleted.status_code == 204
    assert client.get("/api/v1/discovery/matterhorn/reviews").json()["review_count"] == 0

    new_destination = client.get("/api/v1/discovery/interlaken/reviews")
    assert new_destination.status_code == 200
    assert new_destination.json() == {
        "average_rating": 0.0,
        "review_count": 0,
        "items": [],
        "my_review": None,
    }


def test_discovery_review_security_validation_reporting_and_moderation() -> None:
    author = _identity()
    reporter = _identity()
    admin = _identity(admin=True)

    assert client.put(
        "/api/v1/discovery/bern/reviews/me",
        json={"rating": 5, "comment": "Excellent old town."},
    ).status_code == 401
    assert client.put(
        "/api/v1/discovery/not-real/reviews/me",
        headers=author,
        json={"rating": 5, "comment": "Unknown place."},
    ).status_code == 404
    assert client.put(
        "/api/v1/discovery/bern/reviews/me",
        headers=author,
        json={"rating": 6, "comment": "Invalid rating."},
    ).status_code == 422

    created = client.put(
        "/api/v1/discovery/bern/reviews/me",
        headers=author,
        json={"rating": 5, "comment": "Arcades are perfect on a rainy day."},
    )
    review_id = created.json()["id"]

    own_report = client.post(
        f"/api/v1/discovery/reviews/{review_id}/report",
        headers=author,
        json={"reason": "spam"},
    )
    assert own_report.status_code == 400

    reported = client.post(
        f"/api/v1/discovery/reviews/{review_id}/report",
        headers=reporter,
        json={"reason": "misinformation"},
    )
    assert reported.status_code == 200
    assert reported.json()["status"] == "reported"
    duplicate = client.post(
        f"/api/v1/discovery/reviews/{review_id}/report",
        headers=reporter,
        json={"reason": "misinformation"},
    )
    assert duplicate.json()["status"] == "already_reported"

    hidden = client.patch(
        f"/api/v1/admin/discovery/reviews/{review_id}",
        headers=admin,
        json={"status": "hidden"},
    )
    assert hidden.status_code == 200
    assert hidden.json()["comment"] == "Arcades are perfect on a rainy day."
    assert client.get("/api/v1/discovery/bern/reviews").json()["review_count"] == 0
