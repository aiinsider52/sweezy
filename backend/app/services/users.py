from __future__ import annotations

from datetime import datetime, timezone
import uuid

from sqlalchemy import or_
from sqlalchemy.orm import Session

from ..core.security import get_password_hash, verify_password
from ..core.config import get_settings
from ..models.user import User


class UserService:
    @staticmethod
    def get_by_id(db: Session, user_id: str) -> User | None:
        return db.get(User, user_id)

    @staticmethod
    def get_by_email(db: Session, email: str) -> User | None:
        return db.query(User).filter(User.email == email.lower()).one_or_none()

    @staticmethod
    def get_by_apple_sub(db: Session, apple_sub: str) -> User | None:
        return db.query(User).filter(User.apple_sub == apple_sub).one_or_none()

    @staticmethod
    def get_by_google_sub(db: Session, google_sub: str) -> User | None:
        return db.query(User).filter(User.google_sub == google_sub).one_or_none()

    @staticmethod
    def get_by_provider(db: Session, provider: str, provider_sub: str) -> User | None:
        if provider == "apple":
            return UserService.get_by_apple_sub(db, provider_sub)
        if provider == "google":
            return UserService.get_by_google_sub(db, provider_sub)
        return None

    @staticmethod
    def create(
        db: Session,
        *,
        email: str,
        password: str,
        is_superuser: bool = False,
        role: str = "viewer",
        email_verified: bool = False,
    ) -> User:
        user = User(
            email=email.lower(),
            hashed_password=get_password_hash(password),
            password_login_enabled=True,
            email_verified=email_verified,
            email_verified_at=datetime.now(timezone.utc) if email_verified else None,
            is_superuser=is_superuser,
            role=role,
            subscription_status="free",
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def authenticate(db: Session, *, email: str, password: str) -> User | None:
        user = UserService.get_by_email(db, email)
        if not user or not user.password_login_enabled or not verify_password(password, user.hashed_password):
            return None
        if not user.is_active:
            return None
        return user

    @staticmethod
    def create_social(
        db: Session,
        *,
        email: str,
        provider: str,
        provider_sub: str,
        email_verified: bool = True,
    ) -> User:
        user = User(
            email=email.lower(),
            hashed_password=get_password_hash(uuid.uuid4().hex + "!social"),
            password_login_enabled=False,
            email_verified=email_verified,
            email_verified_at=datetime.now(timezone.utc) if email_verified else None,
            is_superuser=False,
            role="viewer",
            subscription_status="free",
            apple_sub=provider_sub if provider == "apple" else None,
            google_sub=provider_sub if provider == "google" else None,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def link_provider(db: Session, *, user: User, provider: str, provider_sub: str) -> User:
        existing_user = UserService.get_by_provider(db, provider, provider_sub)
        if existing_user and existing_user.id != user.id:
            raise ValueError("Provider already linked to another account")

        if provider == "apple":
            user.apple_sub = provider_sub
        elif provider == "google":
            user.google_sub = provider_sub
        else:
            raise ValueError("Unsupported provider")

        if not user.email_verified:
            user.email_verified = True
            user.email_verified_at = datetime.now(timezone.utc)

        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def delete_account(db: Session, *, user: User) -> None:
        """
        Delete (anonymize) a user account for App Store 'Account Deletion' compliance.

        We keep the row to avoid breaking foreign references, but:
        - mark the account inactive
        - remove subscription identifiers
        - remove related user data rows where we store user_id
        - anonymize email and password to revoke all existing tokens
        """
        from ..models.analytics import AnalyticsEvent, AnalyticsSession, PaywallEvent
        from ..models.auth_email_code import AuthEmailCode
        from ..models.business import (
            BusinessAvailabilityRule,
            BusinessBooking,
            BusinessClient,
            BusinessDocument,
            BusinessLead,
            BusinessProfile,
            BusinessQuickReply,
            BusinessService,
            BusinessTeamMember,
        )
        from ..models.chat import (
            ChatConversation,
            ChatMessage,
            ChatMessageReport,
            ChatParticipant,
            MarketplaceReview,
            NotificationOutbox,
            PushDevice,
        )
        from ..models.event_listing import EventListing, EventReport
        from ..models.job import JobFavorite
        from ..models.marketplace import MarketplaceBlock, MarketplaceReport, ServiceListing
        from ..models.network import ProfessionalConnection, ProfessionalProfile, ProfessionalProfileReport
        from ..models.social import EventAttendance, FriendConnection, SocialProfile, SocialProfileReport
        from ..models.subscription import PremiumUsage, Subscription, SubscriptionEvent

        user_id = user.id

        db.query(SocialProfileReport).filter(or_(SocialProfileReport.reporter_id == user_id, SocialProfileReport.profile_user_id == user_id)).delete(synchronize_session=False)
        db.query(FriendConnection).filter(or_(FriendConnection.requester_id == user_id, FriendConnection.target_id == user_id)).delete(synchronize_session=False)
        db.query(EventAttendance).filter(EventAttendance.user_id == user_id).delete(synchronize_session=False)
        db.query(SocialProfile).filter(SocialProfile.user_id == user_id).delete(synchronize_session=False)

        db.query(ProfessionalProfileReport).filter(
            or_(
                ProfessionalProfileReport.reporter_id == user_id,
                ProfessionalProfileReport.profile_user_id == user_id,
            )
        ).delete(synchronize_session=False)
        db.query(ProfessionalConnection).filter(
            or_(ProfessionalConnection.requester_id == user_id, ProfessionalConnection.target_id == user_id)
        ).delete(synchronize_session=False)
        db.query(ProfessionalProfile).filter(ProfessionalProfile.user_id == user_id).delete(synchronize_session=False)

        def delete_conversations(conversation_ids: list[str]) -> None:
            if not conversation_ids:
                return
            message_ids = [
                row[0]
                for row in db.query(ChatMessage.id)
                .filter(ChatMessage.conversation_id.in_(conversation_ids))
                .all()
            ]
            if message_ids:
                db.query(ChatMessageReport).filter(ChatMessageReport.message_id.in_(message_ids)).delete(
                    synchronize_session=False
                )
            db.query(MarketplaceReview).filter(MarketplaceReview.conversation_id.in_(conversation_ids)).delete(
                synchronize_session=False
            )
            db.query(ChatMessage).filter(ChatMessage.conversation_id.in_(conversation_ids)).delete(
                synchronize_session=False
            )
            db.query(ChatParticipant).filter(ChatParticipant.conversation_id.in_(conversation_ids)).delete(
                synchronize_session=False
            )
            db.query(ChatConversation).filter(ChatConversation.id.in_(conversation_ids)).delete(
                synchronize_session=False
            )

        authored_listing_ids = [
            row[0] for row in db.query(ServiceListing.id).filter(ServiceListing.author_id == user_id).all()
        ]
        conversation_query = db.query(ChatConversation.id).filter(
            or_(ChatConversation.buyer_id == user_id, ChatConversation.seller_id == user_id)
        )
        if authored_listing_ids:
            conversation_query = conversation_query.union(
                db.query(ChatConversation.id).filter(ChatConversation.listing_id.in_(authored_listing_ids))
            )
        delete_conversations(list(dict.fromkeys(row[0] for row in conversation_query.all())))

        db.query(ChatMessageReport).filter(ChatMessageReport.reporter_id == user_id).delete(synchronize_session=False)
        db.query(ChatMessageReport).filter(ChatMessageReport.resolved_by == user_id).update(
            {ChatMessageReport.resolved_by: None}, synchronize_session=False
        )
        db.query(MarketplaceReview).filter(
            or_(MarketplaceReview.reviewer_id == user_id, MarketplaceReview.reviewed_user_id == user_id)
        ).delete(synchronize_session=False)
        db.query(PushDevice).filter(PushDevice.user_id == user_id).delete(synchronize_session=False)
        db.query(NotificationOutbox).filter(NotificationOutbox.recipient_id == user_id).delete(synchronize_session=False)

        db.query(MarketplaceReport).filter(MarketplaceReport.reporter_id == user_id).delete(synchronize_session=False)
        db.query(MarketplaceBlock).filter(
            or_(MarketplaceBlock.user_id == user_id, MarketplaceBlock.blocked_author_id == user_id)
        ).delete(synchronize_session=False)
        if authored_listing_ids:
            db.query(MarketplaceReport).filter(MarketplaceReport.listing_id.in_(authored_listing_ids)).delete(
                synchronize_session=False
            )
            db.query(ServiceListing).filter(ServiceListing.id.in_(authored_listing_ids)).delete(
                synchronize_session=False
            )

        authored_event_ids = [
            row[0] for row in db.query(EventListing.id).filter(EventListing.author_id == user_id).all()
        ]
        db.query(EventReport).filter(EventReport.reporter_id == user_id).delete(synchronize_session=False)
        if authored_event_ids:
            db.query(EventReport).filter(EventReport.event_id.in_(authored_event_ids)).delete(synchronize_session=False)
            db.query(EventListing).filter(EventListing.id.in_(authored_event_ids)).delete(synchronize_session=False)

        db.query(AuthEmailCode).filter(
            or_(AuthEmailCode.user_id == user_id, AuthEmailCode.email == user.email.lower())
        ).delete(synchronize_session=False)
        db.query(PaywallEvent).filter(PaywallEvent.user_id == user_id).delete(synchronize_session=False)
        # Analytics properties and diagnostic messages can still be user-related;
        # erase authenticated analytics instead of merely unlinking the account.
        analytics_session_ids = [
            row[0]
            for row in db.query(AnalyticsSession.id).filter(AnalyticsSession.user_id == user_id).all()
        ]
        db.query(AnalyticsEvent).filter(AnalyticsEvent.user_id == user_id).delete(synchronize_session="fetch")
        if analytics_session_ids:
            db.query(AnalyticsEvent).filter(AnalyticsEvent.session_id.in_(analytics_session_ids)).delete(
                synchronize_session="fetch"
            )
            db.query(AnalyticsSession).filter(AnalyticsSession.id.in_(analytics_session_ids)).delete(
                synchronize_session="fetch"
            )
        db.query(Subscription).filter(Subscription.user_id == user_id).delete(synchronize_session=False)
        db.query(SubscriptionEvent).filter(SubscriptionEvent.user_id == user_id).delete(synchronize_session=False)
        db.query(PremiumUsage).filter(PremiumUsage.user_id == user_id).delete(synchronize_session=False)
        db.query(JobFavorite).filter(JobFavorite.user_id == uuid.UUID(user_id)).delete(synchronize_session=False)

        # Erase Sweezy Pro workspace and remove access to workspaces owned by others.
        db.query(BusinessDocument).filter(BusinessDocument.business_user_id == user_id).delete(synchronize_session=False)
        db.query(BusinessBooking).filter(BusinessBooking.business_user_id == user_id).delete(synchronize_session=False)
        db.query(BusinessLead).filter(BusinessLead.business_user_id == user_id).delete(synchronize_session=False)
        db.query(BusinessClient).filter(BusinessClient.business_user_id == user_id).delete(synchronize_session=False)
        db.query(BusinessAvailabilityRule).filter(BusinessAvailabilityRule.business_user_id == user_id).delete(synchronize_session=False)
        db.query(BusinessQuickReply).filter(BusinessQuickReply.business_user_id == user_id).delete(synchronize_session=False)
        db.query(BusinessTeamMember).filter(
            or_(BusinessTeamMember.business_user_id == user_id, BusinessTeamMember.member_user_id == user_id)
        ).delete(synchronize_session=False)
        db.query(BusinessService).filter(BusinessService.business_user_id == user_id).delete(synchronize_session=False)
        db.query(BusinessProfile).filter(BusinessProfile.user_id == user_id).delete(synchronize_session=False)

        # Anonymize + deactivate
        user.is_active = False
        user.email_verified = False
        user.email_verified_at = None
        user.subscription_status = "free"
        user.subscription_expire_at = None
        user.stripe_customer_id = None
        user.stripe_subscription_id = None
        user.apple_sub = None
        user.google_sub = None
        user.password_login_enabled = False

        # Change email to a unique, non-personal placeholder (revokes tokens that use email as subject)
        user.email = f"deleted+{uuid.uuid4().hex}@example.invalid"
        user.hashed_password = get_password_hash(uuid.uuid4().hex + "!")

        db.add(user)
        db.commit()


def seed_admin_user(db: Session) -> None:
    settings = get_settings()
    admin_email = settings.ADMIN_EMAIL
    admin_password = settings.ADMIN_PASSWORD
    if not admin_email or not admin_password:
        return
    user = UserService.get_by_email(db, admin_email)
    if user is None:
        UserService.create(db, email=admin_email, password=admin_password, is_superuser=True, email_verified=True)
        return
    # Ensure superuser flag and sync password from env if it has changed
    updated = False
    if not user.is_superuser:
        user.is_superuser = True
        updated = True
    if not getattr(user, "password_login_enabled", True):
        user.password_login_enabled = True
        updated = True
    if not user.email_verified:
        user.email_verified = True
        user.email_verified_at = datetime.now(timezone.utc)
        updated = True
    if not verify_password(admin_password, user.hashed_password):
        user.hashed_password = get_password_hash(admin_password)
        updated = True
    if updated:
        db.add(user)
        db.commit()


def seed_demo_user(db: Session) -> None:
    """
    Ensure a stable demo account exists (for App Store review / QA).

    Controlled by env:
    - DEMO_USER_ENABLED=true
    - DEMO_USER_EMAIL=...
    - DEMO_USER_PASSWORD=...
    """
    settings = get_settings()
    if not getattr(settings, "DEMO_USER_ENABLED", False):
        return
    demo_email = getattr(settings, "DEMO_USER_EMAIL", None)
    demo_password = getattr(settings, "DEMO_USER_PASSWORD", None)
    if not demo_email or not demo_password:
        return

    user = UserService.get_by_email(db, demo_email)
    if user is None:
        UserService.create(db, email=demo_email, password=demo_password, is_superuser=False, role="viewer", email_verified=True)
        return

    updated = False
    if not user.is_active:
        user.is_active = True
        updated = True
    if not getattr(user, "password_login_enabled", True):
        user.password_login_enabled = True
        updated = True
    if not user.email_verified:
        user.email_verified = True
        user.email_verified_at = datetime.now(timezone.utc)
        updated = True
    if not verify_password(demo_password, user.hashed_password):
        user.hashed_password = get_password_hash(demo_password)
        updated = True
    if updated:
        db.add(user)
        db.commit()
