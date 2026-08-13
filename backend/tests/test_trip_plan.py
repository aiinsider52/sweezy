import uuid

from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.models.user import User
from backend.app.services.users import UserService


client = TestClient(app)


def _headers() -> tuple[dict[str, str], str]:
    with SessionLocal() as db:
        user = UserService.create(db, email=f"trip_{uuid.uuid4().hex}@example.com", password="StrongPass1!", email_verified=True)
        token = create_access_token(subject=user.id, is_admin=False, role=user.role)
        return {"Authorization": f"Bearer {token}"}, user.id


def _payload():
    return {
        "origin": "Zürich",
        "budget_chf": 80,
        "transport": "publicTransit",
        "weather": "rain",
        "family": True,
        "available_hours": 8,
        "language": "uk",
        "candidates": [
            {"id": "st-gallen", "title": "St. Gallen", "region": "SG", "route": "Train from Zürich", "tags": ["culture", "family"]},
            {"id": "aletsch", "title": "Aletsch", "region": "VS", "route": "Train and gondola", "tags": ["nature"]},
        ],
    }


def test_trip_plan_requires_plus():
    headers, _ = _headers()
    response = client.post("/api/v1/ai/trip-plan", headers=headers, json=_payload())
    assert response.status_code == 402


def test_trip_plan_has_safe_catalog_fallback():
    headers, user_id = _headers()
    with SessionLocal() as db:
        user = db.get(User, user_id)
        user.subscription_status = "premium"
        db.commit()
    response = client.post("/api/v1/ai/trip-plan", headers=headers, json=_payload())
    assert response.status_code == 200
    body = response.json()
    assert body["selected_place_id"] in {"st-gallen", "aletsch"}
    assert body["itinerary"]
    assert body["generated_by_ai"] is False
