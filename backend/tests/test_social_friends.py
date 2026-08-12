from __future__ import annotations

from datetime import datetime, timedelta, timezone
import uuid

from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.models.event_listing import EventListing
from backend.app.services.users import UserService

client = TestClient(app)


def identity() -> tuple[dict[str, str], str]:
    with SessionLocal() as db:
        user = UserService.create(db, email=f"friends_{uuid.uuid4().hex}@example.test", password="StrongPass1!", role="user", email_verified=True)
        return {"Authorization": f"Bearer {create_access_token(subject=user.id, is_admin=False, role=user.role)}"}, user.id


def profile(headers: dict[str, str], name: str, interests: list[str], canton: str = "ZH") -> dict:
    response = client.put("/api/v1/friends/profile/me", headers=headers, json={
        "display_name": name, "canton": canton, "city": "Zürich", "bio": "Люблю знайомитися з добрими людьми та відкривати нові місця у Швейцарії.",
        "interests": interests, "languages": ["UK", "DE"], "meetup_formats": ["coffee", "event"],
        "guidelines_accepted": True, "is_visible": True, "open_to_friends": True,
    })
    assert response.status_code == 200, response.text
    assert "email" not in response.json()
    return response.json()


def event() -> str:
    with SessionLocal() as db:
        item = EventListing(title="Lake walk", description="Friendly group walk near the lake", category="community", canton="ZH", city="Zürich",
            starts_at=datetime.now(timezone.utc) + timedelta(days=2), is_free=True, contact_type="email", contact_value="host@example.test",
            organizer_name="Sweezy", status="approved")
        db.add(item); db.commit(); db.refresh(item); return item.id


def test_interest_match_event_privacy_friend_acceptance_and_chat() -> None:
    first, first_id = identity(); second, second_id = identity(); event_id = event()
    profile(first, "Anna", ["hiking", "books", "languages"])
    profile(second, "Marta", ["hiking", "books", "art"])

    matches = client.get("/api/v1/friends/profiles?interest=hiking", headers=first)
    assert matches.status_code == 200
    assert matches.json()["items"][0]["shared_interests"] == ["books", "hiking"]
    assert matches.json()["items"][0]["match_score"] > 40

    hidden = client.get(f"/api/v1/friends/profiles?event_id={event_id}", headers=first)
    assert hidden.status_code == 403
    for headers in (first, second):
        joined = client.put(f"/api/v1/friends/events/{event_id}/attendance", headers=headers, json={"status": "going", "visible_to_attendees": True})
        assert joined.status_code == 200
    people = client.get(f"/api/v1/friends/profiles?event_id={event_id}", headers=first)
    assert people.status_code == 200 and people.json()["items"][0]["user_id"] == second_id

    request = client.post(f"/api/v1/friends/profiles/{second_id}/connect", headers=first, json={"message": "Підемо разом?", "event_id": event_id})
    assert request.status_code == 201, request.text
    connection_id = request.json()["id"]
    reverse = client.post(f"/api/v1/friends/profiles/{first_id}/connect", headers=second, json={"message": "crossed"})
    assert reverse.status_code == 409
    accepted = client.patch(f"/api/v1/friends/connections/{connection_id}", headers=second, json={"status": "accepted"})
    assert accepted.status_code == 200, accepted.text
    conversation_id = accepted.json()["conversation_id"]
    conversation = client.get(f"/api/v1/chat/conversations/{conversation_id}", headers=first)
    assert conversation.status_code == 200
    assert conversation.json()["listing_type"] == "friend"
    assert conversation.json()["social_profile_id"] == first_id


def test_guidelines_required_and_private_attendance_hidden() -> None:
    first, _ = identity(); second, _ = identity(); event_id = event()
    profile(first, "Visible", ["music", "travel"]); profile(second, "Private", ["music", "travel"])
    client.put(f"/api/v1/friends/events/{event_id}/attendance", headers=first, json={"status": "interested", "visible_to_attendees": True})
    client.put(f"/api/v1/friends/events/{event_id}/attendance", headers=second, json={"status": "going", "visible_to_attendees": False})
    people = client.get(f"/api/v1/friends/profiles?event_id={event_id}", headers=first)
    assert people.status_code == 200 and people.json()["total"] == 0


def test_managed_media_avatar_is_allowed() -> None:
    headers, _ = identity()
    response = client.put("/api/v1/friends/profile/me", headers=headers, json={
        "display_name": "Photo User", "canton": "ZH", "city": "Zürich",
        "bio": "Люблю безпечні зустрічі, події та знайомства у Швейцарії.",
        "interests": ["music", "travel"], "languages": ["UK"],
        "meetup_formats": ["coffee"], "availability": ["weekend"],
        "avatar_url": "/media/1234567890abcdef1234567890abcdef.jpg",
        "guidelines_accepted": True,
    })
    assert response.status_code == 200, response.text
    assert response.json()["avatar_url"].startswith("/media/")


def test_free_search_limits_advanced_filters_and_weekly_requests() -> None:
    viewer, viewer_id = identity()
    profile(viewer, "Viewer", ["music", "travel"])
    advanced = client.get("/api/v1/friends/profiles?language=DE", headers=viewer)
    assert advanced.status_code == 402
    assert advanced.json()["detail"]["feature"] == "advanced_friend_search"

    for index in range(5):
        target, target_id = identity()
        profile(target, f"Target {index}", ["music", "travel"])
        sent = client.post(
            f"/api/v1/friends/profiles/{target_id}/connect", headers=viewer, json={"message": "Hello"}
        )
        assert sent.status_code == 201
    extra, extra_id = identity()
    profile(extra, "Extra target", ["music", "travel"])
    limited = client.post(
        f"/api/v1/friends/profiles/{extra_id}/connect", headers=viewer, json={"message": "Hello"}
    )
    assert limited.status_code == 402
    assert limited.json()["detail"]["feature"] == "friend_requests"


def test_plus_advanced_search_event_invite_and_group_chat() -> None:
    first, first_id = identity(); second, second_id = identity(); event_id = event()
    profile(first, "First", ["music", "travel"]); profile(second, "Second", ["music", "travel"])
    from backend.app.core.database import SessionLocal
    from backend.app.models.user import User
    with SessionLocal() as db:
        user = db.get(User, first_id)
        user.subscription_status = "premium"
        db.add(user); db.commit()
    filtered = client.get("/api/v1/friends/profiles?language=UK&residency=established", headers=first)
    assert filtered.status_code == 200
    assert filtered.json()["advanced_filters_available"] is True

    connection = client.post(
        f"/api/v1/friends/profiles/{second_id}/connect", headers=first, json={"message": "Meet there"}
    ).json()
    accepted = client.patch(
        f"/api/v1/friends/connections/{connection['id']}", headers=second, json={"status": "accepted"}
    )
    assert accepted.status_code == 200
    assert client.put(
        f"/api/v1/friends/events/{event_id}/attendance", headers=first, json={"status": "going"}
    ).status_code == 200
    invite = client.post(
        f"/api/v1/friends/events/{event_id}/invite", headers=first, json={"friend_user_id": second_id}
    )
    assert invite.status_code == 201
    message = client.post(
        f"/api/v1/friends/events/{event_id}/messages", headers=first, json={"body": "See you there"}
    )
    assert message.status_code == 201
    messages = client.get(f"/api/v1/friends/events/{event_id}/messages", headers=first)
    assert messages.status_code == 200 and messages.json()[0]["body"] == "See you there"
