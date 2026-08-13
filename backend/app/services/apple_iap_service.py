from __future__ import annotations

import base64
import json
import uuid
from datetime import datetime, timezone
from functools import lru_cache
from typing import Any

from sqlalchemy.orm import Session

from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.models.OfferDiscountType import OfferDiscountType
from appstoreserverlibrary.models.Status import Status
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier, VerificationException

from ..core.config import get_settings
from ..models.subscription import Subscription, SubscriptionEvent
from ..models.user import User


class AppleIAPError(RuntimeError):
    pass


class AppleIAPNotConfigured(AppleIAPError):
    pass


class AppleIAPConflict(AppleIAPError):
    pass


def _utc_from_milliseconds(value: int | None) -> datetime | None:
    if value is None:
        return None
    return datetime.fromtimestamp(value / 1000, tz=timezone.utc)


def _as_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _normalized_uuid(value: str | None) -> str | None:
    if not value:
        return None
    try:
        return str(uuid.UUID(value))
    except (TypeError, ValueError) as exc:
        raise AppleIAPError("Apple appAccountToken is not a valid UUID") from exc


def _decode_unverified_payload(signed_payload: str) -> dict[str, Any]:
    """Decode only to select verifier environment. Trust nothing until JWS verification passes."""
    try:
        parts = signed_payload.split(".")
        if len(parts) != 3:
            raise ValueError("invalid JWS segments")
        raw = parts[1] + "=" * (-len(parts[1]) % 4)
        payload = json.loads(base64.urlsafe_b64decode(raw.encode("ascii")))
        if not isinstance(payload, dict):
            raise ValueError("invalid JWS payload")
        return payload
    except Exception as exc:
        raise AppleIAPError("Malformed Apple signed payload") from exc


def _payload_environment(signed_payload: str) -> Environment:
    payload = _decode_unverified_payload(signed_payload)
    raw = payload.get("environment")
    if raw is None and isinstance(payload.get("data"), dict):
        raw = payload["data"].get("environment")
    if raw == Environment.PRODUCTION.value:
        return Environment.PRODUCTION
    if raw == Environment.SANDBOX.value:
        return Environment.SANDBOX
    raise AppleIAPError("Unsupported Apple transaction environment")


def _root_certificates() -> list[bytes]:
    settings = get_settings()
    raw = (settings.APPLE_IAP_ROOT_CERTIFICATES_BASE64 or "").strip()
    if not raw:
        raise AppleIAPNotConfigured("Apple root certificates are not configured")
    try:
        values = json.loads(raw) if raw.startswith("[") else [item.strip() for item in raw.split(",")]
        certificates = [base64.b64decode(item, validate=True) for item in values if item]
    except Exception as exc:
        raise AppleIAPNotConfigured("Apple root certificates configuration is invalid") from exc
    if not certificates:
        raise AppleIAPNotConfigured("Apple root certificates are not configured")
    return certificates


@lru_cache(maxsize=2)
def _verifier(environment: Environment) -> SignedDataVerifier:
    settings = get_settings()
    if not settings.APPLE_IAP_ENABLED:
        raise AppleIAPNotConfigured("Apple subscriptions are not enabled")
    if environment == Environment.SANDBOX and not settings.APPLE_IAP_ALLOW_SANDBOX:
        raise AppleIAPError("Sandbox transactions are disabled")
    app_apple_id = settings.APPLE_IAP_APP_APPLE_ID if environment == Environment.PRODUCTION else None
    if environment == Environment.PRODUCTION and not app_apple_id:
        raise AppleIAPNotConfigured("Apple app ID is not configured")
    return SignedDataVerifier(
        _root_certificates(),
        settings.APPLE_IAP_ENABLE_ONLINE_CHECKS,
        environment,
        settings.APPLE_IAP_BUNDLE_ID,
        app_apple_id,
    )


def verify_signed_transaction(signed_transaction: str):
    try:
        return _verifier(_payload_environment(signed_transaction)).verify_and_decode_signed_transaction(
            signed_transaction
        )
    except VerificationException as exc:
        raise AppleIAPError("Apple transaction verification failed") from exc


def verify_notification(signed_payload: str):
    try:
        environment = _payload_environment(signed_payload)
        return _verifier(environment).verify_and_decode_notification(signed_payload), environment
    except VerificationException as exc:
        raise AppleIAPError("Apple notification verification failed") from exc


def _validate_transaction(decoded: Any) -> None:
    settings = get_settings()
    if decoded.bundleId != settings.APPLE_IAP_BUNDLE_ID:
        raise AppleIAPError("Apple transaction bundle does not match")
    if decoded.productId not in set(settings.parsed_apple_iap_product_ids()):
        raise AppleIAPError("Unknown Apple subscription product")
    if not decoded.originalTransactionId or not decoded.transactionId:
        raise AppleIAPError("Apple transaction identifiers are missing")


def _resolve_notification_user(db: Session, decoded: Any) -> User | None:
    original_id = decoded.originalTransactionId
    if original_id:
        existing = (
            db.query(Subscription)
            .filter(Subscription.provider == "apple", Subscription.original_transaction_id == original_id)
            .one_or_none()
        )
        if existing:
            return db.query(User).filter(User.id == existing.user_id).one_or_none()
    token = _normalized_uuid(decoded.appAccountToken)
    if token:
        return db.query(User).filter(User.id == token, User.is_active.is_(True)).one_or_none()
    return None


