from __future__ import annotations

from datetime import datetime, timedelta, timezone
import uuid

from fastapi.testclient import TestClient

from backend.app.core.config import get_settings
from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token, decode_token
from backend.app.main import app
from backend.app.models.user import User
from backend.app.services.users import UserService


client = TestClient(app)


def _headers(*, premium: bool = True, admin: bool = False) -> dict[str, str]:
    with SessionLocal() as db:
        user = UserService.create(
            db,
            email=f"business_{uuid.uuid4().hex}@example.test",
            password="StrongPass1!",
            is_superuser=admin,
            role="admin" if admin else "user",
            email_verified=True,
        )
        if premium:
            user.subscription_status = "premium"
            user.subscription_expire_at = datetime.now(timezone.utc) + timedelta(days=30)
            db.add(user)
            db.commit()
        token = create_access_token(subject=user.id, is_admin=admin, role=user.role)
    return {"Authorization": f"Bearer {token}"}


def _profile(headers: dict[str, str]) -> dict:
    response = client.put("/api/v1/business/profile", headers=headers, json={
        "display_name": "Züri Clean",
        "legal_name": "Züri Clean GmbH",
        "description": "Reliable home cleaning in Zürich and nearby communities.",
        "category": "cleaning",
        "canton": "ZH",
        "city": "Zürich",
        "service_area": ["ZH"],
        "languages": ["de", "uk"],
        "delivery_modes": ["mobile"],
        "cancellation_policy": "Free cancellation up to 24 hours before appointment.",
    })
    assert response.status_code == 200, response.text
    return response.json()


def _subject(headers: dict[str, str]) -> str:
    return decode_token(headers["Authorization"].split(" ", 1)[1])["sub"]


def test_business_requires_plus() -> None:
    headers = _headers(premium=False)
    response = client.get("/api/v1/business/profile", headers=headers)
    assert response.status_code == 402


def test_business_profile_services_dashboard_and_review() -> None:
    headers = _headers()
    admin = _headers(admin=True)
    saved = _profile(headers)
    assert saved["status"] == "draft"
    submitted = client.post("/api/v1/business/profile/submit", headers=headers)
    assert submitted.status_code == 200
    assert submitted.json()["status"] == "pending"

    queue = client.get("/api/v1/admin/businesses?status=pending", headers=admin)
    assert queue.status_code == 200
    assert saved["user_id"] in {item["user_id"] for item in queue.json()}
    approved = client.patch(
        f"/api/v1/admin/businesses/{saved['user_id']}/review",
        headers=admin,
        json={"decision": "approve", "comment": "Verified"},
    )
    assert approved.status_code == 200
    assert approved.json()["status"] == "approved"
    assert approved.json()["is_verified"] is True

    service = client.post("/api/v1/business/services", headers=headers, json={
        "title": "Home cleaning",
        "description": "Two-hour apartment cleaning.",
        "category": "cleaning",
        "duration_minutes": 120,
        "price_cents": 12000,
        "delivery_mode": "mobile",
    })
    assert service.status_code == 201, service.text
    dashboard = client.get("/api/v1/business/dashboard", headers=headers)
    assert dashboard.status_code == 200, dashboard.text
    assert dashboard.json()["profile"]["display_name"] == "Züri Clean"


def test_booking_conflict_and_completion_updates_client() -> None:
    headers = _headers()
    _profile(headers)
    customer = client.post("/api/v1/business/clients", headers=headers, json={"display_name": "Anna"})
    assert customer.status_code == 201
    starts = datetime.now(timezone.utc) + timedelta(days=2)
    payload = {
        "client_id": customer.json()["id"],
        "customer_name": "Anna",
        "starts_at": starts.isoformat(),
        "ends_at": (starts + timedelta(hours=1)).isoformat(),
        "status": "confirmed",
        "price_cents": 9500,
    }
    first = client.post("/api/v1/business/bookings", headers=headers, json=payload)
    assert first.status_code == 201, first.text
    conflict = client.post("/api/v1/business/bookings", headers=headers, json=payload)
    assert conflict.status_code == 409
    completed = client.patch(
        f"/api/v1/business/bookings/{first.json()['id']}",
        headers=headers,
        json={"status": "completed"},
    )
    assert completed.status_code == 200
    clients = client.get("/api/v1/business/clients", headers=headers).json()
    assert clients[0]["completed_count"] == 1
    assert clients[0]["total_spend_cents"] == 9500


