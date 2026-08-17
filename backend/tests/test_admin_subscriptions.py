from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

from backend.app.core.database import SessionLocal
from backend.app.models.audit_log import AuditLog
from backend.app.models.subscription import Subscription, SubscriptionEvent
from backend.app.models.user import User
from backend.app.routers.admin import (
    AdminSubscriptionUpdate,
    list_subscriptions,
    set_user_subscription,
    subscriptions_analytics,
)
from backend.app.routers.subscriptions import entitlements


def _user(email: str, *, admin: bool = False) -> User:
    return User(
        email=email,
        hashed_password="test",
        role="admin" if admin else "viewer",
        is_superuser=admin,
        is_active=True,
        email_verified=True,
        subscription_status="free",
    )


def _cleanup(db, user_ids: list[str]) -> None:
    db.query(SubscriptionEvent).filter(SubscriptionEvent.user_id.in_(user_ids)).delete(synchronize_session=False)
    db.query(Subscription).filter(Subscription.user_id.in_(user_ids)).delete(synchronize_session=False)
    db.query(AuditLog).filter(AuditLog.entity == "subscriptions", AuditLog.entity_id.in_(user_ids)).delete(synchronize_session=False)
    db.query(User).filter(User.id.in_(user_ids)).delete(synchronize_session=False)
    db.commit()


def test_admin_can_grant_dated_plus_and_list_lifecycle() -> None:
    with SessionLocal() as db:
        admin = _user("subscription-admin@example.test", admin=True)
        customer = _user("subscription-customer@example.test")
        db.add_all([admin, customer])
        db.commit()
        purchased_at = datetime.now(timezone.utc)
        expire_at = purchased_at + timedelta(days=30)
        try:
            result = set_user_subscription(
                customer.id,
                AdminSubscriptionUpdate(
                    status="premium",
                    plan="monthly",
                    purchased_at=purchased_at,
                    expire_at=expire_at,
                    reason="Support grant for paid account correction",
                ),
                db,
                {"sub": admin.id},
            )
            assert result["status"] == "premium"

            manual = db.query(Subscription).filter_by(user_id=customer.id, provider="manual").one()
            assert manual.status == "active"
            assert manual.plan == "monthly"
            assert manual.purchased_at is not None
            assert manual.current_period_end is not None

            rows = list_subscriptions({"sub": admin.id}, db, limit=200)
            row = next(item for item in rows if item["subscription_id"] == manual.id)
            assert row["provider"] == "manual"
            assert row["purchased_at"] is not None
            assert row["current_period_end"] is not None
            assert row["editable"] is True

            db.refresh(customer)
            access = entitlements(db, customer)
            assert access.is_premium is True
            assert access.status == "premium"
            assert access.plan == "monthly"
            assert access.provider == "manual"

            analytics = subscriptions_analytics({"sub": admin.id}, db, months=6)
            assert analytics["totals"]["premium_users"] >= 1
            assert analytics["totals"]["monthly"] >= 1

            event = db.query(SubscriptionEvent).filter_by(user_id=customer.id).one()
            assert event.provider == "manual"
            assert json.loads(event.payload)["reason"] == "Support grant for paid account correction"
            assert db.query(AuditLog).filter_by(entity="subscriptions", entity_id=customer.id).count() == 1
        finally:
            _cleanup(db, [admin.id, customer.id])


def test_admin_free_override_never_revokes_verified_apple_access() -> None:
    with SessionLocal() as db:
        admin = _user("subscription-admin-apple@example.test", admin=True)
        customer = _user("subscription-apple@example.test")
        now = datetime.now(timezone.utc)
        apple = Subscription(
            user=customer,
            provider="apple",
            product_id="sweezy_plus_monthly",
            plan="monthly",
            status="active",
            purchased_at=now - timedelta(days=2),
            current_period_end=now + timedelta(days=28),
            original_transaction_id="admin-test-original-transaction",
            latest_transaction_id="admin-test-latest-transaction",
            auto_renew_enabled=True,
        )
        customer.subscription_status = "premium"
        customer.subscription_expire_at = apple.current_period_end
        db.add_all([admin, customer, apple])
        db.commit()
        apple_id = apple.id
        try:
            result = set_user_subscription(
                customer.id,
                AdminSubscriptionUpdate(status="free", reason="Remove temporary manual entitlement"),
                db,
                {"sub": admin.id},
            )
            db.refresh(customer)
            db.refresh(apple)
            assert result["status"] == "premium"
            assert customer.subscription_status == "premium"
            assert apple.id == apple_id
            assert apple.status == "active"
            assert apple.auto_renew_enabled is True
            manual = db.query(Subscription).filter_by(user_id=customer.id, provider="manual").one()
            assert manual.status == "canceled"
        finally:
            _cleanup(db, [admin.id, customer.id])
