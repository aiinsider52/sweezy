from __future__ import annotations

import json
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from backend.app.core.config import get_settings
from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.models.chat import NotificationOutbox
from backend.app.models.event_listing import EventListing
from backend.app.models.marketplace import ServiceListing
from backend.app.models.notification import NotificationPreference
from backend.app.models.social import SocialProfile, SocialSwipe
from backend.app.services import engagement_push
from backend.app.services.engagement_push import deliver_at, enqueue_engagement, run_engagement_jobs
from backend.app.services.users import UserService

client = TestClient(app)

# Sunday 26 Oct 2031, 19:00 in Zurich (CET, UTC+1): inside the likes digest window.
SUNDAY_EVENING = datetime(2031, 10, 26, 18, 0, tzinfo=timezone.utc)


@pytest.fixture(autouse=True)
def enable_push_outbox():
    settings = get_settings()
    previous = settings.PUSH_NOTIFICATIONS_ENABLED
    settings.PUSH_NOTIFICATIONS_ENABLED = True
    try:
        yield
    finally:
        settings.PUSH_NOTIFICATIONS_ENABLED = previous


def identity() -> tuple[dict[str, str], str]:
    with SessionLocal() as db:
        user = UserService.create(db, email=f"engage_{uuid.uuid4().hex}@example.test", password="StrongPass1!", role="user", email_verified=True)
        return {"Authorization": f"Bearer {create_access_token(subject=user.id, is_admin=False, role=user.role)}"}, user.id


def social_profile(user_id: str, subdivision: str = "ZH") -> None:
    with SessionLocal() as db:
        db.add(SocialProfile(
            user_id=user_id, display_name="Anna", canton=subdivision, country_code="CH", subdivision_code=subdivision,
            city="Zürich", bio="Привіт", interests=["hiking"], languages=["UK"], meetup_formats=["coffee"],
            guidelines_accepted=True, moderation_status="approved",
        ))
        db.commit()


def listing(author_id: str, *, price_minor: int | None = 20000, subdivision: str = "ZH", category: str = "furniture", created_at: datetime | None = None) -> str:
    with SessionLocal() as db:
        item = ServiceListing(
            listing_type="item", title="Дивани IKEA", description="Майже новий диван", category=category,
            canton=subdivision, country_code="CH", subdivision_code=subdivision, price_minor=price_minor,
            currency_code="CHF", contact_type="email", contact_value="seller@example.test",
            author_id=author_id, author_name="Seller", status="approved",
            created_at=created_at or datetime.now(timezone.utc),
        )
        db.add(item); db.commit(); db.refresh(item)
        return item.id


def pushes(user_id: str, kind: str | None = None) -> list[NotificationOutbox]:
    with SessionLocal() as db:
        query = select(NotificationOutbox).where(NotificationOutbox.recipient_id == user_id)
        if kind:
            query = query.where(NotificationOutbox.event_type == kind)
        return list(db.execute(query).scalars().all())


def alert(row: NotificationOutbox) -> dict:
    return json.loads(row.payload_json)["aps"]["alert"]


def test_preferences_roundtrip_and_validation() -> None:
    headers, _ = identity()
    initial = client.get("/api/v1/notifications/preferences", headers=headers)
    assert initial.status_code == 200
    assert initial.json() == {
        "locale": "uk", "timezone": "Europe/Zurich",
        "social_enabled": True, "events_enabled": True, "marketplace_enabled": True,
    }
    updated = client.put("/api/v1/notifications/preferences", headers=headers, json={"locale": "de", "timezone": "Europe/Berlin", "events_enabled": False})
    assert updated.status_code == 200
    assert updated.json()["locale"] == "de" and updated.json()["events_enabled"] is False
    assert client.put("/api/v1/notifications/preferences", headers=headers, json={"timezone": "Mars/Base"}).status_code == 422


def test_price_drop_reaches_watchers_in_their_language() -> None:
    seller_headers, seller_id = identity()
    buyer_headers, buyer_id = identity()
    listing_id = listing(seller_id)
    client.put("/api/v1/notifications/preferences", headers=buyer_headers, json={"locale": "en"})
    assert client.put(f"/api/v1/notifications/listing-watches/{listing_id}", headers=buyer_headers).status_code == 204

    raised = client.patch(f"/api/v1/marketplace/{listing_id}", headers=seller_headers, json={"price_minor": 25000})
    assert raised.status_code == 200
    assert pushes(buyer_id, "price_drop") == []

    dropped = client.patch(f"/api/v1/marketplace/{listing_id}", headers=seller_headers, json={"price_minor": 15000})
    assert dropped.status_code == 200
    [row] = pushes(buyer_id, "price_drop")
    assert alert(row)["title"] == "Price dropped"
    assert "250 CHF → 150 CHF" in alert(row)["body"]
    assert json.loads(row.payload_json)["listing_id"] == listing_id
    assert pushes(seller_id, "price_drop") == []

    assert client.delete(f"/api/v1/notifications/listing-watches/{listing_id}", headers=buyer_headers).status_code == 204
    client.patch(f"/api/v1/marketplace/{listing_id}", headers=seller_headers, json={"price_minor": 9000})
    assert len(pushes(buyer_id, "price_drop")) == 1


def test_view_milestone_tells_the_author_once() -> None:
    _, seller_id = identity()
    listing_id = listing(seller_id)
    with SessionLocal() as db:
        db.get(ServiceListing, listing_id).view_count = 9
        db.commit()
    assert client.get(f"/api/v1/marketplace/{listing_id}").status_code == 200
    assert client.get(f"/api/v1/marketplace/{listing_id}").status_code == 200
    [row] = pushes(seller_id, "listing_views")
    assert alert(row)["title"] == "Твоє оголошення переглянули 10 разів"


