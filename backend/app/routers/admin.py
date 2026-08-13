from typing import Any, Dict, List
import csv
import hashlib
import io
import json
import re
import time
from datetime import date, datetime
from urllib.parse import urlparse, urljoin

from fastapi import APIRouter, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field, model_validator
from sqlalchemy import func, or_, select

from ..dependencies import DBSession, CurrentAdmin
from ..models import User, Guide, Template, Checklist, Appointment
from ..models.audit_log import AuditLog
from ..models.news import News
from ..schemas import GuideCreate, TemplateCreate, ChecklistCreate
from ..core.config import get_settings
from ..routers.media import UPLOAD_DIR
from ..models.rss_feed import RSSFeed
from ..models.brave_news_query import BraveNewsQuery
from ..services.rss_importer import RSSImporter
from ..core.url_security import validate_public_http_url
from ..services.brave_search_importer import BraveSearchImporter
from ..models.subscription import Subscription, SubscriptionEvent
from ..models.analytics import PaywallEvent
from ..models.network import ProfessionalProfile
from ..models.social import SocialProfile
from ..services import stripe_service
from ..services.audit import log_audit
from ..models.moderation import ModerationAction, ModerationCase
from ..services.moderation import notify_user, utcnow
from datetime import timedelta, timezone
import feedparser
import httpx


router = APIRouter()


class ProfileModerationDecision(BaseModel):
    reason: str | None = Field(default=None, max_length=500)


def _profile_moderation_item(kind: str, profile: SocialProfile | ProfessionalProfile) -> Dict[str, Any]:
    return {
        "kind": kind,
        "user_id": profile.user_id,
        "display_name": profile.display_name,
        "canton": profile.canton,
        "city": profile.city,
        "bio": profile.bio,
        "avatar_url": profile.avatar_url,
        "moderation_status": profile.moderation_status,
        "moderation_reason": profile.moderation_reason,
        "created_at": profile.created_at.isoformat() if profile.created_at else None,
        "updated_at": profile.updated_at.isoformat() if profile.updated_at else None,
        "moderated_at": profile.moderated_at.isoformat() if profile.moderated_at else None,
        "details": {
            "interests": profile.interests,
            "languages": profile.languages,
            "meetup_formats": profile.meetup_formats,
        } if kind == "social" else {
            "headline": profile.headline,
            "company_name": profile.company_name,
            "role": profile.role,
            "industry": profile.industry,
            "skills": profile.skills,
            "languages": profile.languages,
            "goals": profile.goals,
            "website_url": profile.website_url,
        },
    }


@router.get("/profile-moderation")
def profile_moderation_queue(
    _: CurrentAdmin,
    db: DBSession,
    moderation_status: str | None = Query(default=None, alias="status", pattern="^(pending|approved|rejected)$"),
    kind: str | None = Query(default=None, pattern="^(social|professional)$"),
) -> List[Dict[str, Any]]:
    items: list[Dict[str, Any]] = []
    if kind in (None, "social"):
        query = db.query(SocialProfile)
        if moderation_status: query = query.filter(SocialProfile.moderation_status == moderation_status)
        items.extend(_profile_moderation_item("social", row) for row in query.all())
    if kind in (None, "professional"):
        query = db.query(ProfessionalProfile)
        if moderation_status: query = query.filter(ProfessionalProfile.moderation_status == moderation_status)
        items.extend(_profile_moderation_item("professional", row) for row in query.all())
    return sorted(items, key=lambda item: item["updated_at"] or "", reverse=True)


def _moderate_profile(kind: str, user_id: str, db: DBSession) -> SocialProfile | ProfessionalProfile:
    model = SocialProfile if kind == "social" else ProfessionalProfile if kind == "professional" else None
    if model is None: raise HTTPException(status_code=404, detail="Profile type not found")
    profile = db.get(model, user_id)
    if not profile: raise HTTPException(status_code=404, detail="Profile not found")
    return profile


@router.patch("/profile-moderation/{kind}/{user_id}/approve")
def approve_profile(kind: str, user_id: str, payload: ProfileModerationDecision, admin: CurrentAdmin, db: DBSession) -> Dict[str, Any]:
    profile = _moderate_profile(kind, user_id, db)
    profile.moderation_status = "approved"
    profile.moderation_reason = payload.reason
    profile.moderated_at = datetime.now(timezone.utc)
    profile.moderated_by = admin.get("sub")
    case = db.scalar(select(ModerationCase).where(ModerationCase.source_key == f"{kind}_profile_review:{user_id}"))
    if case:
        case.status = "resolved"; case.decision = "approve"; case.moderator_comment = payload.reason or "Profile approved"; case.resolved_at = utcnow(); case.assigned_to = admin.get("sub")
        db.add(ModerationAction(case_id=case.id, subject_user_id=user_id, moderator_id=admin.get("sub"), action="approve", comment=payload.reason or "Profile approved"))
        notify_user(db, user_id=user_id, case_id=case.id, kind="profile_approved", title="Profile approved", body="Your profile is now visible in Sweezy.", event_key=f"moderation:profile:approved:{case.id}:{profile.updated_at}")
    db.add(profile); db.commit(); db.refresh(profile)
    return _profile_moderation_item(kind, profile)


