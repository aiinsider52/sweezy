from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..dependencies import DBSession, CurrentUser
from ..models.user import User
from ..models.subscription import Subscription, SubscriptionEvent
from ..services import stripe_service

router = APIRouter()


class CurrentOut(BaseModel):
    status: str
    expire_at: Optional[datetime] = None


@router.get("/current", response_model=CurrentOut)
def current(user: CurrentUser) -> CurrentOut:
    return CurrentOut(status=user.subscription_status, expire_at=user.subscription_expire_at)

class EntitlementsOut(BaseModel):
    status: str
    expire_at: Optional[datetime] = None
    is_premium: bool
    ai_access: bool
    favorites_limit: int | None  # None means unlimited
    guides_full_access: bool
    pdf_download: bool

def _compute_is_premium(status: str, expire_at: Optional[datetime]) -> bool:
    if status in {"trial", "premium"}:
        if expire_at is None:
            return True
        try:
            return expire_at > datetime.now(timezone.utc)
        except Exception:
            return True
    return False

@router.get("/entitlements", response_model=EntitlementsOut)
def entitlements(user: CurrentUser) -> EntitlementsOut:
    status = user.subscription_status or "free"
    expire_at = user.subscription_expire_at
    is_premium = _compute_is_premium(status, expire_at)
    favorites_limit = None if is_premium else 3
    return EntitlementsOut(
        status=status,
        expire_at=expire_at,
        is_premium=is_premium,
        ai_access=is_premium,
        favorites_limit=favorites_limit,
        guides_full_access=is_premium,
        pdf_download=is_premium,
    )


class CheckoutIn(BaseModel):
    plan: str  # 'monthly'|'yearly'
    success_url: str
    cancel_url: str
    promotion_code: Optional[str] = None


class CheckoutOut(BaseModel):
    url: str


@router.post("/checkout", response_model=CheckoutOut)
def create_checkout(payload: CheckoutIn, db: DBSession, user: CurrentUser) -> CheckoutOut:
    if payload.plan not in {"monthly", "yearly"}:
        raise HTTPException(status_code=400, detail="Invalid plan")
    try:
        url = stripe_service.create_checkout_session(
            db,
            user,
            payload.plan,
            success_url=payload.success_url,
            cancel_url=payload.cancel_url,
            promotion_code=payload.promotion_code,
        )
        return CheckoutOut(url=url)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/trial", response_model=CurrentOut)
def start_trial(db: DBSession, user: CurrentUser) -> CurrentOut:
    # Allow trial only once (if already premium/trial then reject)
    if user.subscription_status in {"trial", "premium"}:
        raise HTTPException(status_code=400, detail="Trial already used or active subscription")
    user = stripe_service.apply_trial(db, user, days=7)
    return CurrentOut(status=user.subscription_status, expire_at=user.subscription_expire_at)

class ReferralOut(BaseModel):
    code: str

@router.post("/referral/create", response_model=ReferralOut)
def create_referral_code(user: CurrentUser) -> ReferralOut:
    try:
        code = stripe_service.create_referral_promotion_code(user, prefix="SWZ")
        return ReferralOut(code=code)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/stripe/webhook", status_code=200)
async def stripe_webhook(request: Request, db: DBSession):
    payload = await request.body()
    sig = request.headers.get("stripe-signature")
    secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    if not secret:
        raise HTTPException(status_code=500, detail="Webhook not configured")
    import stripe  # type: ignore
    import urllib.request
    import json as _json

    try:
        event = stripe.Webhook.construct_event(payload=payload, sig_header=sig, secret=secret)  # type: ignore
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail="Invalid signature") from exc

    data = event["data"]["object"]
    event_type = event["type"]

    # Try to locate user via client_reference_id or customer id
    user: Optional[User] = None
    client_ref = data.get("client_reference_id") or data.get("client_reference_id".replace("_", ""))
    customer_id = data.get("customer") or data.get("customer_id")
    subscription_id = data.get("subscription") or data.get("id")

    if client_ref:
        user = db.query(User).filter(User.id == str(client_ref)).one_or_none()
    if not user and customer_id:
        user = db.query(User).filter(User.stripe_customer_id == str(customer_id)).one_or_none()

    stripe_service.log_event(db, user.id if user else None, event_type, json.loads(payload.decode("utf-8")))

    # Optional Telegram notification (only for key events)
    def _notify_telegram(text: str) -> None:
        token = os.getenv("TELEGRAM_BOT_TOKEN")
        chat_id = os.getenv("TELEGRAM_CHAT_ID")
        if not token or not chat_id:
            return
        try:
            url = f"https://api.telegram.org/bot{token}/sendMessage"
            data = _json.dumps({"chat_id": chat_id, "text": text}).encode("utf-8")
            req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
            urllib.request.urlopen(req, timeout=3)  # nosec B310
        except Exception:
            pass

    # Handle events
    if event_type == "checkout.session.completed":
        # nothing to do; wait for invoice.payment_succeeded
        return {"ok": True}

    if event_type in {"invoice.payment_succeeded", "customer.subscription.updated"}:
        # subscription active/renewed
        if not user:
            return {"ok": True}
        # extract current period end
        period_end = None
        try:
            if "current_period_end" in data:
                ts = int(data["current_period_end"])
                period_end = datetime.fromtimestamp(ts, tz=timezone.utc)
            elif "lines" in data and "data" in data["lines"] and data["lines"]["data"]:
                ts = int(data["lines"]["data"][0]["period"]["end"])
                period_end = datetime.fromtimestamp(ts, tz=timezone.utc)
        except Exception:
            period_end = None
        stripe_service.apply_premium(db, user, subscription_id=str(subscription_id), current_period_end=period_end)
        _notify_telegram(f"✅ Subscription active for {user.email} (until {period_end.isoformat() if period_end else 'n/a'})")
        return {"ok": True}

    if event_type in {"customer.subscription.deleted"}:
        if user:
            stripe_service.apply_free(db, user)
            _notify_telegram(f"⚠️ Subscription canceled for {user.email}")
        return {"ok": True}

    return {"ok": True}


