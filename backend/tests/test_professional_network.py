from __future__ import annotations

import uuid

from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.services.users import UserService


client = TestClient(app)


def _identity(*, verified: bool = True) -> tuple[dict[str, str], str]:
    with SessionLocal() as db:
        user = UserService.create(
            db,
            email=f"network_{uuid.uuid4().hex}@example.com",
            password="StrongPass1!",
            role="user",
            email_verified=verified,
        )
        token = create_access_token(subject=user.id, is_admin=False, role=user.role)
        return {"Authorization": f"Bearer {token}"}, user.id


def _profile(headers: dict[str, str], *, name: str, canton: str, role: str, goals: list[str]) -> dict:
    response = client.put(
        "/api/v1/network/profile/me",
        headers=headers,
        json={
            "display_name": name,
            "headline": f"{role.title()} building products in Switzerland",
            "company_name": "Alpine Labs",
            "role": role,
            "industry": "Technology",
            "canton": canton,
            "city": "Zürich" if canton == "ZH" else "Basel",
            "bio": "I build useful products and want to meet thoughtful professionals for long-term collaboration.",
            "skills": ["Product", "AI", "Strategy"],
            "languages": ["DE", "EN"],
            "goals": goals,
            "is_visible": True,
            "open_to_connections": True,
        },
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_network_profile_search_connection_acceptance_and_chat() -> None:
    founder, founder_id = _identity()
    specialist, specialist_id = _identity()
    _profile(founder, name="Founder One", canton="ZH", role="founder", goals=["partners", "investing"])
    _profile(specialist, name="Specialist Two", canton="BS", role="specialist", goals=["clients", "events"])

    catalog = client.get("/api/v1/network/profiles?canton=BS&goal=clients", headers=founder)
    assert catalog.status_code == 200, catalog.text
    assert catalog.json()["total"] == 1
    assert catalog.json()["items"][0]["user_id"] == specialist_id
    assert "email" not in catalog.json()["items"][0]

    request = client.post(
        f"/api/v1/network/profiles/{specialist_id}/connect",
        headers=founder,
        json={"message": "Would you like to discuss a product partnership?"},
    )
    assert request.status_code == 201, request.text
    connection_id = request.json()["id"]
    assert request.json()["direction"] == "outgoing"
    assert request.json()["status"] == "pending"

    duplicate = client.post(
        f"/api/v1/network/profiles/{specialist_id}/connect",
        headers=founder,
        json={"message": "duplicate"},
    )
    assert duplicate.status_code == 409

    reverse_duplicate = client.post(
        f"/api/v1/network/profiles/{founder_id}/connect",
        headers=specialist,
        json={"message": "crossed request"},
    )
    assert reverse_duplicate.status_code == 409

    incoming = client.get("/api/v1/network/connections?box=incoming", headers=specialist)
    assert incoming.status_code == 200
    assert incoming.json()[0]["other_profile"]["user_id"] == founder_id

    accepted = client.patch(
        f"/api/v1/network/connections/{connection_id}",
        headers=specialist,
        json={"status": "accepted"},
    )
    assert accepted.status_code == 200, accepted.text
    conversation_id = accepted.json()["conversation_id"]
    assert conversation_id

    conversation = client.get(f"/api/v1/chat/conversations/{conversation_id}", headers=founder)
    assert conversation.status_code == 200, conversation.text
    assert conversation.json()["listing_type"] == "network"
    assert conversation.json()["network_profile_id"] == founder_id
    assert conversation.json()["listing_status"] == "approved"

    message = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/messages",
        headers=founder,
        json={"client_message_id": uuid.uuid4().hex, "body": "Great to connect."},
    )
    assert message.status_code == 201, message.text


def test_network_requires_verified_email_and_supports_blocking() -> None:
    unverified, _ = _identity(verified=False)
    denied = client.put(
        "/api/v1/network/profile/me",
        headers=unverified,
        json={
            "display_name": "Hidden User",
            "headline": "Founder in Switzerland",
            "role": "founder",
            "industry": "Technology",
            "canton": "ZH",
            "city": "Zürich",
            "bio": "A sufficiently detailed professional biography for validation and publishing.",
            "skills": [],
            "languages": ["EN"],
            "goals": ["partners"],
        },
    )
    assert denied.status_code == 403

    first, _ = _identity()
    second, second_id = _identity()
    _profile(first, name="First Person", canton="ZH", role="mentor", goals=["mentoring"])
    _profile(second, name="Second Person", canton="ZH", role="freelancer", goals=["clients"])

    blocked = client.post(f"/api/v1/network/profiles/{second_id}/block", headers=first)
    assert blocked.status_code == 200
    catalog = client.get("/api/v1/network/profiles", headers=first)
    assert all(item["user_id"] != second_id for item in catalog.json()["items"])


def test_network_rejects_insecure_public_urls() -> None:
    headers, _ = _identity()
    response = client.put(
        "/api/v1/network/profile/me",
        headers=headers,
        json={
            "display_name": "Secure Founder",
            "headline": "Founder building trusted products",
            "role": "founder",
            "industry": "Technology",
            "canton": "ZH",
            "city": "Zürich",
            "bio": "I build secure products and collaborate with professionals across Switzerland.",
            "languages": ["EN"],
            "goals": ["partners"],
            "website_url": "http://example.com",
        },
    )
    assert response.status_code == 422
