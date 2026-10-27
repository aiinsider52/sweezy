from __future__ import annotations

import math
import uuid
from dataclasses import asdict, dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Any

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..core.config import get_settings
from ..models.business import BusinessProfile, BusinessPurchase, BusinessReview, BusinessStatDaily
from ..models.user import User


PLANS = ("free", "pro", "business")
BOOST_DAYS = 7

BUSINESS_KINDS = ("business", "specialist", "club")
BUSINESS_CATEGORIES = (
    "beauty",
    "food",
    "health",
    "legal",
    "translation",
    "finance",
    "education",
    "it",
    "repair",
    "cleaning",
    "moving",
    "auto",
    "retail",
    "events",
    "community",
    "other",
)
# Guide / checklist topics → business categories that help with that step.
CONTEXT_TOPICS: dict[str, tuple[str, ...]] = {
    "documents": ("translation", "legal"),
    "legal": ("legal", "translation"),
    "finance": ("finance",),
    "taxes": ("finance",),
    "housing": ("moving", "repair", "cleaning"),
    "health": ("health",),
    "work": ("education", "it", "legal"),
    "education": ("education",),
    "language": ("education", "translation"),
    "family": ("education", "health"),
    "transport": ("auto",),
    "community": ("community", "events"),
}
STAT_METRICS = ("view", "call", "website", "route", "message", "booking", "offer", "share")
PLAN_RANK = {"free": 0, "pro": 1, "business": 2}


@dataclass(frozen=True)
class PlanLimits:
    services: int
    offers: int
    quick_replies: int
    stats_days: int
    documents: bool
    ai_receptionist: bool
    team_members: int


PLAN_LIMITS: dict[str, PlanLimits] = {
    "free": PlanLimits(services=3, offers=0, quick_replies=5, stats_days=7, documents=False, ai_receptionist=False, team_members=0),
    "pro": PlanLimits(services=20, offers=5, quick_replies=50, stats_days=90, documents=True, ai_receptionist=False, team_members=0),
    "business": PlanLimits(services=50, offers=20, quick_replies=50, stats_days=365, documents=True, ai_receptionist=True, team_members=10),
}


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def effective_plan(profile: BusinessProfile | None) -> str:
    if profile is None or profile.plan not in PLAN_RANK or profile.plan == "free":
        return "free"
    expires = _aware(profile.plan_expires_at)
    if expires is None or expires <= now_utc():
        return "free"
    return profile.plan


def limits_for(profile: BusinessProfile | None) -> PlanLimits:
    return PLAN_LIMITS[effective_plan(profile)]


def limits_dict(plan: str) -> dict[str, Any]:
    return asdict(PLAN_LIMITS[plan])


def is_boosted(profile: BusinessProfile) -> bool:
    until = _aware(profile.boost_until)
    return until is not None and until > now_utc()


def require_plan(profile: BusinessProfile, minimum: str) -> None:
    if PLAN_RANK[effective_plan(profile)] < PLAN_RANK[minimum]:
        raise HTTPException(
            status_code=402,
            detail={"code": "business_plan_required", "required_plan": minimum},
        )


def ranking_key(profile: BusinessProfile) -> tuple:
    """Higher sorts first: sponsored, paid plan, verified, then a review-weighted score."""
    rating = profile.average_rating or 0.0
    score = rating * math.log1p(profile.review_count or 0)
    updated = _aware(profile.updated_at) or datetime.min.replace(tzinfo=timezone.utc)
    return (
        is_boosted(profile),
        PLAN_RANK[effective_plan(profile)],
        bool(profile.is_verified),
        score,
        updated,
    )


def record_stat(db: Session, business_user_id: str, metric: str, *, day: date | None = None) -> None:
    day = day or now_utc().date()
    for _ in range(2):
        row = db.execute(
            select(BusinessStatDaily).where(
                BusinessStatDaily.business_user_id == business_user_id,
                BusinessStatDaily.day == day,
                BusinessStatDaily.metric == metric,
            ).with_for_update()
        ).scalar_one_or_none()
        if row is None:
            db.add(BusinessStatDaily(business_user_id=business_user_id, day=day, metric=metric, count=1))
        else:
            row.count += 1
        try:
            db.commit()
            return
        except IntegrityError:
            # A concurrent request created today's counter first; retry as an update.
            db.rollback()


