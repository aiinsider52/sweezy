import json
import os
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse
import asyncio
from pydantic import BaseModel

from ..dependencies import CurrentUser, DBSession
from ..core.database import db_session
from ..models.subscription import PremiumUsage
from ..models.user import User
from ..services import apple_iap_service
from ..services import stripe_service
from ..services.telegram import send_telegram_message
from ..core.config import get_settings
from urllib.parse import urlparse

router = APIRouter()


class CurrentOut(BaseModel):
    status: str
    expire_at: Optional[datetime] = None


@router.get("/current", response_model=CurrentOut)
def current(db: DBSession, user: CurrentUser) -> CurrentOut:
    if not _compute_is_premium(user.subscription_status or "free", user.subscription_expire_at):
        if user.subscription_status in {"trial", "premium"}:
            user.subscription_status = "free"
            user.subscription_expire_at = None
            db.add(user)
            db.commit()
    return CurrentOut(status=user.subscription_status, expire_at=user.subscription_expire_at)

class EntitlementsOut(BaseModel):
    status: str
    expire_at: Optional[datetime] = None
    is_premium: bool
    ai_access: bool
    favorites_limit: int | None  # None means unlimited
    guides_full_access: bool
    pdf_download: bool
    cv_free_uses_remaining: int

def _compute_is_premium(status: str, expire_at: Optional[datetime]) -> bool:
    if status in {"trial", "premium"}:
        if expire_at is None:
            return True
        try:
            comparable = expire_at if expire_at.tzinfo else expire_at.replace(tzinfo=timezone.utc)
            return comparable > datetime.now(timezone.utc)
        except Exception:
            return True
    return False

@router.get("/entitlements", response_model=EntitlementsOut)
def entitlements(db: DBSession, user: CurrentUser) -> EntitlementsOut:
    status = user.subscription_status or "free"
    expire_at = user.subscription_expire_at
    is_premium = _compute_is_premium(status, expire_at)
    if not is_premium and status in {"trial", "premium"}:
        user.subscription_status = "free"
        user.subscription_expire_at = None
        db.add(user)
        db.commit()
        status = "free"
        expire_at = None
    favorites_limit = None if is_premium else 3
    usage = (
        db.query(PremiumUsage)
        .filter(PremiumUsage.user_id == user.id, PremiumUsage.feature == "cv_tools")
        .one_or_none()
    )
    cv_free_uses_remaining = 3 if is_premium else max(0, 3 - (usage.free_uses if usage else 0))
    return EntitlementsOut(
        status=status,
        expire_at=expire_at,
        is_premium=is_premium,
        ai_access=is_premium,
        favorites_limit=favorites_limit,
        guides_full_access=is_premium,
        pdf_download=is_premium,
        cv_free_uses_remaining=cv_free_uses_remaining,
    )


@router.get("/stream")
async def stream(user: CurrentUser):
    """
    Server-Sent Events stream for live subscription updates.
    Emits 'update' when user.subscription_status or expire_at changes.
    Sends keepalive pings periodically.
    """
    async def event_generator():
        # initial snapshot
        last_status = user.subscription_status or "free"
        last_expire = user.subscription_expire_at.isoformat() if user.subscription_expire_at else None
        ping_counter = 0
        while True:
            await asyncio.sleep(10)
            # keepalive ping every 25s
            ping_counter += 10
            if ping_counter >= 25:
                yield "event: ping\ndata: keepalive\n\n"
                ping_counter = 0
            # reload user from DB in a background thread to avoid blocking event loop
            try:
                from asyncio import to_thread

                def _load_snapshot(user_id: str):
                    with db_session() as db:
                        refreshed = db.query(User).filter(User.id == user_id).first()
                        if not refreshed:
                            return None
                        cur_status = refreshed.subscription_status or "free"
                        cur_expire = (
                            refreshed.subscription_expire_at.isoformat()
                            if refreshed.subscription_expire_at
                            else None
                        )
                        return cur_status, cur_expire

                snapshot = await to_thread(_load_snapshot, user.id)
                if not snapshot:
                    continue
                cur_status, cur_expire = snapshot
                if cur_status != last_status or cur_expire != last_expire:
                    last_status = cur_status
                    last_expire = cur_expire
                    payload = {"status": cur_status, "expire_at": cur_expire}
                    yield f"event: update\ndata: {json.dumps(payload)}\n\n"
            except Exception:
                # soft fail and continue
                continue

    return StreamingResponse(event_generator(), media_type="text/event-stream")

class CheckoutIn(BaseModel):
    plan: str  # 'monthly'|'yearly'
    success_url: str
    cancel_url: str
    promotion_code: Optional[str] = None


class CheckoutOut(BaseModel):
    url: str


