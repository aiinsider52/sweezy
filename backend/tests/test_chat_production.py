from __future__ import annotations

import json
import uuid

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from backend.app.core.database import SessionLocal
from backend.app.core.config import get_settings
from backend.app.core.security import create_access_token, create_refresh_token
from backend.app.main import app
from backend.app.models.chat import NotificationOutbox
from backend.app.services.users import UserService


client = TestClient(app)


@pytest.fixture(autouse=True)
def enable_push_outbox_for_chat_tests():
    settings = get_settings()
    previous = settings.PUSH_NOTIFICATIONS_ENABLED
    settings.PUSH_NOTIFICATIONS_ENABLED = True
    try:
        yield
    finally:
        settings.PUSH_NOTIFICATIONS_ENABLED = previous


def _identity(*, admin: bool = False) -> tuple[dict[str, str], str]:
    with SessionLocal() as db:
        user = UserService.create(
            db,
            email=f"chat_{uuid.uuid4().hex}@example.com",
            password="StrongPass1!",
            is_superuser=admin,
            role="admin" if admin else "user",
            email_verified=True,
        )
        token = create_access_token(subject=user.id, is_admin=admin, role=user.role)
        return {"Authorization": f"Bearer {token}"}, user.id


def _approved_listing(owner: dict[str, str], admin: dict[str, str], *, listing_type: str = "service") -> str:
    created = client.post(
        "/api/v1/marketplace/",
        headers=owner,
        json={
            "listing_type": listing_type,
            "title": "Safe marketplace listing",
            "description": "A clear listing used to test protected in-app conversations.",
            "category": "moving" if listing_type == "service" else "furniture",
            "canton": "ZH",
            "price_info": "CHF 50/hour" if listing_type == "service" else None,
            "price_chf": 50 if listing_type == "item" else None,
            "contact_type": "email",
            "contact_value": "owner@example.com",
            "author_name": "Owner",
            "image_urls": [],
        },
    )
    assert created.status_code == 201, created.text
    listing_id = created.json()["id"]
    approved = client.patch(f"/api/v1/admin/marketplace/{listing_id}/approve", headers=admin, json={})
    assert approved.status_code == 200, approved.text
    return listing_id


def test_chat_end_to_end_idempotency_read_close_review_and_report() -> None:
    owner, owner_id = _identity()
    buyer, buyer_id = _identity()
    admin, _ = _identity(admin=True)
    listing_id = _approved_listing(owner, admin)

    created = client.post("/api/v1/chat/conversations", headers=buyer, json={"listing_id": listing_id})
    assert created.status_code == 201, created.text
    conversation = created.json()
    conversation_id = conversation["id"]
    assert conversation["other_user_id"] == owner_id
    assert conversation["is_seller"] is False

    public_listing = client.get(f"/api/v1/marketplace/{listing_id}")
    assert public_listing.status_code == 200
    assert "contact_value" not in public_listing.json()

    duplicate = client.post("/api/v1/chat/conversations", headers=buyer, json={"listing_id": listing_id})
    assert duplicate.status_code == 201
    assert duplicate.json()["id"] == conversation_id

    own_conversation = client.post("/api/v1/chat/conversations", headers=owner, json={"listing_id": listing_id})
    assert own_conversation.status_code == 400

    client_message_id = str(uuid.uuid4())
    sent = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/messages",
        headers=buyer,
        json={"client_message_id": client_message_id, "body": "Чи актуально?"},
    )
    assert sent.status_code == 201, sent.text
    with SessionLocal() as db:
        outbox = db.query(NotificationOutbox).filter_by(event_key=f"chat:{sent.json()['id']}").one()
        assert json.loads(outbox.payload_json)["aps"]["badge"] == 1
    duplicate_send = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/messages",
        headers=buyer,
        json={"client_message_id": client_message_id, "body": "Чи актуально?"},
    )
    assert duplicate_send.status_code == 201
    assert duplicate_send.json()["id"] == sent.json()["id"]

    unread = client.get("/api/v1/chat/conversations/unread-count", headers=owner)
    assert unread.status_code == 200
    assert unread.json()["count"] == 1

    messages = client.get(f"/api/v1/chat/conversations/{conversation_id}/messages", headers=owner)
    assert messages.status_code == 200
    assert [item["body"] for item in messages.json()["items"]] == ["Чи актуально?"]
    read = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/read",
        headers=owner,
        json={"message_id": sent.json()["id"]},
    )
    assert read.status_code == 200
    assert client.get("/api/v1/chat/conversations/unread-count", headers=owner).json()["count"] == 0

    reply = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/messages",
        headers=owner,
        json={"client_message_id": str(uuid.uuid4()), "body": "Так, актуально."},
    )
    assert reply.status_code == 201, reply.text

    report = client.post(
        f"/api/v1/chat/messages/{reply.json()['id']}/report",
        headers=buyer,
        json={"reason": "spam"},
    )
    assert report.status_code == 200
    admin_reports = client.get("/api/v1/admin/chat/reports", headers=admin)
    assert admin_reports.status_code == 200
    assert any(item["message"]["id"] == reply.json()["id"] for item in admin_reports.json())

    closed = client.post(f"/api/v1/chat/conversations/{conversation_id}/close", headers=owner)
    assert closed.status_code == 200, closed.text
    assert closed.json()["status"] == "closed"
    listing = client.get(f"/api/v1/marketplace/{listing_id}")
    assert listing.status_code == 404

    review = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/review",
        headers=buyer,
        json={"rating": 5, "comment": "Все добре"},
    )
    assert review.status_code == 201, review.text
    duplicate_review = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/review",
        headers=buyer,
        json={"rating": 5},
    )
    assert duplicate_review.status_code == 409


def test_block_is_bidirectional_and_push_device_lifecycle() -> None:
    owner, _ = _identity()
    buyer, _ = _identity()
    admin, _ = _identity(admin=True)
    listing_id = _approved_listing(owner, admin, listing_type="item")
    conversation = client.post("/api/v1/chat/conversations", headers=buyer, json={"listing_id": listing_id}).json()

    registered = client.post(
        "/api/v1/devices/push",
        headers=buyer,
        json={"token": "ab" * 32, "environment": "sandbox"},
    )
    assert registered.status_code == 200, registered.text

    blocked = client.post(f"/api/v1/chat/conversations/{conversation['id']}/block", headers=buyer)
    assert blocked.status_code == 200
    denied = client.post(
        f"/api/v1/chat/conversations/{conversation['id']}/messages",
        headers=owner,
        json={"client_message_id": str(uuid.uuid4()), "body": "Message after block"},
    )
    assert denied.status_code == 403

    removed = client.delete("/api/v1/devices/push/" + "ab" * 32, headers=buyer)
    assert removed.status_code == 204


def test_websocket_rejects_missing_token() -> None:
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect("/api/v1/chat/ws") as socket:
            socket.receive_json()


def test_websocket_rejects_refresh_token() -> None:
    _, user_id = _identity()
    refresh_token = create_refresh_token(subject=user_id)
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect(
            "/api/v1/chat/ws",
            headers={"Authorization": f"Bearer {refresh_token}"},
        ) as socket:
            socket.receive_json()


def test_chat_feature_kill_switch_returns_service_unavailable() -> None:
    settings = get_settings()
    previous = settings.CHAT_ENABLED
    settings.CHAT_ENABLED = False
    try:
        response = client.get("/api/v1/chat/conversations")
        assert response.status_code == 503
    finally:
        settings.CHAT_ENABLED = previous