def test_custom_ai_receptionist_fallback_is_safe(monkeypatch) -> None:
    headers = _headers()
    _profile(headers)
    settings = get_settings()
    monkeypatch.setattr(settings, "OPENAI_API_KEY", None)
    configured = client.put("/api/v1/business/ai-settings", headers=headers, json={
        "ai_enabled": True,
        "ai_auto_reply": False,
        "ai_tone": "warm",
        "ai_business_facts": "We clean apartments Monday through Friday.",
        "ai_instructions": "Ask for apartment size.",
        "ai_greeting": "Danke! Wie gross ist Ihre Wohnung?",
        "ai_faq": [{"question": "Do you bring supplies?", "answer": "Yes."}],
        "ai_handoff_topics": ["refund"],
        "ai_allowed_languages": ["de", "uk"],
    })
    assert configured.status_code == 200
    draft = client.post("/api/v1/business/ai-receptionist/draft", headers=headers, json={
        "customer_name": "Mia",
        "customer_language": "de",
        "messages": [{"role": "customer", "content": "Kann ich nächste Woche buchen?"}],
    })
    assert draft.status_code == 200, draft.text
    assert draft.json()["reply"] == "Danke! Wie gross ist Ihre Wohnung?"
    assert draft.json()["generated_by_ai"] is False


def test_public_profile_slots_booking_and_customer_cancellation() -> None:
    owner_headers = _headers()
    admin_headers = _headers(admin=True)
    owner = _profile(owner_headers)
    assert client.post("/api/v1/business/profile/submit", headers=owner_headers).status_code == 200
    assert client.patch(
        f"/api/v1/admin/businesses/{owner['user_id']}/review",
        headers=admin_headers,
        json={"decision": "approve", "comment": "Verified"},
    ).status_code == 200
    service = client.post("/api/v1/business/services", headers=owner_headers, json={
        "title": "Consultation",
        "description": "One-hour consultation.",
        "duration_minutes": 60,
        "price_cents": 9500,
        "delivery_mode": "remote",
    })
    assert service.status_code == 201, service.text
    booking_day = (datetime.now(timezone.utc) + timedelta(days=3)).date()
    availability = client.put("/api/v1/business/availability", headers=owner_headers, json=[{
        "weekday": booking_day.weekday(),
        "start_time": "09:00",
        "end_time": "12:00",
        "is_active": True,
    }])
    assert availability.status_code == 200, availability.text

    public_profile = client.get(f"/api/v1/businesses/{owner['user_id']}")
    assert public_profile.status_code == 200
    assert public_profile.json()["services"][0]["title"] == "Consultation"
    slots = client.get(
        f"/api/v1/businesses/{owner['user_id']}/slots",
        params={"service_id": service.json()["id"], "date": booking_day.isoformat()},
    )
    assert slots.status_code == 200, slots.text
    assert len(slots.json()) == 3

    customer_headers = _headers(premium=False)
    booking = client.post(
        f"/api/v1/businesses/{owner['user_id']}/bookings",
        headers=customer_headers,
        json={
            "service_id": service.json()["id"],
            "starts_at": slots.json()[0]["starts_at"],
            "notes": "Please call through the app.",
        },
    )
    assert booking.status_code == 201, booking.text
    assert booking.json()["status"] == "requested"
    customer_bookings = client.get("/api/v1/businesses/me/bookings", headers=customer_headers)
    assert customer_bookings.status_code == 200
    assert customer_bookings.json()[0]["business_name"] == "Züri Clean"
    assert customer_bookings.json()[0]["service_title"] == "Consultation"
    cancelled = client.post(
        f"/api/v1/businesses/me/bookings/{booking.json()['id']}/cancel",
        headers=customer_headers,
    )
    assert cancelled.status_code == 200
    assert cancelled.json()["status"] == "cancelled"


def test_team_member_can_manage_workspace_without_own_plus() -> None:
    owner_headers = _headers()
    member_headers = _headers(premium=False)
    owner = _profile(owner_headers)
    member_id = _subject(member_headers)
    with SessionLocal() as db:
        member = db.get(User, member_id)
        member_email = member.email

    invited = client.post("/api/v1/business/team", headers=owner_headers, json={
        "email": member_email,
        "display_name": "Team Member",
        "role": "manager",
    })
    assert invited.status_code == 201, invited.text
    assert invited.json()["status"] == "active"

    workspaces = client.get("/api/v1/businesses/me/workspaces", headers=member_headers)
    assert workspaces.status_code == 200, workspaces.text
    assert workspaces.json()[0]["owner_user_id"] == owner["user_id"]
    dashboard = client.get(
        f"/api/v1/businesses/workspaces/{owner['user_id']}/dashboard",
        headers=member_headers,
    )
    assert dashboard.status_code == 200, dashboard.text
    assert dashboard.json()["profile"]["display_name"] == "Züri Clean"
