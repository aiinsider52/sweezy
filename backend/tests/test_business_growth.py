from __future__ import annotations

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
import uuid

from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token, decode_token
from backend.app.main import app
from backend.app.models.business import BusinessBooking, BusinessClient, BusinessProfile
from backend.app.models.user import User
from backend.app.services.business_plans import apply_business_transaction
from backend.app.services.users import UserService


client = TestClient(app)


def _headers(*, admin: bool = False) -> dict[str, str]:
    with SessionLocal() as db:
        user = UserService.create(
            db,
            email=f"growth_{uuid.uuid4().hex}@example.test",
            password="StrongPass1!",
            is_superuser=admin,
            role="admin" if admin else "user",
            email_verified=True,
        )
        token = create_access_token(subject=user.id, is_admin=admin, role=user.role)
    return {"Authorization": f"Bearer {token}"}


def _subject(headers: dict[str, str]) -> str:
    return decode_token(headers["Authorization"].split(" ", 1)[1])["sub"]


ADMIN: dict[str, str] = {}


def _admin() -> dict[str, str]:
    if not ADMIN:
        ADMIN.update(_headers(admin=True))
    return ADMIN


def _business(
    *,
    name: str,
    kind: str = "business",
    category: str = "beauty",
    languages: list[str] | None = None,
    country: str = "AT",
    subdivision: str = "AT-9",
    city: str = "Wien",
    plan: str | None = None,
    boosted: bool = False,
    approve: bool = True,
    location: bool = True,
) -> dict[str, str]:
    headers = _headers()
    saved = client.put("/api/v1/business/profile", headers=headers, json={
        "kind": kind,
        "display_name": name,
        "tagline": f"{name} tagline",
        "legal_name": f"{name} GmbH",
        "represented_by": "Olena Koval",
        "description": f"{name} serves the Ukrainian community.",
        "category": category,
        "country_code": country,
        "subdivision_code": subdivision,
        "city": city,
        "address": "Mariahilfer Strasse 1, 1060 Wien",
        "latitude": 48.2 if location else None,
        "longitude": 16.35 if location else None,
        "languages": languages or ["uk", "de"],
        "delivery_modes": ["onsite"],
        "social_links": {"instagram": "@ukr.wien", "telegram": "https://t.me/ukrwien"},
        "photo_urls": ["https://example.test/a.jpg"],
    })
    assert saved.status_code == 200, saved.text
    assert client.post("/api/v1/business/profile/submit", headers=headers).status_code == 200
    user_id = _subject(headers)
    if approve:
        reviewed = client.patch(
            f"/api/v1/admin/businesses/{user_id}/review",
            headers=_admin(),
            json={"decision": "approve"},
        )
        assert reviewed.status_code == 200, reviewed.text
    if plan or boosted:
        with SessionLocal() as db:
            profile = db.get(BusinessProfile, user_id)
            if plan:
                profile.plan = plan
                profile.plan_expires_at = datetime.now(timezone.utc) + timedelta(days=30)
            if boosted:
                profile.boost_until = datetime.now(timezone.utc) + timedelta(days=7)
            db.add(profile)
            db.commit()
    return headers


def _visit(business_headers: dict[str, str], customer_headers: dict[str, str]) -> None:
    """Simulates a confirmed appointment in the past, which unlocks writing a review."""
    with SessionLocal() as db:
        business_id = _subject(business_headers)
        customer_id = _subject(customer_headers)
        customer = BusinessClient(business_user_id=business_id, customer_user_id=customer_id, display_name="Client")
        db.add(customer)
        db.flush()
        starts = datetime.now(timezone.utc) - timedelta(days=2)
        db.add(BusinessBooking(
            business_user_id=business_id,
            client_id=customer.id,
            customer_name="Client",
            starts_at=starts,
            ends_at=starts + timedelta(hours=1),
            status="completed",
        ))
        db.commit()