@router.patch("/profile-moderation/{kind}/{user_id}/reject")
def reject_profile(kind: str, user_id: str, payload: ProfileModerationDecision, admin: CurrentAdmin, db: DBSession) -> Dict[str, Any]:
    reason = (payload.reason or "").strip()
    if not reason: raise HTTPException(status_code=400, detail="Rejection reason is required")
    profile = _moderate_profile(kind, user_id, db)
    profile.moderation_status = "rejected"
    profile.moderation_reason = reason
    profile.moderated_at = datetime.now(timezone.utc)
    profile.moderated_by = admin.get("sub")
    case = db.scalar(select(ModerationCase).where(ModerationCase.source_key == f"{kind}_profile_review:{user_id}"))
    if case:
        case.status = "resolved"; case.decision = "reject"; case.moderator_comment = reason; case.resolved_at = utcnow(); case.assigned_to = admin.get("sub")
        db.add(ModerationAction(case_id=case.id, subject_user_id=user_id, moderator_id=admin.get("sub"), action="reject", comment=reason))
        notify_user(db, user_id=user_id, case_id=case.id, kind="profile_rejected", title="Profile needs changes", body=reason, event_key=f"moderation:profile:rejected:{case.id}:{profile.updated_at}")
    db.add(profile); db.commit(); db.refresh(profile)
    return _profile_moderation_item(kind, profile)


class AdminSubscriptionUpdate(BaseModel):
    status: str = Field(pattern="^(free|trial|premium)$")
    plan: str | None = Field(default=None, pattern="^(monthly|yearly)$")
    purchased_at: datetime | None = None
    expire_at: datetime | None = None
    duration_days: int | None = Field(default=None, ge=1, le=3660)
    reason: str = Field(min_length=3, max_length=500)

    @model_validator(mode="after")
    def validate_period(self):
        if self.status == "premium" and not self.plan:
            raise ValueError("Plan is required for premium")
        if self.purchased_at and self.expire_at and self.expire_at <= self.purchased_at:
            raise ValueError("Expiration must be after purchase date")
        return self


@router.get("/stats")
def stats(_: CurrentAdmin, db: DBSession) -> Dict[str, Any]:
    settings = get_settings()
    counts = {
        "users": db.scalar(select(func.count()).select_from(User)) or 0,
        "guides": db.scalar(select(func.count()).select_from(Guide)) or 0,
        "templates": db.scalar(select(func.count()).select_from(Template)) or 0,
        "checklists": db.scalar(select(func.count()).select_from(Checklist)) or 0,
        "appointments": db.scalar(select(func.count()).select_from(Appointment)) or 0,
        "news": db.scalar(select(func.count()).select_from(News)) or 0,
    }
    return {
        "app_version": settings.APP_VERSION,
        "counts": counts,
    }


def _filtered_users_query(
    db: DBSession,
    search: str | None,
    role: str | None,
    user_status: str | None,
    subscription: str | None,
    created_from: date | None = None,
    created_to: date | None = None,
):
    query = db.query(User)
    if search:
        term = f"%{search.strip()}%"
        query = query.filter(or_(User.email.ilike(term), User.id.ilike(term)))
    if role:
        query = query.filter(User.role == role)
    if user_status == "active":
        query = query.filter(User.is_active.is_(True))
    elif user_status == "inactive":
        query = query.filter(User.is_active.is_(False))
    if subscription:
        query = query.filter(User.subscription_status == subscription)
    if created_from:
        query = query.filter(User.created_at >= datetime.combine(created_from, datetime.min.time()))
    if created_to:
        query = query.filter(User.created_at < datetime.combine(created_to + timedelta(days=1), datetime.min.time()))
    return query


def _serialize_user(r: User) -> Dict[str, Any]:
    return {
        "id": r.id,
        "email": r.email,
        "is_superuser": bool(r.is_superuser),
        "is_active": bool(r.is_active),
        "email_verified": bool(r.email_verified),
        "role": r.role,
        "subscription_status": r.subscription_status,
        "created_at": r.created_at.isoformat() if r.created_at else None,
    }


@router.get("/users")
def list_users(
    _: CurrentAdmin,
    db: DBSession,
    page: int | None = Query(default=None, ge=1),
    page_size: int = Query(default=25, ge=1, le=100),
    search: str | None = Query(default=None, max_length=255),
    role: str | None = Query(default=None),
    status: str | None = Query(default=None),
    subscription: str | None = Query(default=None),
    created_from: date | None = Query(default=None),
    created_to: date | None = Query(default=None),
) -> Any:
    if created_from and created_to and created_from > created_to:
        raise HTTPException(status_code=422, detail="created_from must not be after created_to")
    query = _filtered_users_query(
        db, search, role, status, subscription, created_from, created_to
    )
    # Preserve the original array response for callers that do not request pagination.
    if page is None and not any((search, role, status, subscription, created_from, created_to)):
        return [_serialize_user(r) for r in query.order_by(User.created_at.desc()).limit(100).all()]
    current_page = page or 1
    total = query.count()
    rows = query.order_by(User.created_at.desc()).offset((current_page - 1) * page_size).limit(page_size).all()
    return {
        "items": [_serialize_user(r) for r in rows],
        "page": current_page,
        "page_size": page_size,
        "total": total,
        "pages": (total + page_size - 1) // page_size,
    }


@router.get("/users/stats")
def user_stats(_: CurrentAdmin, db: DBSession) -> Dict[str, int]:
    since = datetime.now(timezone.utc) - timedelta(days=30)
    return {
        "total": db.query(User).count(),
        "active": db.query(User).filter(User.is_active.is_(True)).count(),
        "verified": db.query(User).filter(User.email_verified.is_(True)).count(),
        "premium": db.query(User).filter(User.subscription_status == "premium").count(),
        "admins": db.query(User).filter(User.is_superuser.is_(True)).count(),
        "new_30d": db.query(User).filter(User.created_at >= since).count(),
    }


