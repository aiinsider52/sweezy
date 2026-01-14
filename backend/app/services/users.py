from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from ..core.security import get_password_hash, verify_password
from ..core.config import get_settings
from ..models.user import User


class UserService:
    @staticmethod
    def get_by_email(db: Session, email: str) -> User | None:
        return db.query(User).filter(User.email == email.lower()).one_or_none()

    @staticmethod
    def create(db: Session, *, email: str, password: str, is_superuser: bool = False, role: str = "viewer") -> User:
        user = User(
            email=email.lower(),
            hashed_password=get_password_hash(password),
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
        if not user or not verify_password(password, user.hashed_password):
            return None
        if not user.is_active:
            return None
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
        # Best-effort cleanup of related tables
        try:
            from ..models.analytics import PaywallEvent
            db.query(PaywallEvent).filter(PaywallEvent.user_id == user.id).delete(synchronize_session=False)
        except Exception:
            pass

        try:
            from ..models.subscription import Subscription, SubscriptionEvent
            db.query(Subscription).filter(Subscription.user_id == user.id).delete(synchronize_session=False)
            db.query(SubscriptionEvent).filter(SubscriptionEvent.user_id == user.id).delete(synchronize_session=False)
        except Exception:
            pass

        try:
            from ..models.job import JobFavorite
            # JobFavorite.user_id is UUID in DB, while User.id is stored as a UUID string.
            db.query(JobFavorite).filter(JobFavorite.user_id == uuid.UUID(user.id)).delete(synchronize_session=False)
        except Exception:
            pass

        # Anonymize + deactivate
        user.is_active = False
        user.subscription_status = "free"
        user.subscription_expire_at = None
        user.stripe_customer_id = None
        user.stripe_subscription_id = None

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
        UserService.create(db, email=admin_email, password=admin_password, is_superuser=True)
        return
    # Ensure superuser flag and sync password from env if it has changed
    updated = False
    if not user.is_superuser:
        user.is_superuser = True
        updated = True
    if not verify_password(admin_password, user.hashed_password):
        user.hashed_password = get_password_hash(admin_password)
        updated = True
    if updated:
        db.add(user)
        db.commit()


