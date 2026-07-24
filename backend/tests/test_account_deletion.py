from __future__ import annotations

from datetime import datetime, timedelta, timezone
import json
import uuid

from backend.app.core.database import SessionLocal
from backend.app.models.analytics import PaywallEvent
from backend.app.models.auth_email_code import AuthEmailCode
from backend.app.models.chat import (
    ChatConversation,
    ChatMessage,
    ChatParticipant,
    NotificationOutbox,
    PushDevice,
)
from backend.app.models.event_listing import EventListing
from backend.app.models.marketplace import MarketplaceBlock, ServiceListing
from backend.app.models.user import User
from backend.app.services.auth_email_codes import AuthEmailCodeService
from backend.app.services.users import UserService


def test_delete_account_removes_personal_and_user_generated_data() -> None:
    target_email = f"delete_{uuid.uuid4().hex}@example.com"
    with SessionLocal() as db:
        target = UserService.create(db, email=target_email, password="StrongPass1!", email_verified=True)
        other = UserService.create(
            db,
            email=f"other_{uuid.uuid4().hex}@example.com",
            password="StrongPass1!",
            email_verified=True,
        )

        listing = ServiceListing(
            listing_type="service",
            title="Private listing",
            description="Contains user generated content",
            category="other",
            canton="ZH",
            contact_type="email",
            contact_value=target_email,
            author_id=target.id,
            author_name="Delete Me",
            image_urls=[],
        )
        event = EventListing(
            title="Private event",
            description="User event",
            category="community",
            canton="ZH",
            city="Zürich",
            starts_at=datetime.now(timezone.utc) + timedelta(days=1),
            is_free=True,
            contact_type="email",
            contact_value=target_email,
            organizer_name="Delete Me",
            author_id=target.id,
        )
        db.add_all([listing, event])
        db.flush()

        conversation = ChatConversation(
            listing_id=listing.id,
            buyer_id=other.id,
            seller_id=target.id,
            listing_type="service",
            listing_title=listing.title,
            seller_name="Delete Me",
        )
        db.add(conversation)
        db.flush()
        db.add_all(
            [
                ChatParticipant(conversation_id=conversation.id, user_id=target.id),
                ChatParticipant(conversation_id=conversation.id, user_id=other.id),
                ChatMessage(
                    conversation_id=conversation.id,
                    sender_id=target.id,
                    client_message_id=uuid.uuid4().hex,
                    body="Personal chat content",
                ),
                PushDevice(user_id=target.id, token=uuid.uuid4().hex, environment="sandbox"),
                NotificationOutbox(
                    event_key=f"delete-test:{uuid.uuid4().hex}",
                    recipient_id=target.id,
                    event_type="chat_message",
                    payload_json=json.dumps({"body": "private"}),
                ),
                MarketplaceBlock(user_id=target.id, blocked_author_id=other.id),
                PaywallEvent(user_id=target.id, event_type="view"),
            ]
        )
        db.commit()

        AuthEmailCodeService.issue_code(db, user=target, purpose=AuthEmailCodeService.VERIFY_EMAIL)
        UserService.delete_account(db, user=target)

        deleted_user = db.query(User).filter(User.id == target.id).one()
        assert deleted_user.is_active is False
        assert deleted_user.email.endswith("@example.invalid")
        assert deleted_user.apple_sub is None
        assert deleted_user.google_sub is None

        assert db.query(ServiceListing).filter(ServiceListing.author_id == target.id).count() == 0
        assert db.query(EventListing).filter(EventListing.author_id == target.id).count() == 0
        assert db.query(ChatConversation).filter(
            (ChatConversation.buyer_id == target.id) | (ChatConversation.seller_id == target.id)
        ).count() == 0
        assert db.query(ChatMessage).filter(ChatMessage.sender_id == target.id).count() == 0
        assert db.query(ChatParticipant).filter(ChatParticipant.user_id == target.id).count() == 0
        assert db.query(PushDevice).filter(PushDevice.user_id == target.id).count() == 0
        assert db.query(NotificationOutbox).filter(NotificationOutbox.recipient_id == target.id).count() == 0
        assert db.query(MarketplaceBlock).filter(MarketplaceBlock.user_id == target.id).count() == 0
        assert db.query(PaywallEvent).filter(PaywallEvent.user_id == target.id).count() == 0
        assert db.query(AuthEmailCode).filter(AuthEmailCode.user_id == target.id).count() == 0