@router.get("/users/registrations")
def user_registrations(
    _: CurrentAdmin,
    db: DBSession,
    days: int = Query(default=30, ge=1, le=365),
) -> Dict[str, Any]:
    """Daily account-creation counts from User.created_at (not product telemetry)."""
    today = datetime.now(timezone.utc).date()
    since_date = today - timedelta(days=days - 1)
    since = datetime.combine(since_date, datetime.min.time(), tzinfo=timezone.utc)
    dialect = db.get_bind().dialect.name
    day_bucket = (
        func.date(User.created_at)
        if dialect == "sqlite"
        else func.date_trunc("day", User.created_at)
    )

    rows = (
        db.query(day_bucket.label("day"), func.count().label("count"))
        .filter(User.created_at >= since)
        .group_by(day_bucket)
        .order_by(day_bucket.asc())
        .all()
    )
    by_day: Dict[Any, int] = {}
    for row in rows:
        if row.day is None:
            continue
        value = row.day.date() if hasattr(row.day, "date") else row.day
        if isinstance(value, str):
            value = date.fromisoformat(value)
        by_day[value] = int(row.count or 0)
    trends = [
        {
            "date": (since_date + timedelta(days=offset)).isoformat(),
            "count": by_day.get(since_date + timedelta(days=offset), 0),
        }
        for offset in range(days)
    ]
    total_in_range = sum(point["count"] for point in trends)
    today_count = by_day.get(today, 0)
    last_7 = sum(point["count"] for point in trends[-7:])
    previous_7 = sum(point["count"] for point in trends[-14:-7]) if days >= 14 else 0
    delta_7 = None
    if days >= 14 and previous_7 > 0:
        delta_7 = round(((last_7 - previous_7) / previous_7) * 100)
    elif days >= 14 and last_7 > 0:
        delta_7 = 100

    return {
        "days": days,
        "since": since_date.isoformat(),
        "total_in_range": total_in_range,
        "today": today_count,
        "last_7d": last_7,
        "last_30d": sum(point["count"] for point in trends[-30:]),
        "avg_per_day": round(total_in_range / days, 2) if days else 0,
        "delta_7d_percent": delta_7,
        "trends": trends,
    }


def _csv_safe(value: Any) -> str:
    text = "" if value is None else str(value)
    return f"'{text}" if text.startswith(("=", "+", "-", "@")) else text


def _meta_email_hash(email: str) -> str:
    normalized = email.strip().lower()
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def _record_user_export_audit(
    db: DBSession,
    *,
    admin: Dict[str, Any],
    filters: Dict[str, Any],
    purpose: str,
    row_count: int,
    outcome: str,
) -> None:
    actor = db.query(User).filter(User.id == admin.get("sub")).first()
    entry = AuditLog(
        user_email=actor.email if actor else f"user:{admin.get('sub', 'unknown')}",
        action="export",
        entity="users",
        entity_id="meta_custom_audience",
        changes=json.dumps({
            "filters": filters,
            "purpose": purpose,
            "format": "meta_custom_audience_sha256",
            "row_count": row_count,
            "outcome": outcome,
        }, sort_keys=True),
    )
    db.add(entry)
    db.commit()


@router.post("/users/export")
def export_users(
    admin: CurrentAdmin,
    db: DBSession,
    search: str | None = Query(default=None, max_length=255),
    role: str | None = Query(default=None),
    status: str | None = Query(default=None),
    subscription: str | None = Query(default=None),
    created_from: date | None = Query(default=None),
    created_to: date | None = Query(default=None),
    purpose: str = Query(default="meta_custom_audience", pattern="^meta_custom_audience$"),
) -> StreamingResponse:
    if created_from and created_to and created_from > created_to:
        raise HTTPException(status_code=422, detail="created_from must not be after created_to")
    filters = {
        key: value.isoformat() if isinstance(value, (date, datetime)) else value
        for key, value in {
            "search": search,
            "role": role,
            "status": status,
            "subscription": subscription,
            "created_from": created_from,
            "created_to": created_to,
        }.items()
        if value is not None
    }
    try:
        rows = (
            _filtered_users_query(
                db, search, role, status, subscription, created_from, created_to
            )
            .filter(User.email_verified.is_(True))
            .order_by(User.created_at.desc())
            .all()
        )
        output = io.StringIO(newline="")
        writer = csv.writer(output, lineterminator="\n")
        writer.writerow(["email"])
        for row in rows:
            # A fixed-width lowercase hex digest cannot trigger spreadsheet formulas.
            writer.writerow([_meta_email_hash(row.email)])
        _record_user_export_audit(
            db,
            admin=admin,
            filters=filters,
            purpose=purpose,
            row_count=len(rows),
            outcome="success",
        )
    except Exception:
        db.rollback()
        try:
            _record_user_export_audit(
                db,
                admin=admin,
                filters=filters,
                purpose=purpose,
                row_count=0,
                outcome="failed",
            )
        except Exception:
            db.rollback()
        raise
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={
            "Content-Disposition": 'attachment; filename="meta-custom-audience-sha256.csv"',
            "X-Export-Row-Count": str(len(rows)),
        },
    )


