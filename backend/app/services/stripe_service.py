from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from typing import Optional

import stripe  # type: ignore
from sqlalchemy.orm import Session

from ..models.user import User
from ..models.subscription import Subscription, SubscriptionEvent


def _init():
    api_key = os.getenv("STRIPE_SECRET_KEY")
    if not api_key:
        raise RuntimeError("STRIPE_SECRET_KEY not configured")
    stripe.api_key = api_key


def create_checkout_session(
    db: Session,
    user: User,
    plan: str,
    success_url: str,
    cancel_url: str,
    promotion_code: Optional[str] = None,
) -> str:
    """
    plan: 'monthly' or 'yearly'
    Returns URL to redirect user to Stripe Checkout.
    """
    _init()
    price_id = os.getenv("STRIPE_PRICE_MONTHLY") if plan == "monthly" else os.getenv("STRIPE_PRICE_YEARLY")
    if not price_id:
        raise RuntimeError("Stripe price IDs are not configured")

    customer_id = user.stripe_customer_id
    if not customer_id:
        # Create customer lazily
        customer = stripe.Customer.create(email=user.email)
        customer_id = customer["id"]
        user.stripe_customer_id = customer_id
        db.add(user)
        db.commit()

    discounts = None
    if promotion_code:
        try:
            pcs = stripe.PromotionCode.list(code=promotion_code, active=True, limit=1)
            if pcs["data"]:
                discounts = [{"promotion_code": pcs["data"][0]["id"]}]
        except Exception:
            discounts = None

    session = stripe.checkout.Session.create(
        mode="subscription",
        success_url=success_url,
        cancel_url=cancel_url,
        customer=customer_id,
        line_items=[{"price": price_id, "quantity": 1}],
        allow_promotion_codes=True,
        discounts=discounts,
        client_reference_id=user.id,
    )
    return session["url"]


def log_event(db: Session, user_id: Optional[str], event_type: str, payload: dict) -> None:
    try:
        ev = SubscriptionEvent(user_id=user_id, type=event_type, payload=json.dumps(payload)[:8000])
        db.add(ev)
        db.commit()
    except Exception:
        db.rollback()


def apply_trial(db: Session, user: User, days: int = 7) -> User:
    user.subscription_status = "trial"
    user.subscription_expire_at = datetime.now(timezone.utc) + timedelta(days=days)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def apply_premium(db: Session, user: User, subscription_id: str, current_period_end: Optional[datetime]) -> None:
    user.subscription_status = "premium"
    user.subscription_expire_at = current_period_end
    user.stripe_subscription_id = subscription_id
    # Upsert subscriptions table
    sub = db.query(Subscription).filter(Subscription.user_id == user.id).one_or_none()
    if sub is None:
        sub = Subscription(
            user_id=user.id,
            stripe_customer_id=user.stripe_customer_id,
            stripe_subscription_id=subscription_id,
            plan=None,
            status="active",
            current_period_end=current_period_end,
        )
    else:
        sub.stripe_subscription_id = subscription_id
        sub.status = "active"
        sub.current_period_end = current_period_end
    db.add(sub)
    db.add(user)
    db.commit()


def apply_free(db: Session, user: User) -> None:
    user.subscription_status = "free"
    user.subscription_expire_at = None
    db.add(user)
    db.commit()


def create_referral_promotion_code(user: User, prefix: Optional[str] = None) -> str:
    """
    Creates a one-time promotion code from a preconfigured Stripe coupon for referrals.
    Requires STRIPE_REFERRAL_COUPON_ID in env.
    """
    _init()
    coupon_id = os.getenv("STRIPE_REFERRAL_COUPON_ID")
    if not coupon_id:
        raise RuntimeError("STRIPE_REFERRAL_COUPON_ID not configured")
    code = None
    try:
        kwargs = {
            "coupon": coupon_id,
            "max_redemptions": 1,
            "metadata": {"referrer_user_id": user.id, "referrer_email": user.email},
        }
        if prefix:
            kwargs["code"] = f"{prefix}{user.id[:6]}".upper()
        pc = stripe.PromotionCode.create(**kwargs)
        code = pc["code"]
    except Exception as exc:
        raise RuntimeError(f"Failed to create referral code: {exc}") from exc
    return code or ""