def test_directory_ranks_sponsored_then_paid_and_filters() -> None:
    city = f"Graz-{uuid.uuid4().hex[:6]}"
    common = {"country": "AT", "subdivision": "AT-6", "city": city}
    free = _business(name="Free Salon", **common)
    pro = _business(name="Pro Salon", plan="pro", **common)
    boosted = _business(name="Boosted Salon", boosted=True, languages=["de"], **common)
    _business(name="Hidden Salon", approve=False, **common)
    _business(name="Club Graz", kind="club", category="community", location=False, **common)

    response = client.get("/api/v1/businesses/directory", params={"country": "AT", "city": city, "kind": "business"})
    assert response.status_code == 200, response.text
    items = response.json()["items"]
    names = [item["display_name"] for item in items]
    assert "Hidden Salon" not in names
    assert names[:3] == ["Boosted Salon", "Pro Salon", "Free Salon"]
    assert items[0]["is_sponsored"] is True and items[1]["plan"] == "pro"

    ukrainian = client.get("/api/v1/businesses/directory", params={"city": city, "language": "uk", "kind": "business"}).json()
    assert {item["user_id"] for item in ukrainian["items"]} == {_subject(free), _subject(pro)}
    clubs = client.get("/api/v1/businesses/directory", params={"city": city, "kind": "club"}).json()
    assert [item["display_name"] for item in clubs["items"]] == ["Club Graz"]
    mapped = client.get("/api/v1/businesses/directory", params={"city": city, "with_location": True}).json()
    assert "Club Graz" not in {item["display_name"] for item in mapped["items"]}
    searched = client.get("/api/v1/businesses/directory", params={"city": city, "q": "boosted"}).json()
    assert [item["user_id"] for item in searched["items"]] == [_subject(boosted)]


def test_public_page_impressum_and_contextual_helpers() -> None:
    translator = _business(name="Dokument Profi", kind="specialist", category="translation", country="DE", subdivision="DE-BE", city="Berlin")
    page = client.get(f"/api/v1/businesses/{_subject(translator)}")
    assert page.status_code == 200, page.text
    body = page.json()
    assert body["kind"] == "specialist"
    assert body["impressum"]["legal_name"] == "Dokument Profi GmbH"
    assert body["impressum"]["represented_by"] == "Olena Koval"
    assert body["social_links"]["telegram"] == "https://t.me/ukrwien"

    helpers = client.get("/api/v1/businesses/contextual", params={"topic": "documents", "country": "DE", "subdivision": "DE-BE"})
    assert helpers.status_code == 200
    assert _subject(translator) in {item["user_id"] for item in helpers.json()}
    assert client.get("/api/v1/businesses/contextual", params={"topic": "unknown"}).json() == []


def test_tracking_feeds_owner_stats_with_plan_window() -> None:
    owner = _business(name="Stats Cafe", category="food")
    business_id = _subject(owner)
    for event in ("view", "view", "call", "route"):
        assert client.post(f"/api/v1/businesses/{business_id}/track", json={"event": event}).status_code == 204
    assert client.post(f"/api/v1/businesses/{business_id}/track", json={"event": "bogus"}).status_code == 422

    stats = client.get("/api/v1/business/stats", params={"days": 30}, headers=owner)
    assert stats.status_code == 200, stats.text
    body = stats.json()
    assert body["max_days"] == 7 and body["days"] == 7
    assert body["totals"]["view"] == 2 and body["totals"]["call"] == 1
    assert body["series"][-1] == {"day": datetime.now(timezone.utc).date().isoformat(), "views": 2, "actions": 2}


def test_reviews_require_visit_update_rating_and_moderation() -> None:
    owner = _business(name="Review Barber")
    business_id = _subject(owner)
    customer = _headers()

    eligibility = client.get(f"/api/v1/businesses/{business_id}/reviews/eligibility", headers=customer).json()
    assert eligibility == {"can_review": False, "reason": "review_requires_visit", "existing": None}
    denied = client.post(f"/api/v1/businesses/{business_id}/reviews", headers=customer, json={"rating": 5, "text": "Great"})
    assert denied.status_code == 403

    _visit(owner, customer)
    created = client.post(f"/api/v1/businesses/{business_id}/reviews", headers=customer, json={"rating": 4, "text": " Good cut "})
    assert created.status_code == 201, created.text
    assert created.json()["text"] == "Good cut"
    updated = client.post(f"/api/v1/businesses/{business_id}/reviews", headers=customer, json={"rating": 2, "text": "Changed"})
    assert updated.status_code == 201
    assert updated.json()["id"] == created.json()["id"]

    second = _headers()
    _visit(owner, second)
    assert client.post(f"/api/v1/businesses/{business_id}/reviews", headers=second, json={"rating": 5}).status_code == 201
    page = client.get(f"/api/v1/businesses/{business_id}").json()
    assert page["review_count"] == 2 and page["average_rating"] == 3.5

    reply = client.post(f"/api/v1/business/reviews/{created.json()['id']}/reply", headers=owner, json={"text": "Дякуємо!"})
    assert reply.status_code == 200 and reply.json()["owner_reply"] == "Дякуємо!"
    assert client.post(f"/api/v1/businesses/{business_id}/reviews", headers=owner, json={"rating": 5}).status_code == 409

    hidden = client.patch(f"/api/v1/admin/business-reviews/{created.json()['id']}", headers=_admin(), json={"status": "hidden"})
    assert hidden.status_code == 200
    page = client.get(f"/api/v1/businesses/{business_id}").json()
    assert page["review_count"] == 1 and page["average_rating"] == 5.0
    assert [item["rating"] for item in client.get(f"/api/v1/businesses/{business_id}/reviews").json()] == [5]


