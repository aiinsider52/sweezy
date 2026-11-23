import uuid
from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.models.analytics import AnalyticsEvent, AnalyticsSession
from backend.app.services.users import UserService


client = TestClient(app)


def _admin_headers() -> dict[str, str]:
    with SessionLocal() as db:
        user = UserService.create(db, email=f"growth_{uuid.uuid4().hex}@example.com", password="StrongPass1!", email_verified=True)
        user.is_superuser = True
        db.commit()
        token = create_access_token(subject=user.id, is_admin=True, role="admin")
    return {"Authorization": f"Bearer {token}"}


def _seed(install: str, start: datetime, events: list[tuple[int, str, dict]]) -> None:
    with SessionLocal() as db:
        session = AnalyticsSession(
            client_session_id=f"s-{uuid.uuid4().hex}", guest_id=install, started_at=start, last_seen_at=start,
        )
        db.add(session)
        db.flush()
        for day, event_type, props in events:
            db.add(AnalyticsEvent(
                id=uuid.uuid4().hex, session_id=session.id, guest_id=install,
                occurred_at=start + timedelta(days=day), source="test", event_type=event_type,
                properties={"install_id": install, **props},
            ))
        db.commit()


def test_growth_splits_funnel_and_retention_by_source():
    start = datetime.now(timezone.utc) - timedelta(days=10)
    ads, organic = f"ads-{uuid.uuid4().hex}", f"org-{uuid.uuid4().hex}"
    _seed(ads, start, [
        (0, "install_attributed", {"source": "apple_search_ads", "campaign_id": "77", "keyword_id": "k1"}),
        (0, "onboarding_completed", {}),
        (0, "account_registered", {}),
        (1, "letter_explained", {}),
        (1, "paywall_viewed", {}),
        (7, "plus_purchased", {}),
    ])
    _seed(organic, start, [
        (0, "install_attributed", {"source": "organic"}),
        (0, "onboarding_completed", {}),
    ])

    response = client.get("/api/v1/admin/analytics/growth?days=30", headers=_admin_headers())

    assert response.status_code == 200
    body = response.json()
    sources = {item["source"]: item for item in body["sources"]}
    ads_funnel = {step["step"]: step["users"] for step in sources["apple_search_ads:77"]["funnel"]}
    assert ads_funnel == {"installs": 1, "onboarded": 1, "registered": 1, "activated": 1, "paywall": 1, "paid": 1}
    assert sources["apple_search_ads:77"]["retention"]["d1"] == 1.0
    assert sources["apple_search_ads:77"]["retention"]["d7"] == 1.0
    organic_funnel = {step["step"]: step["users"] for step in sources["organic"]["funnel"]}
    assert organic_funnel["onboarded"] == 1 and organic_funnel["activated"] == 0
    assert sources["organic"]["retention"]["d1"] == 0.0
    assert {"keyword_id": "k1", "installs": 1} in body["top_keywords"]


def test_growth_requires_admin():
    assert client.get("/api/v1/admin/analytics/growth").status_code in (401, 403)
