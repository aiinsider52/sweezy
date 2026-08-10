from __future__ import annotations

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.models.OfferDiscountType import OfferDiscountType
from appstoreserverlibrary.models.Status import Status
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.core.security import create_access_token
from app.dependencies import require_premium_or_free_uses
from app.models.subscription import PremiumUsage, Subscription, SubscriptionEvent
from app.models.user import User
from app.services import apple_iap_service
from app.services.apple_iap_service import AppleIAPConflict, AppleIAPError, apply_verified_transaction


def _user(db, prefix: str = "apple") -> User:
    user = User(email=f"{prefix}-{uuid4().hex}@example.com", hashed_password="x")
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _transaction(user: User, *, original_id: str, expires_at: datetime, transaction_id: str | None = None):
    return SimpleNamespace(
        bundleId="com.sweezy.mobile",
        productId="sweezy_plus_monthly",
        originalTransactionId=original_id,
        transactionId=transaction_id or f"tx-{uuid4().hex}",
        appAccountToken=user.id,
        expiresDate=int(expires_at.timestamp() * 1000),
        revocationDate=None,
        isUpgraded=False,
        offerDiscountType=OfferDiscountType.FREE_TRIAL,
        environment=Environment.SANDBOX,
        rawEnvironment=Environment.SANDBOX.value,
    )


def test_verified_apple_transaction_links_account_and_trial():
    with SessionLocal() as db:
        user = _user(db, "apple-active")
        decoded = _transaction(
            user,
            original_id=f"orig-{uuid4().hex}",
            expires_at=datetime.now(timezone.utc) + timedelta(days=30),
        )
        row = apply_verified_transaction(db, user, decoded)

        assert row.provider == "apple"
        assert row.status == "trial"
        assert row.app_account_token == user.id
        assert user.subscription_status == "trial"
        assert user.subscription_expire_at is not None


def test_apple_original_transaction_cannot_move_between_accounts():
    with SessionLocal() as db:
        owner = _user(db, "apple-owner")
        attacker = _user(db, "apple-other")
        original_id = f"orig-{uuid4().hex}"
        decoded = _transaction(
            owner,
            original_id=original_id,
            expires_at=datetime.now(timezone.utc) + timedelta(days=30),
        )
        apply_verified_transaction(db, owner, decoded)
        decoded.appAccountToken = attacker.id
        decoded.transactionId = f"tx-{uuid4().hex}"

        with pytest.raises(AppleIAPConflict):
            apply_verified_transaction(db, attacker, decoded)


def test_expired_apple_transaction_downgrades_user():
    with SessionLocal() as db:
        user = _user(db, "apple-expired")
        user.subscription_status = "premium"
        db.commit()
        decoded = _transaction(
            user,
            original_id=f"orig-{uuid4().hex}",
            expires_at=datetime.now(timezone.utc) - timedelta(minutes=1),
        )

        row = apply_verified_transaction(db, user, decoded)

        assert row.status == "expired"
        assert user.subscription_status == "free"
        assert user.subscription_expire_at is None


def test_notification_v2_updates_entitlement_once(monkeypatch):
    with SessionLocal() as db:
        user = _user(db, "apple-notification")
        decoded = _transaction(
            user,
            original_id=f"orig-{uuid4().hex}",
            expires_at=datetime.now(timezone.utc) + timedelta(days=30),
        )
        decoded.offerDiscountType = None
        renewal = SimpleNamespace(gracePeriodExpiresDate=None, autoRenewStatus=SimpleNamespace(value=1))
        data = SimpleNamespace(
            signedTransactionInfo="signed-transaction",
            signedRenewalInfo="signed-renewal",
            status=Status.ACTIVE,
        )
        notification = SimpleNamespace(
            notificationUUID=f"event-{uuid4().hex}",
            rawNotificationType="DID_RENEW",
            notificationType=None,
            rawSubtype=None,
            data=data,
        )
        verifier = SimpleNamespace(
            verify_and_decode_signed_transaction=lambda _value: decoded,
            verify_and_decode_renewal_info=lambda _value: renewal,
        )
        monkeypatch.setattr(
            apple_iap_service,
            "verify_notification",
            lambda _payload: (notification, Environment.SANDBOX),
        )
        monkeypatch.setattr(apple_iap_service, "_verifier", lambda _environment: verifier)

        assert apple_iap_service.process_notification(db, "signed-notification")[0] == "processed"
        assert apple_iap_service.process_notification(db, "signed-notification")[0] == "duplicate"
        assert db.query(SubscriptionEvent).filter(SubscriptionEvent.external_event_id == notification.notificationUUID).count() == 1
        db.refresh(user)
        assert user.subscription_status == "premium"


def test_malformed_apple_jws_is_rejected_before_parsing():
    with pytest.raises(AppleIAPError):
        apple_iap_service.verify_signed_transaction("not-a-jws")


quota_app = FastAPI()


@quota_app.post("/cv")
def use_cv(_user= require_premium_or_free_uses("cv_tools", 3)):
    return {"ok": True}


def test_cv_quota_is_server_authoritative():
    with SessionLocal() as db:
        user = _user(db, "cv-quota")
        token = create_access_token(subject=user.id, role=user.role)
        headers = {"Authorization": f"Bearer {token}"}

    client = TestClient(quota_app)
    assert [client.post("/cv", headers=headers).status_code for _ in range(3)] == [200, 200, 200]
    blocked = client.post("/cv", headers=headers)
    assert blocked.status_code == 402

    with SessionLocal() as db:
        usage = db.query(PremiumUsage).filter(PremiumUsage.user_id == user.id).one()
        assert usage.free_uses == 3
        stored_user = db.query(User).filter(User.id == user.id).one()
        stored_user.subscription_status = "premium"
        stored_user.subscription_expire_at = datetime.now(timezone.utc) + timedelta(days=30)
        db.commit()

    assert client.post("/cv", headers=headers).status_code == 200
    with SessionLocal() as db:
        assert db.query(Subscription).filter(Subscription.user_id == user.id).count() == 0
        usage = db.query(PremiumUsage).filter(PremiumUsage.user_id == user.id).one()
        assert usage.free_uses == 3