def _recompute_user_entitlement(db: Session, user: User) -> None:
    now = datetime.now(timezone.utc)
    rows = db.query(Subscription).filter(Subscription.user_id == user.id).all()
    active_rows = [
        row
        for row in rows
        if row.status in {"active", "trial"}
        and row.revocation_date is None
        and (_as_utc(row.current_period_end) is None or _as_utc(row.current_period_end) > now)
    ]
    if not active_rows:
        user.subscription_status = "free"
        user.subscription_expire_at = None
    else:
        user.subscription_status = "premium" if any(row.status == "active" for row in active_rows) else "trial"
        expirations = [_as_utc(row.current_period_end) for row in active_rows if row.current_period_end]
        user.subscription_expire_at = max(expirations) if expirations else None
    db.add(user)


def apply_verified_transaction(
    db: Session,
    user: User,
    decoded: Any,
    *,
    renewal: Any | None = None,
    notification_status: Status | None = None,
) -> Subscription:
    _validate_transaction(decoded)
    account_token = _normalized_uuid(decoded.appAccountToken)
    if account_token and account_token != str(uuid.UUID(user.id)):
        raise AppleIAPConflict("Apple purchase belongs to another Sweezy account")

    existing = (
        db.query(Subscription)
        .filter(
            Subscription.provider == "apple",
            Subscription.original_transaction_id == decoded.originalTransactionId,
        )
        .one_or_none()
    )
    if existing and existing.user_id != user.id:
        raise AppleIAPConflict("Apple purchase is already linked to another Sweezy account")

    row = existing or Subscription(
        user_id=user.id,
        provider="apple",
        original_transaction_id=decoded.originalTransactionId,
    )
    expires_at = _utc_from_milliseconds(decoded.expiresDate)
    grace_expires_at = _utc_from_milliseconds(getattr(renewal, "gracePeriodExpiresDate", None))
    effective_expiry = max(filter(None, (expires_at, grace_expires_at)), default=None)
    revoked_at = _utc_from_milliseconds(decoded.revocationDate)
    now = datetime.now(timezone.utc)
    active_by_date = effective_expiry is None or effective_expiry > now
    active_by_server_status = notification_status in {None, Status.ACTIVE, Status.BILLING_GRACE_PERIOD}
    active = active_by_date and active_by_server_status and revoked_at is None and not bool(decoded.isUpgraded)
    is_trial = decoded.offerDiscountType == OfferDiscountType.FREE_TRIAL

    row.product_id = decoded.productId
    row.latest_transaction_id = decoded.transactionId
    row.app_account_token = account_token or row.app_account_token
    row.environment = decoded.environment.value if decoded.environment else decoded.rawEnvironment
    row.plan = "monthly" if decoded.productId.endswith("monthly") else "yearly"
    row.status = "trial" if active and is_trial else "active" if active else "revoked" if revoked_at else "expired"
    original_purchase_at = _utc_from_milliseconds(getattr(decoded, "originalPurchaseDate", None))
    purchase_at = _utc_from_milliseconds(getattr(decoded, "purchaseDate", None))
    row.purchased_at = original_purchase_at or row.purchased_at or purchase_at
    row.current_period_end = effective_expiry
    row.revocation_date = revoked_at
    row.last_verified_at = now
    if renewal is not None and renewal.autoRenewStatus is not None:
        row.auto_renew_enabled = bool(renewal.autoRenewStatus.value)
    db.add(row)
    db.flush()
    _recompute_user_entitlement(db, user)
    db.commit()
    db.refresh(row)
    db.refresh(user)
    return row


def sync_signed_transaction(db: Session, user: User, signed_transaction: str) -> Subscription:
    return apply_verified_transaction(db, user, verify_signed_transaction(signed_transaction))


def process_notification(db: Session, signed_payload: str) -> tuple[str, str | None]:
    notification, environment = verify_notification(signed_payload)
    event_id = notification.notificationUUID
    event_type = notification.rawNotificationType or (
        notification.notificationType.value if notification.notificationType else "UNKNOWN"
    )
    if event_id and db.query(SubscriptionEvent.id).filter(SubscriptionEvent.external_event_id == event_id).first():
        return "duplicate", None

    data = notification.data
    user: User | None = None
    decoded = None
    renewal = None
    try:
        if data and data.signedTransactionInfo:
            decoded = _verifier(environment).verify_and_decode_signed_transaction(data.signedTransactionInfo)
            _validate_transaction(decoded)
            user = _resolve_notification_user(db, decoded)
        if data and data.signedRenewalInfo:
            renewal = _verifier(environment).verify_and_decode_renewal_info(data.signedRenewalInfo)
    except VerificationException as exc:
        raise AppleIAPError("Apple notification transaction verification failed") from exc

    if user and decoded:
        apply_verified_transaction(db, user, decoded, renewal=renewal, notification_status=data.status if data else None)

    event = SubscriptionEvent(
        user_id=user.id if user else None,
        provider="apple",
        external_event_id=event_id,
        type=event_type,
        payload=json.dumps(
            {
                "environment": environment.value,
                "subtype": notification.rawSubtype,
                "original_transaction_id": getattr(decoded, "originalTransactionId", None),
                "transaction_id": getattr(decoded, "transactionId", None),
                "product_id": getattr(decoded, "productId", None),
            }
        ),
    )
    db.add(event)
    db.commit()
    return "processed", user.id if user else None