def test_follow_announces_new_listings_and_respects_daily_cap() -> None:
    headers, follower_id = identity()
    _, seller_id = identity()
    created = client.post("/api/v1/notifications/marketplace-follows", headers=headers, json={"country_code": "CH", "subdivision_code": "BE", "category": "furniture"})
    assert created.status_code == 201
    assert client.post("/api/v1/notifications/marketplace-follows", headers=headers, json={"country_code": "CH", "subdivision_code": "BE", "category": "furniture"}).json()["id"] == created.json()["id"]
    assert client.post("/api/v1/notifications/marketplace-follows", headers=headers, json={"country_code": "CH", "subdivision_code": "XX"}).status_code == 422

    soon = datetime.now(timezone.utc) + timedelta(seconds=5)
    listing(seller_id, subdivision="BE", created_at=soon)
    listing(seller_id, subdivision="BE", category="electronics", created_at=soon)  # other category
    listing(seller_id, subdivision="ZH", created_at=soon)  # other canton
    listing(seller_id, subdivision="BE", created_at=soon)
    run_engagement_jobs(datetime.now(timezone.utc) + timedelta(minutes=1))
    [row] = pushes(follower_id, "listing_follow")
    assert alert(row)["title"] == "Нове оголошення · Bern"
    assert alert(row)["body"].endswith("і ще 1")

    # Already had its one promotional push today: the next listing waits for tomorrow.
    listing(seller_id, subdivision="BE", created_at=datetime.now(timezone.utc) + timedelta(minutes=2))
    run_engagement_jobs(datetime.now(timezone.utc) + timedelta(minutes=3))
    assert len(pushes(follower_id, "listing_follow")) == 1

    assert client.delete(f"/api/v1/notifications/marketplace-follows/{created.json()['id']}", headers=headers).status_code == 204
    assert client.get("/api/v1/notifications/marketplace-follows", headers=headers).json() == []


def test_weekly_likes_digest_counts_unanswered_likes_on_sunday_evening() -> None:
    _, target_id = identity()
    social_profile(target_id)
    likers = []
    for _ in range(3):
        _, liker_id = identity()
        social_profile(liker_id)
        likers.append(liker_id)
    with SessionLocal() as db:
        for liker_id in likers:
            db.add(SocialSwipe(swiper_id=liker_id, target_id=target_id, decision="like", created_at=SUNDAY_EVENING - timedelta(days=1)))
        # Already liked back: not a mystery any more, so it does not count.
        db.add(SocialSwipe(swiper_id=target_id, target_id=likers[0], decision="like", created_at=SUNDAY_EVENING - timedelta(hours=2)))
        db.commit()

    run_engagement_jobs(SUNDAY_EVENING - timedelta(days=1))  # Saturday: nothing
    assert pushes(target_id, "likes_digest") == []
    run_engagement_jobs(SUNDAY_EVENING)
    [row] = pushes(target_id, "likes_digest")
    assert alert(row)["title"] == "Тебе лайкнули 2 людини цього тижня"
    run_engagement_jobs(SUNDAY_EVENING + timedelta(minutes=30))
    assert len(pushes(target_id, "likes_digest")) == 1


def test_event_nearby_in_the_morning_skips_switched_off_users() -> None:
    headers, user_id = identity()
    _, muted_id = identity()
    social_profile(user_id, "LU")
    social_profile(muted_id, "LU")
    with SessionLocal() as db:
        db.add(NotificationPreference(user_id=muted_id, events_enabled=False))
        db.commit()
    morning = datetime.now(timezone.utc).replace(hour=10, minute=0, second=0, microsecond=0) + timedelta(days=1)
    with SessionLocal() as db:
        db.add(EventListing(
            title="Ранкова кава біля озера", description="Знайомимось", category="community", canton="LU",
            country_code="CH", subdivision_code="LU", city="Luzern", starts_at=morning + timedelta(days=2),
            is_free=True, contact_type="email", contact_value="host@example.test", organizer_name="Sweezy",
            status="approved", created_at=morning - timedelta(hours=1),
        ))
        db.commit()
    run_engagement_jobs(morning)
    [row] = pushes(user_id, "event_nearby")
    assert alert(row)["title"] == "Нова подія поруч: Ранкова кава біля озера"
    assert "Luzern" in alert(row)["body"]
    assert pushes(muted_id, "event_nearby") == []


def test_quiet_hours_hold_delivery_until_morning() -> None:
    night = datetime(2031, 10, 27, 22, 30, tzinfo=timezone.utc)  # 23:30 in Zurich
    assert deliver_at("Europe/Zurich", night) == datetime(2031, 10, 28, 8, 0, tzinfo=timezone.utc)
    early = datetime(2031, 10, 28, 5, 0, tzinfo=timezone.utc)  # 06:00 in Zurich
    assert deliver_at("Europe/Zurich", early) == datetime(2031, 10, 28, 8, 0, tzinfo=timezone.utc)
    day = datetime(2031, 10, 28, 12, 0, tzinfo=timezone.utc)
    assert deliver_at("Europe/Zurich", day) == day


def test_switched_off_category_drops_matches() -> None:
    _, user_id = identity()
    with SessionLocal() as db:
        db.add(NotificationPreference(user_id=user_id, social_enabled=False))
        db.commit()
        assert not enqueue_engagement(db, user_id=user_id, kind="friend_match", event_key=f"t:{uuid.uuid4()}", params={"name": "Anna", "score": 80})
    assert engagement_push.PREFERENCE_FIELD["friend_match"] == "social_enabled"