def test_offers_need_pro_and_appear_in_public_feed() -> None:
    owner = _business(name="Offer Bakery", category="food", country="CH", subdivision="ZH", city="Zürich")
    offer = {"title": "Borscht lunch", "discount_label": "-15%", "promo_code": "SWEEZY"}
    assert client.post("/api/v1/business/offers", headers=owner, json=offer).status_code == 402

    with SessionLocal() as db:
        profile = db.get(BusinessProfile, _subject(owner))
        profile.plan = "pro"
        profile.plan_expires_at = datetime.now(timezone.utc) + timedelta(days=30)
        db.commit()
    created = client.post("/api/v1/business/offers", headers=owner, json=offer)
    assert created.status_code == 201, created.text
    expired = client.post("/api/v1/business/offers", headers=owner, json={
        **offer,
        "title": "Old deal",
        "ends_at": (datetime.now(timezone.utc) - timedelta(days=1)).isoformat(),
    })
    assert expired.status_code == 201
    for index in range(3):
        assert client.post("/api/v1/business/offers", headers=owner, json={**offer, "title": f"Deal {index}"}).status_code == 201
    assert client.post("/api/v1/business/offers", headers=owner, json={**offer, "title": "Too many"}).status_code == 409

    feed = client.get("/api/v1/businesses/offers", params={"country": "CH", "subdivision": "ZH"}).json()
    titles = {item["title"] for item in feed if item["business"]["user_id"] == _subject(owner)}
    assert "Borscht lunch" in titles and "Old deal" not in titles
    page = client.get(f"/api/v1/businesses/{_subject(owner)}").json()
    assert "Borscht lunch" in {item["title"] for item in page["offers"]}
    directory = client.get("/api/v1/businesses/directory", params={"q": "Offer Bakery"}).json()
    assert directory["items"][0]["top_offer_label"] == "-15%"


def test_clubs_accept_member_businesses() -> None:
    club = _business(name="UA Business Club Wien", kind="club", category="community")
    member = _business(name="Member Studio")
    club_id = _subject(club)
    member_id = _subject(member)

    joined = client.post(f"/api/v1/business/clubs/{club_id}/join", headers=member)
    assert joined.status_code == 201, joined.text
    assert joined.json()["status"] == "pending"
    assert client.post(f"/api/v1/business/clubs/{member_id}/join", headers=club).status_code == 409

    requests = client.get("/api/v1/business/club/members", headers=club).json()
    assert [item["business"]["user_id"] for item in requests] == [member_id]
    approved = client.patch(f"/api/v1/business/club/members/{requests[0]['id']}", headers=club, json={"status": "approved"})
    assert approved.status_code == 200

    club_page = client.get(f"/api/v1/businesses/{club_id}").json()
    assert [item["user_id"] for item in club_page["members"]] == [member_id]
    member_page = client.get(f"/api/v1/businesses/{member_id}").json()
    assert [item["user_id"] for item in member_page["clubs"]] == [club_id]
    assert client.get("/api/v1/business/clubs/mine", headers=member).json()[0]["status"] == "approved"