def _validate_redirect_url(value: str) -> None:
    parsed = urlparse(value)
    origin = f"{parsed.scheme}://{parsed.netloc}"
    allowed = {item.strip().rstrip("/") for item in (get_settings().STRIPE_REDIRECT_ORIGINS or "").split(",") if item.strip()}
    if parsed.scheme not in {"https", "sweezy"} or not parsed.netloc or origin not in allowed:
        raise HTTPException(status_code=422, detail="Redirect URL is not allowed")


@router.post("/checkout", response_model=CheckoutOut)
def create_checkout(payload: CheckoutIn, db: DBSession, user: CurrentUser) -> CheckoutOut:
    if not get_settings().STRIPE_SUBSCRIPTIONS_ENABLED:
        raise HTTPException(status_code=410, detail="Stripe subscription checkout is disabled for the iOS product")
    if payload.plan not in {"monthly", "yearly"}:
        raise HTTPException(status_code=400, detail="Invalid plan")
    _validate_redirect_url(payload.success_url)
    _validate_redirect_url(payload.cancel_url)
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
    raise HTTPException(
        status_code=410,
        detail="Legacy backend trial is disabled. Introductory offers are managed by App Store Connect.",
    )


class AppleTransactionIn(BaseModel):
    signed_transaction: str


class AppleSyncOut(BaseModel):
    status: str
    expire_at: Optional[datetime] = None
    product_id: str
    environment: str


@router.post("/apple/transactions", response_model=AppleSyncOut)
def sync_apple_transaction(payload: AppleTransactionIn, db: DBSession, user: CurrentUser) -> AppleSyncOut:
    if len(payload.signed_transaction) > 100_000:
        raise HTTPException(status_code=413, detail="Signed transaction is too large")
    try:
        row = apple_iap_service.sync_signed_transaction(db, user, payload.signed_transaction)
    except apple_iap_service.AppleIAPNotConfigured as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except apple_iap_service.AppleIAPConflict as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except apple_iap_service.AppleIAPError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return AppleSyncOut(
        status=user.subscription_status,
        expire_at=user.subscription_expire_at,
        product_id=row.product_id or "",
        environment=row.environment or "",
    )


class AppleNotificationIn(BaseModel):
    signedPayload: str


@router.post("/apple/notifications", status_code=200)
def apple_notifications(payload: AppleNotificationIn, db: DBSession) -> dict:
    if len(payload.signedPayload) > 250_000:
        raise HTTPException(status_code=413, detail="Signed notification is too large")
    try:
        result, _user_id = apple_iap_service.process_notification(db, payload.signedPayload)
    except apple_iap_service.AppleIAPNotConfigured as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except apple_iap_service.AppleIAPError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"ok": True, "result": result}

class ReferralOut(BaseModel):
    code: str

@router.post("/referral/create", response_model=ReferralOut)
def create_referral_code(user: CurrentUser) -> ReferralOut:
    if not get_settings().STRIPE_SUBSCRIPTIONS_ENABLED:
        raise HTTPException(status_code=410, detail="Stripe subscription referrals are disabled")
    try:
        code = stripe_service.create_referral_promotion_code(user, prefix="SWZ")
        return ReferralOut(code=code)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/stripe/webhook", status_code=200)
async def stripe_webhook(request: Request):
    if not get_settings().STRIPE_SUBSCRIPTIONS_ENABLED:
        raise HTTPException(status_code=410, detail="Stripe subscription webhook is disabled")
    from asyncio import to_thread

    payload = await request.body()
    sig = request.headers.get("stripe-signature")
    secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    if not secret:
        raise HTTPException(status_code=500, detail="Webhook not configured")
    import stripe  # type: ignore

    try:
        event = stripe.Webhook.construct_event(payload=payload, sig_header=sig, secret=secret)  # type: ignore
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail="Invalid signature") from exc

    data = event["data"]["object"]
    event_type = event["type"]

    # Process event in a background thread so DB work and HTTP calls don't block the event loop

    def _handle_event() -> dict:
        from ..core.database import db_session

        # Try to locate user via client_reference_id or customer id
        user: Optional[User] = None
        client_ref = data.get("client_reference_id") or data.get("client_reference_id".replace("_", ""))
        customer_id = data.get("customer") or data.get("customer_id")
        subscription_id = data.get("subscription") or data.get("id")

        with db_session() as db:
            if client_ref:
                user = db.query(User).filter(User.id == str(client_ref)).one_or_none()
            if not user and customer_id:
                user = db.query(User).filter(User.stripe_customer_id == str(customer_id)).one_or_none()

            stripe_service.log_event(db, user.id if user else None, event_type, json.loads(payload.decode("utf-8")))

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
                send_telegram_message(
                    f"✅ Subscription active for {user.email} (until {period_end.isoformat() if period_end else 'n/a'})"
                )
                return {"ok": True}

            if event_type in {"customer.subscription.deleted"}:
                if user:
                    stripe_service.apply_free(db, user)
                    send_telegram_message(f"⚠️ Subscription canceled for {user.email}")
                return {"ok": True}

            return {"ok": True}

    return await to_thread(_handle_event)