def refresh_rating(db: Session, business_user_id: str) -> None:
    profile = db.get(BusinessProfile, business_user_id)
    if profile is None:
        return
    average, count = db.execute(
        select(func.avg(BusinessReview.rating), func.count(BusinessReview.id)).where(
            BusinessReview.business_user_id == business_user_id,
            BusinessReview.status == "published",
        )
    ).one()
    profile.review_count = int(count or 0)
    profile.average_rating = round(float(average), 1) if average is not None else None
    db.add(profile)


# MARK: - Apple In-App Purchases


class BusinessPurchaseError(RuntimeError):
    pass


def business_product_ids() -> set[str]:
    return set(get_settings().parsed_apple_business_product_ids())


def is_business_product(product_id: str | None) -> bool:
    return bool(product_id) and product_id in business_product_ids()


def product_effect(product_id: str) -> tuple[str, str | None]:
    """Returns (purchase kind, plan) for a configured business product."""
    if "boost" in product_id:
        return "boost", None
    if "_max_" in product_id:
        return "plan", "business"
    if "_pro_" in product_id:
        return "plan", "pro"
    raise BusinessPurchaseError("Unknown business product")


def _from_ms(value: int | None) -> datetime | None:
    if value is None:
        return None
    return datetime.fromtimestamp(value / 1000, tz=timezone.utc)


def apply_business_transaction(db: Session, user: User, decoded: Any) -> BusinessProfile:
    """Applies a verified App Store transaction for a business product to the user's profile."""
    settings = get_settings()
    if decoded.bundleId != settings.APPLE_IAP_BUNDLE_ID:
        raise BusinessPurchaseError("Apple transaction bundle does not match")
    if not is_business_product(decoded.productId):
        raise BusinessPurchaseError("Unknown business product")
    if not decoded.transactionId:
        raise BusinessPurchaseError("Apple transaction identifiers are missing")
    token = decoded.appAccountToken
    if token and str(uuid.UUID(token)) != str(uuid.UUID(user.id)):
        raise BusinessPurchaseError("Apple purchase belongs to another Sweezy account")
    profile = db.get(BusinessProfile, user.id)
    if profile is None:
        raise BusinessPurchaseError("Business profile required")

    kind, plan = product_effect(decoded.productId)
    existing = db.execute(
        select(BusinessPurchase).where(BusinessPurchase.transaction_id == decoded.transactionId)
    ).scalar_one_or_none()
    if existing and existing.business_user_id != user.id:
        raise BusinessPurchaseError("Apple purchase is already linked to another business")

    revoked = _from_ms(getattr(decoded, "revocationDate", None)) is not None
    environment = decoded.environment.value if decoded.environment else getattr(decoded, "rawEnvironment", None)
    if kind == "boost":
        if existing is None and not revoked:
            start = max(filter(None, (_aware(profile.boost_until), now_utc())))
            profile.boost_until = start + timedelta(days=BOOST_DAYS)
            db.add(BusinessPurchase(
                business_user_id=user.id,
                product_id=decoded.productId,
                kind="boost",
                transaction_id=decoded.transactionId,
                original_transaction_id=decoded.originalTransactionId,
                environment=environment,
                expires_at=profile.boost_until,
            ))
    else:
        expires_at = _from_ms(decoded.expiresDate)
        if revoked or bool(getattr(decoded, "isUpgraded", False)):
            if profile.plan_original_transaction_id == decoded.originalTransactionId:
                profile.plan_expires_at = now_utc()
        elif expires_at is not None:
            current = _aware(profile.plan_expires_at)
            # A renewal or upgrade replaces the plan; an older transaction never shortens it.
            if current is None or expires_at >= current or profile.plan_source != "apple":
                profile.plan = plan or "free"
                profile.plan_expires_at = expires_at
                profile.plan_source = "apple"
                profile.plan_original_transaction_id = decoded.originalTransactionId
        if existing is None:
            db.add(BusinessPurchase(
                business_user_id=user.id,
                product_id=decoded.productId,
                kind="plan",
                transaction_id=decoded.transactionId,
                original_transaction_id=decoded.originalTransactionId,
                environment=environment,
                expires_at=expires_at,
            ))
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile


def resolve_business_purchase_user(db: Session, decoded: Any) -> User | None:
    original_id = getattr(decoded, "originalTransactionId", None)
    if original_id:
        purchase = db.execute(
            select(BusinessPurchase).where(BusinessPurchase.original_transaction_id == original_id).limit(1)
        ).scalar_one_or_none()
        if purchase:
            return db.get(User, purchase.business_user_id)
    token = getattr(decoded, "appAccountToken", None)
    if token:
        try:
            return db.get(User, str(uuid.UUID(token)))
        except ValueError:
            return None
    return None