def _transaction(user_id: str, product: str, transaction_id: str, *, expires: datetime | None = None) -> SimpleNamespace:
    return SimpleNamespace(
        bundleId="com.sweezy.mobile",
        productId=product,
        transactionId=transaction_id,
        originalTransactionId=f"orig-{product}-{user_id}",
        appAccountToken=user_id,
        expiresDate=int(expires.timestamp() * 1000) if expires else None,
        revocationDate=None,
        isUpgraded=False,
        environment=None,
        rawEnvironment="Sandbox",
    )


def test_apple_business_purchases_set_plan_and_boost_once() -> None:
    owner = _business(name="Purchase Spa")
    user_id = _subject(owner)
    with SessionLocal() as db:
        user = db.get(User, user_id)
        expires = datetime.now(timezone.utc) + timedelta(days=30)
        apply_business_transaction(db, user, _transaction(user_id, "sweezy_business_pro_monthly", "t-plan-1", expires=expires))
        boost = _transaction(user_id, "sweezy_business_boost_7d", "t-boost-1")
        profile = apply_business_transaction(db, user, boost)
        first_boost = profile.boost_until
        profile = apply_business_transaction(db, user, boost)
        assert profile.boost_until == first_boost

    plan = client.get("/api/v1/business/plan", headers=owner).json()
    assert plan["effective_plan"] == "pro" and plan["is_boosted"] is True
    assert plan["limits"]["offers"] == 5
    assert "sweezy_business_boost_7d" in plan["product_ids"]
    listing = client.get("/api/v1/businesses/directory", params={"q": "Purchase Spa"}).json()["items"][0]
    assert listing["is_sponsored"] is True

    other = _headers()
    with SessionLocal() as db:
        stranger = db.get(User, _subject(other))
        try:
            apply_business_transaction(db, stranger, _transaction(user_id, "sweezy_business_boost_7d", "t-boost-2"))
        except Exception as exc:  # noqa: BLE001 - asserting the error type below
            assert "another Sweezy account" in str(exc) or "Business profile required" in str(exc)
        else:
            raise AssertionError("Purchase for another account must be rejected")

    # Server-side App Store verification is not configured in tests.
    synced = client.post("/api/v1/business/plan/apple", headers=owner, json={"signed_transaction": "a.b.c.d.e.f"})
    assert synced.status_code in {422, 503}


def test_admin_grants_launch_plan() -> None:
    owner = _business(name="Launch Partner")
    granted = client.patch(
        f"/api/v1/admin/businesses/{_subject(owner)}/plan",
        headers=_admin(),
        json={"plan": "business", "days": 90},
    )
    assert granted.status_code == 200, granted.text
    assert granted.json()["effective_plan"] == "business"
    assert client.get("/api/v1/business/plan", headers=owner).json()["limits"]["ai_receptionist"] is True


def test_account_deletion_removes_written_reviews() -> None:
    owner = _business(name="Deletion Nails")
    customer = _headers()
    _visit(owner, customer)
    business_id = _subject(owner)
    assert client.post(f"/api/v1/businesses/{business_id}/reviews", headers=customer, json={"rating": 1}).status_code == 201
    with SessionLocal() as db:
        UserService.delete_account(db, user=db.get(User, _subject(customer)))
    page = client.get(f"/api/v1/businesses/{business_id}").json()
    assert page["review_count"] == 0 and page["average_rating"] is None


def test_profile_accepts_uploaded_media_and_rejects_unsafe_links() -> None:
    headers = _headers()
    base = {
        "display_name": "Media Check",
        "description": "Checks image and social link validation.",
        "country_code": "CH",
        "subdivision_code": "ZH",
        "city": "Zürich",
    }
    media = "/media/" + "a" * 32 + ".jpg"
    ok = client.put("/api/v1/business/profile", headers=headers, json={**base, "logo_url": media, "photo_urls": [media, "https://cdn.example.test/p.jpg"]})
    assert ok.status_code == 200, ok.text
    assert ok.json()["logo_url"] == media

    for payload in (
        {"logo_url": "/media/../secret.jpg"},
        {"photo_urls": ["http://insecure.example.test/p.jpg"]},
        {"social_links": {"telegram": "javascript://alert(1)"}},
        {"social_links": {"myspace": "@old"}},
    ):
        rejected = client.put("/api/v1/business/profile", headers=headers, json={**base, **payload})
        assert rejected.status_code == 422, payload