@router.get("/activity")
def activity(_: CurrentAdmin, db: DBSession) -> Dict[str, Any]:
    def recent_simple(model):
        created = getattr(model, "created_at")
        rows = db.query(model.id, created).order_by(created.desc()).limit(5).all()
        return [
            {"id": r.id, "created_at": r.created_at.isoformat() if r.created_at else None}
            for r in rows
        ]

    recent_users = (
        db.query(User.id, User.email, User.created_at)
        .order_by(User.created_at.desc())
        .limit(5)
        .all()
    )
    return {
        "users": [
            {
                "id": r.id,
                "email": r.email,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in recent_users
        ],
        "guides": recent_simple(Guide),
        "templates": recent_simple(Template),
        "checklists": recent_simple(Checklist),
        "appointments": recent_simple(Appointment),
    }


@router.get("/categories/guides")
def guide_categories(_: CurrentAdmin) -> Dict[str, Any]:
    # Keep in sync with Swift enum GuideCategory
    categories = [
        "documents", "housing", "insurance", "work", "finance", "education",
        "healthcare", "legal", "emergency", "integration", "transport", "banking",
    ]
    return {"categories": categories}


@router.post("/import/guides")
def import_guides(payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    items = payload.get("items") or []
    created = 0
    for raw in items:
        try:
            try:
                # Try backend shape first
                data = GuideCreate(**raw)
                title = data.title
                slug = data.slug
                description = data.description
                content = data.content
                category = data.category
                image_url = getattr(data, "image_url", None)
                is_published = data.is_published
                version = data.version
            except Exception:
                # Fallback to iOS seed shape
                def slugify(s: str) -> str:
                    s = s.lower()
                    s = re.sub(r"[^a-z0-9\s-]", "", s)
                    s = re.sub(r"[\s-]+", "-", s).strip("-")
                    return s or "guide"

                title = raw.get("title") or raw.get("name") or "Untitled"
                slug = raw.get("slug") or slugify(title)
                description = raw.get("subtitle") or raw.get("description")
                content = raw.get("bodyMarkdown") or raw.get("content")
                category = (raw.get("category") or "documents")
                image_url = raw.get("heroImage") or raw.get("image_url")
                is_published = bool(raw.get("is_published", True))
                version = int(raw.get("version", 1))

            obj = Guide(
                title=title,
                slug=slug,
                description=description,
                content=content,
                category=category,
                image_url=image_url,
                is_published=is_published,
                version=version,
            )
            db.add(obj)
            created += 1
        except Exception:
            continue
    db.commit()
    return {"created": created}


@router.put("/users/{user_id}/role")
def update_user_role(user_id: str, payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    role = payload.get("role")
    if role not in ["admin", "editor", "translator", "viewer"]:
        raise HTTPException(status_code=400, detail="Invalid role")
    user.role = role
    # Keep is_superuser in sync for 'admin'
    user.is_superuser = bool(role == "admin")
    db.add(user)
    db.commit()
    return {"ok": True}


@router.get("/audit-logs")
def list_audit_logs(_: CurrentAdmin, db: DBSession, limit: int = 100) -> List[Dict[str, Any]]:
    rows = db.query(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit).all()
    return [
        {
            "id": r.id,
            "user_email": r.user_email,
            "action": r.action,
            "entity": r.entity,
            "entity_id": r.entity_id,
            "changes": r.changes,
            "created_at": r.created_at.isoformat(),
        }
        for r in rows
    ]


@router.get("/audit-logs/export")
def export_audit_logs(_: CurrentAdmin, db: DBSession, limit: int = Query(default=1000, ge=1, le=10000)) -> StreamingResponse:
    rows = db.query(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit).all()
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["created_at", "user_email", "action", "entity", "entity_id", "changes"])
    for row in rows:
        writer.writerow([
            row.created_at.isoformat(), _csv_safe(row.user_email), _csv_safe(row.action),
            _csv_safe(row.entity), _csv_safe(row.entity_id), _csv_safe(row.changes),
        ])
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": 'attachment; filename="audit-logs.csv"'},
    )
 
 
@router.get("/subscriptions")
def list_subscriptions(_: CurrentAdmin, db: DBSession, limit: int = 200) -> List[Dict[str, Any]]:
    users = db.query(User).order_by(User.created_at.desc()).limit(limit).all()
    user_ids = [user.id for user in users]
    subscriptions = (
        db.query(Subscription)
        .filter(Subscription.user_id.in_(user_ids))
        .order_by(Subscription.updated_at.desc())
        .all()
        if user_ids else []
    )
    by_user: dict[str, list[Subscription]] = {}
    for subscription in subscriptions:
        by_user.setdefault(subscription.user_id, []).append(subscription)
    result: list[dict[str, Any]] = []
    for user in users:
        records = by_user.get(user.id) or [None]
        for subscription in records:
            result.append({
                "row_id": subscription.id if subscription else f"user:{user.id}",
                "user_id": user.id,
                "email": user.email,
                "status": user.subscription_status,
                "expire_at": user.subscription_expire_at.isoformat() if user.subscription_expire_at else None,
                "subscription_id": subscription.id if subscription else None,
                "provider": subscription.provider if subscription else "none",
                "provider_status": subscription.status if subscription else "free",
                "plan": subscription.plan if subscription else None,
                "product_id": subscription.product_id if subscription else None,
                "purchased_at": subscription.purchased_at.isoformat() if subscription and subscription.purchased_at else None,
                "current_period_end": subscription.current_period_end.isoformat() if subscription and subscription.current_period_end else None,
                "auto_renew_enabled": subscription.auto_renew_enabled if subscription else None,
                "environment": subscription.environment if subscription else None,
                "revocation_date": subscription.revocation_date.isoformat() if subscription and subscription.revocation_date else None,
                "last_verified_at": subscription.last_verified_at.isoformat() if subscription and subscription.last_verified_at else None,
                "original_transaction_id": subscription.original_transaction_id if subscription else None,
                "latest_transaction_id": subscription.latest_transaction_id if subscription else None,
                "stripe_customer_id": subscription.stripe_customer_id if subscription else user.stripe_customer_id,
                "stripe_subscription_id": subscription.stripe_subscription_id if subscription else user.stripe_subscription_id,
                "created_at": subscription.created_at.isoformat() if subscription and subscription.created_at else user.created_at.isoformat(),
                "updated_at": subscription.updated_at.isoformat() if subscription and subscription.updated_at else user.updated_at.isoformat(),
                "editable": subscription is None or subscription.provider == "manual",
            })
    return result
 
 
@router.get("/subscriptions/events")
def list_subscription_events(_: CurrentAdmin, db: DBSession, limit: int = 200) -> List[Dict[str, Any]]:
    rows = (
        db.query(SubscriptionEvent)
        .order_by(SubscriptionEvent.created_at.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "id": e.id,
            "user_id": e.user_id,
            "provider": e.provider,
            "type": e.type,
            "payload": e.payload,
            "created_at": e.created_at.isoformat() if e.created_at else None,
        }
        for e in rows
    ]
 
 
@router.post("/users/{user_id}/subscription")
def set_user_subscription(user_id: str, payload: AdminSubscriptionUpdate, db: DBSession, admin: CurrentAdmin) -> Dict[str, Any]:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    now = datetime.now(timezone.utc)
    before = {
        "status": user.subscription_status,
        "expire_at": user.subscription_expire_at.isoformat() if user.subscription_expire_at else None,
    }
    manual = (
        db.query(Subscription)
        .filter(Subscription.user_id == user.id, Subscription.provider == "manual")
        .one_or_none()
    )
    if manual is None:
        manual = Subscription(user_id=user.id, provider="manual", status="canceled")
    if payload.status == "free":
        manual.status = "canceled"
        manual.current_period_end = now
        manual.auto_renew_enabled = False
    else:
        default_days = 30 if payload.status == "trial" or payload.plan == "monthly" else 365
        purchased_at = payload.purchased_at or manual.purchased_at or now
        expire_at = payload.expire_at or (now + timedelta(days=payload.duration_days or default_days))
        if expire_at <= now:
            raise HTTPException(status_code=400, detail="Expiration must be in the future")
        manual.status = "trial" if payload.status == "trial" else "active"
        manual.plan = payload.plan or ("monthly" if payload.status == "trial" else None)
        manual.product_id = "sweezy_plus_manual"
        manual.purchased_at = purchased_at
        manual.current_period_end = expire_at
        manual.auto_renew_enabled = False
        manual.revocation_date = None
        manual.last_verified_at = now
    db.add(manual)
    db.flush()

    valid = db.query(Subscription).filter(
        Subscription.user_id == user.id,
        Subscription.status.in_(["active", "trial"]),
        Subscription.revocation_date.is_(None),
        or_(Subscription.current_period_end.is_(None), Subscription.current_period_end > now),
    ).all()
    user.subscription_status = "premium" if any(row.status == "active" for row in valid) else "trial" if valid else "free"
    expirations = [row.current_period_end for row in valid if row.current_period_end]
    user.subscription_expire_at = max(expirations) if expirations else None
    db.add(user)
    event = SubscriptionEvent(
        user_id=user.id,
        provider="manual",
        type="admin.subscription.updated",
        payload=json.dumps({
            "status": payload.status,
            "plan": payload.plan,
            "expire_at": payload.expire_at.isoformat() if payload.expire_at else None,
            "reason": payload.reason,
            "admin_id": admin.get("sub"),
        }),
    )
    db.add(event)
    db.commit()
    db.refresh(user)
    actor = db.query(User).filter(User.id == admin.get("sub")).first()
    log_audit(
        db,
        user_email=actor.email if actor else f"user:{admin.get('sub', 'unknown')}",
        action="update",
        entity="subscriptions",
        entity_id=user.id,
        before=before,
        after={
            "status": user.subscription_status,
            "expire_at": user.subscription_expire_at.isoformat() if user.subscription_expire_at else None,
            "reason": payload.reason,
        },
    )
    return {
        "ok": True,
        "status": user.subscription_status,
        "expire_at": user.subscription_expire_at.isoformat() if user.subscription_expire_at else None,
    }

@router.get("/subscriptions/analytics")
def subscriptions_analytics(_: CurrentAdmin, db: DBSession, months: int = 6) -> Dict[str, Any]:
    # Totals by plan
    monthly = db.query(func.count()).select_from(Subscription).filter(Subscription.status == "active", Subscription.plan == "monthly").scalar() or 0
    yearly = db.query(func.count()).select_from(Subscription).filter(Subscription.status == "active", Subscription.plan == "yearly").scalar() or 0
    premium_users = db.query(func.count()).select_from(User).filter(User.subscription_status == "premium").scalar() or 0
    trial_users = db.query(func.count()).select_from(User).filter(User.subscription_status == "trial").scalar() or 0
    free_users = db.query(func.count()).select_from(User).filter(User.subscription_status == "free").scalar() or 0
    # Last 6 months time series
    rows = (
        db.query(
            func.date_trunc("month", Subscription.created_at).label("m"),
            func.sum(func.case((Subscription.plan == "monthly", 1), else_=0)).label("monthly"),
            func.sum(func.case((Subscription.plan == "yearly", 1), else_=0)).label("yearly"),
        )
        .filter(Subscription.status == "active")
        .group_by(func.date_trunc("month", Subscription.created_at))
        .order_by(func.date_trunc("month", Subscription.created_at).desc())
        .limit(max(1, min(24, months)))
        .all()
    )
    series = [
        {"month": r[0].strftime("%Y-%m"), "monthly": int(r[1] or 0), "yearly": int(r[2] or 0)}
        for r in reversed(rows)
    ]
    return {
        "totals": {
            "monthly": int(monthly),
            "yearly": int(yearly),
            "premium_users": int(premium_users),
            "trial_users": int(trial_users),
            "free_users": int(free_users),
        },
        "by_month": series,
    }

@router.get("/paywall/funnel")
def paywall_funnel(_: CurrentAdmin, db: DBSession, days: int = 30) -> Dict[str, Any]:
    """
    Returns counts for paywall events over the last N days.
    """
    from datetime import datetime, timedelta, timezone
    since = datetime.now(timezone.utc) - timedelta(days=max(1, min(365, days)))
    rows = (
        db.query(PaywallEvent.event_type, func.count().label("cnt"))
        .filter(PaywallEvent.created_at >= since)
        .group_by(PaywallEvent.event_type)
        .all()
    )
    by_type = {r[0]: int(r[1]) for r in rows}
    contexts = (
        db.query(PaywallEvent.context, func.count().label("cnt"))
        .filter(PaywallEvent.created_at >= since)
        .group_by(PaywallEvent.context)
        .order_by(func.count().desc())
        .limit(10)
        .all()
    )
    top_contexts = [{"context": r[0] or "none", "count": int(r[1])} for r in contexts]
    return {"by_type": by_type, "top_contexts": top_contexts, "since": since.isoformat()}

@router.post("/import/news/rss")
def import_news_rss(payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    """
    Import news items from an RSS/Atom feed.
    Body:
      - feed_url: str
      - language: str = 'uk'
      - status: 'draft'|'published' = 'draft'
      - max_items: int = 50
      - download_images: bool = True
      - extract_full: bool = False (reserved)
    """
    feed_url = payload.get("feed_url")
    if not feed_url:
        return {"created": 0, "updated": 0, "skipped": 0, "error": "feed_url is required"}
    language = payload.get("language", "uk")
    status = payload.get("status", "draft")
    max_items = int(payload.get("max_items", 50))
    download_images = bool(payload.get("download_images", True))
    try:
        return RSSImporter.import_from_url(
            db, str(feed_url), language=str(language), status=str(status),
            max_items=max(1, min(max_items, 100)), download_images=download_images,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    # Fetch feed with proper headers (some hosts block default user agents)
    client = httpx.Client(timeout=10, follow_redirects=True, headers={
        "User-Agent": "SweezyRSS/1.0 (+https://sweezy-9xyk.onrender.com)"
    })
    try:
        resp = client.get(feed_url)
        text = resp.text if resp.status_code < 400 else ""
    except Exception:
        text = ""
    parsed = feedparser.parse(text or feed_url)
    # If no entries, try to discover <link rel="alternate" type="application/rss+xml|atom+xml">
    if not getattr(parsed, "entries", None):
        try:
            html = text or ""
            if not html:
                html = client.get(feed_url).text
            import re as _re
            m = _re.search(r'<link[^>]+type="application/(?:rss|atom)\+xml"[^>]+href="([^"]+)"', html, flags=_re.I)
            if m:
                feed_href = m.group(1)
                feed_abs = urljoin(feed_url, feed_href)
                text2 = client.get(feed_abs).text
                parsed = feedparser.parse(text2)
        except Exception:
            pass
    created = updated = skipped = 0
    src = parsed.feed.get("title") or (urlparse(feed_url).hostname or "RSS")

    # If still no entries — treat the URL as single article page and import via OpenGraph
    if not getattr(parsed, "entries", None):
        try:
            html = text or client.get(feed_url).text
            import re as _re
            def meta(prop=None, name=None):
                if prop:
                    m = _re.search(rf'<meta[^>]+property=["\']{_re.escape(prop)}["\'][^>]*content=["\']([^"\']+)["\']', html, flags=_re.I)
                    if m:
                        return m.group(1)
                if name:
                    m = _re.search(rf'<meta[^>]+name=["\']{_re.escape(name)}["\'][^>]*content=["\']([^"\']+)["\']', html, flags=_re.I)
                    if m:
                        return m.group(1)
                return None
            title = meta(prop="og:title") or meta(name="title")
            if not title:
                mtitle = _re.search(r'<title[^>]*>(.*?)</title>', html, flags=_re.I|_re.S)
                title = (mtitle.group(1).strip() if mtitle else "Untitled")
            desc = meta(prop="og:description") or meta(name="description") or ""
            img = meta(prop="og:image") or meta(name="image")
            pub = meta(prop="article:published_time") or meta(name="article:published_time")
            pub_dt = datetime.utcnow()
            try:
                # try ISO-8601 (trim timezone if necessary)
                p = pub.replace("Z","").split("+")[0] if pub else ""
                if p:
                    pub_dt = datetime.fromisoformat(p)
            except Exception:
                pass
            image_url = None
            if img:
                image_url = img
                if download_images:
                    try:
                        r = client.get(urljoin(feed_url, img))
                        if r.status_code == 200:
                            name = f"{__import__('uuid').uuid4()}.jpg"
                            (UPLOAD_DIR / name).write_bytes(r.content)
                            image_url = f"/media/{name}"
                    except Exception:
                        pass
            data = {
                "title": title.strip(),
                "summary": desc.strip(),
                "content": None,
                "url": feed_url,
                "source": src,
                "language": language,
                "status": status,
                "published_at": pub_dt,
                "image_url": image_url,
            }
            existing = db.query(News).filter(News.url == feed_url).first()
            from ..services.news_service import NewsService as _NS
            if existing:
                _NS.update(db, existing, **data)
                updated += 1
            else:
                _NS.create(db, **data)
                created += 1
        except Exception:
            skipped += 1
            client.close()
            return {"created": created, "updated": updated, "skipped": skipped}

    for entry in getattr(parsed, "entries", [])[:max_items]:
        try:
            url = entry.get("link")
            if not url:
                skipped += 1
                continue
            existing = db.query(News).filter(News.url == url).first()
            title = (entry.get("title") or "Untitled").strip()
            summary = entry.get("summary") or entry.get("description") or ""
            # published
            pub_dt = datetime.utcnow()
            if entry.get("published_parsed"):
                pub_dt = datetime.fromtimestamp(time.mktime(entry.published_parsed))
            # image
            image_url = None
            media = entry.get("media_content") or entry.get("enclosures") or []
            if isinstance(media, list) and media:
                m0 = media[0]
                if isinstance(m0, dict):
                    image_url = m0.get("url")
            if not image_url and isinstance(summary, str):
                import re as _re
                m = _re.search(r'<img[^>]+src="([^"]+)"', summary)
                if m:
                    image_url = m.group(1)
            # optionally download image
            if download_images and image_url:
                try:
                    r = client.get(image_url)
                    if r.status_code == 200:
                        ext = ".jpg"
                        name = f"{__import__('uuid').uuid4()}{ext}"
                        (UPLOAD_DIR / name).write_bytes(r.content)
                        image_url = f"/media/{name}"
                except Exception:
                    pass

            data = {
                "title": title,
                "summary": summary,
                "content": None,
                "url": url,
                "source": src,
                "language": language,
                "status": status,
                "published_at": pub_dt,
                "image_url": image_url,
            }
            if existing:
                from ..services.news_service import NewsService as _NS
                _NS.update(db, existing, **data)
                updated += 1
            else:
                from ..services.news_service import NewsService as _NS
                _NS.create(db, **data)
                created += 1
        except Exception:
            skipped += 1
            continue
    client.close()
    return {"created": created, "updated": updated, "skipped": skipped}


@router.post("/import/news")
def import_news(payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    items = payload.get("items") or []
    created = 0
    for raw in items:
        try:
            title = raw.get("title") or "Untitled"
            summary = raw.get("summary") or ""
            url = raw.get("url") or ""
            source = raw.get("source") or "Sweezy"
            language = raw.get("language") or "uk"
            published_at = raw.get("published_at") or raw.get("date") or None
            image_url = raw.get("image_url")
            if not url:
                continue
            obj = News(
                id=str(__import__("uuid").uuid4()),
                title=title,
                summary=summary,
                url=url,
                source=source,
                language=language,
                published_at=__import__("datetime").datetime.fromisoformat(published_at) if isinstance(published_at, str) else (__import__("datetime").datetime.utcnow()),
                image_url=image_url,
            )
            db.add(obj)
            created += 1
        except Exception:
            continue
    db.commit()
    return {"created": created}

@router.get("/rss-feeds")
def list_rss_feeds(_: CurrentAdmin, db: DBSession) -> List[Dict[str, Any]]:
    rows = db.query(RSSFeed).order_by(RSSFeed.created_at.desc()).all()
    return [{
        "id": r.id,
        "url": r.url,
        "language": r.language,
        "status": r.status,
        "enabled": bool(r.enabled),
        "max_items": r.max_items,
        "download_images": bool(r.download_images),
        "last_imported_at": r.last_imported_at.isoformat() if r.last_imported_at else None,
    } for r in rows]

@router.post("/rss-feeds")
def create_rss_feed(payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    try:
        validate_public_http_url(str(payload.get("url") or ""))
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    r = RSSFeed(
        id=str(__import__("uuid").uuid4()),
        url=payload["url"],
        language=payload.get("language", "uk"),
        status=payload.get("status", "draft"),
        enabled=bool(payload.get("enabled", True)),
        max_items=int(payload.get("max_items", 20)),
        download_images=bool(payload.get("download_images", True)),
        created_at=__import__("datetime").datetime.utcnow(),
        updated_at=__import__("datetime").datetime.utcnow(),
    )
    db.add(r)
    db.commit()
    return {"id": r.id}

@router.delete("/rss-feeds/{feed_id}")
def delete_rss_feed(feed_id: str, db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    r = db.query(RSSFeed).filter(RSSFeed.id == feed_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Not found")
    db.delete(r)
    db.commit()
    return {"ok": True}

@router.post("/rss-feeds/{feed_id}/import")
def run_rss_feed_import(feed_id: str, db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    r = db.query(RSSFeed).filter(RSSFeed.id == feed_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Not found")
    return RSSImporter.import_feed_record(db, r)

@router.patch("/rss-feeds/{feed_id}")
def update_rss_feed(feed_id: str, payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    r = db.query(RSSFeed).filter(RSSFeed.id == feed_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Not found")
    if payload.get("url") is not None:
        try:
            validate_public_http_url(str(payload["url"]))
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
    for k in ["url","language","status"]:
        if k in payload and payload[k] is not None:
            setattr(r, k, payload[k])
    if "enabled" in payload:
        r.enabled = bool(payload["enabled"])
    if "max_items" in payload:
        r.max_items = int(payload["max_items"])
    if "download_images" in payload:
        r.download_images = bool(payload["download_images"])
    r.updated_at = __import__("datetime").datetime.utcnow()
    db.add(r)
    db.commit()
    return {"ok": True}


@router.get("/brave-news/queries")
def list_brave_news_queries(_: CurrentAdmin, db: DBSession) -> List[Dict[str, Any]]:
    rows = db.query(BraveNewsQuery).order_by(BraveNewsQuery.created_at.desc()).all()
    return [{
        "id": row.id,
        "query": row.query,
        "language": row.language,
        "country": row.country,
        "status": row.status,
        "enabled": bool(row.enabled),
        "max_results": row.max_results,
        "freshness_days": row.freshness_days,
        "last_imported_at": row.last_imported_at.isoformat() if row.last_imported_at else None,
        "created_at": row.created_at.isoformat() if row.created_at else None,
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    } for row in rows]


@router.post("/brave-news/queries")
def create_brave_news_query(payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    query = str(payload.get("query") or "").strip()
    if not query:
        raise HTTPException(status_code=400, detail="query is required")

    row = BraveNewsQuery(
        id=str(__import__("uuid").uuid4()),
        query=query,
        language=str(payload.get("language") or "uk"),
        country=(str(payload["country"]).strip().upper() if payload.get("country") else None),
        status=str(payload.get("status") or "published"),
        enabled=bool(payload.get("enabled", True)),
        max_results=max(1, min(int(payload.get("max_results", 8)), 10)),
        freshness_days=max(1, min(int(payload.get("freshness_days", 7)), 365)),
        created_at=__import__("datetime").datetime.utcnow(),
        updated_at=__import__("datetime").datetime.utcnow(),
    )
    db.add(row)
    db.commit()
    return {"id": row.id}


@router.patch("/brave-news/queries/{query_id}")
def update_brave_news_query(query_id: str, payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    row = db.query(BraveNewsQuery).filter(BraveNewsQuery.id == query_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Not found")

    if "query" in payload and payload["query"] is not None:
        row.query = str(payload["query"]).strip()
    if "language" in payload and payload["language"] is not None:
        row.language = str(payload["language"])
    if "country" in payload:
        row.country = (str(payload["country"]).strip().upper() or None) if payload["country"] is not None else None
    if "status" in payload and payload["status"] is not None:
        row.status = str(payload["status"])
    if "enabled" in payload:
        row.enabled = bool(payload["enabled"])
    if "max_results" in payload and payload["max_results"] is not None:
        row.max_results = max(1, min(int(payload["max_results"]), 10))
    if "freshness_days" in payload and payload["freshness_days"] is not None:
        row.freshness_days = max(1, min(int(payload["freshness_days"]), 365))
    row.updated_at = __import__("datetime").datetime.utcnow()
    db.add(row)
    db.commit()
    return {"ok": True}


@router.delete("/brave-news/queries/{query_id}")
def delete_brave_news_query(query_id: str, db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    row = db.query(BraveNewsQuery).filter(BraveNewsQuery.id == query_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Not found")
    db.delete(row)
    db.commit()
    return {"ok": True}


@router.post("/brave-news/queries/{query_id}/run")
def run_brave_news_query(query_id: str, db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    row = db.query(BraveNewsQuery).filter(BraveNewsQuery.id == query_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Not found")
    try:
        return BraveSearchImporter.import_query(db, row)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/brave-news/run-all")
def run_all_brave_news_queries(db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    try:
        return BraveSearchImporter.import_enabled_queries(db)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.post("/import/templates")
def import_templates(payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    items = payload.get("items") or []
    created = 0
    for raw in items:
        try:
            try:
                data = TemplateCreate(**raw)
                name = data.name
                category = data.category
                content = data.content
            except Exception:
                name = raw.get("name") or raw.get("title") or "Untitled"
                category = raw.get("category") or "general"
                content = raw.get("content") or ""
            obj = Template(name=name, category=category, content=content)
            db.add(obj)
            created += 1
        except Exception:
            continue
    db.commit()
    return {"created": created}


@router.post("/import/checklists")
def import_checklists(payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    items = payload.get("items") or []
    created = 0
    for raw in items:
        try:
            try:
                data = ChecklistCreate(**raw)
                title = data.title
                description = data.description
                items_list = data.items
                is_published = data.is_published
            except Exception:
                title = raw.get("title") or "Checklist"
                description = raw.get("description") or ""
                # iOS shape: steps: [{ title: ... }]
                if isinstance(raw.get("steps"), list):
                    items_list = [str(step.get("title") or step.get("description") or "Step") for step in raw.get("steps", [])]
                else:
                    items_list = raw.get("items") or []
                is_published = bool(raw.get("is_published", True))
            obj = Checklist(title=title, description=description, items=items_list, is_published=is_published)
            db.add(obj)
            created += 1
        except Exception:
            continue
    db.commit()
    return {"created": created}
