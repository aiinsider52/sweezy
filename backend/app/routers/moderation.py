from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field, model_validator
from sqlalchemy import func, or_, select

from ..dependencies import CurrentAdmin, CurrentUser, DBSession
from ..models.chat import ChatMessage, ChatMessageReport
from ..models.discovery_review import DiscoveryReview, DiscoveryReviewReport
from ..models.event_listing import EventListing, EventReport
from ..models.job import Job, JobReport
from ..models.marketplace import MarketplaceReport, ServiceListing
from ..models.moderation import ModerationAction, ModerationCase, ModerationNotification, UserSanction
from ..models.network import ProfessionalProfile, ProfessionalProfileReport
from ..models.social import SocialProfile, SocialProfileReport
from ..models.user import User
from ..services.moderation import backfill_legacy_cases, notify_user, serialize_case, utcnow


router = APIRouter()
admin_router = APIRouter()


class ModerationDecision(BaseModel):
    action: Literal["approve", "reject", "dismiss", "warn", "hide", "suspend", "ban"]
    comment: str = Field(min_length=3, max_length=1000)
    suspension_days: int | None = Field(default=None, ge=1, le=365)

    @model_validator(mode="after")
    def validate_duration(self):
        if self.action == "suspend" and self.suspension_days is None:
            raise ValueError("suspension_days is required for suspend")
        return self


class CaseUpdate(BaseModel):
    status: Literal["open", "reviewing"]
    priority: Literal["low", "normal", "high", "critical"] | None = None


def _hide_source(db: DBSession, case: ModerationCase) -> None:
    if case.source_type == "social_profile":
        profile = db.get(SocialProfile, case.source_id)
        if profile: profile.is_visible = False
    elif case.source_type == "professional_profile":
        profile = db.get(ProfessionalProfile, case.source_id)
        if profile: profile.is_visible = False
    elif case.source_type == "marketplace_listing":
        listing = db.get(ServiceListing, case.source_id)
        if listing: listing.status = "rejected"; listing.rejection_reason = "Hidden after safety review"
    elif case.source_type == "event":
        event = db.get(EventListing, case.source_id)
        if event: event.status = "rejected"; event.rejection_reason = "Hidden after safety review"
    elif case.source_type == "chat_message":
        message = db.get(ChatMessage, case.source_id)
        if message: message.deleted_at = utcnow(); message.body = ""
    elif case.source_type == "job":
        job = db.get(Job, case.source_id)
        if job: job.status = "hidden"; job.moderation_notes = "Hidden after safety review"
    elif case.source_type == "discovery_review":
        review = db.get(DiscoveryReview, case.source_id)
        if review: review.status = "hidden"


def _sync_legacy_report(db: DBSession, case: ModerationCase, status: str) -> None:
    models = {
        "social_profile": SocialProfileReport,
        "professional_profile": ProfessionalProfileReport,
        "marketplace_listing": MarketplaceReport,
        "event": EventReport,
        "chat_message": ChatMessageReport,
        "job": JobReport,
        "discovery_review": DiscoveryReviewReport,
    }
    model = models.get(case.source_type)
    legacy_report_id = case.context_json.get("legacy_report_id")
    if model and legacy_report_id:
        row = db.get(model, legacy_report_id)
        if row and hasattr(row, "status"):
            row.status = status


def _case_or_404(db: DBSession, case_id: str) -> ModerationCase:
    case = db.get(ModerationCase, case_id)
    if not case: raise HTTPException(status_code=404, detail="Moderation case not found")
    return case


@admin_router.get("/reports-safety")
def cases(
    db: DBSession,
    _: CurrentAdmin,
    status: str | None = Query(default=None, pattern="^(open|reviewing|resolved|dismissed)$"),
    source_type: str | None = None,
    priority: str | None = Query(default=None, pattern="^(low|normal|high|critical)$"),
    subject_user_id: str | None = None,
    search: str | None = Query(default=None, max_length=120),
    limit: int = Query(default=100, ge=1, le=500),
):
    backfill_legacy_cases(db)
    query = select(ModerationCase)
    if status: query = query.where(ModerationCase.status == status)
    if source_type: query = query.where(ModerationCase.source_type == source_type)
    if priority: query = query.where(ModerationCase.priority == priority)
    if subject_user_id: query = query.where(ModerationCase.subject_user_id == subject_user_id)
    if search:
        term = f"%{search.strip()}%"
        query = query.outerjoin(User, User.id == ModerationCase.subject_user_id).where(
            or_(ModerationCase.reason.ilike(term), ModerationCase.details.ilike(term), User.email.ilike(term))
        )
    order = {"critical": 0, "high": 1, "normal": 2, "low": 3}
    rows = db.scalars(query.order_by(ModerationCase.created_at.desc()).limit(limit)).all()
    return [serialize_case(db, row) for row in sorted(rows, key=lambda row: order.get(row.priority, 2))]


@admin_router.get("/reports-safety/stats")
def stats(db: DBSession, _: CurrentAdmin):
    backfill_legacy_cases(db)
    return {
        "open": db.scalar(select(func.count()).select_from(ModerationCase).where(ModerationCase.status == "open")) or 0,
        "reviewing": db.scalar(select(func.count()).select_from(ModerationCase).where(ModerationCase.status == "reviewing")) or 0,
        "suspended": db.scalar(select(func.count()).select_from(User).where(User.safety_status == "suspended")) or 0,
        "banned": db.scalar(select(func.count()).select_from(User).where(User.safety_status == "banned")) or 0,
    }


@admin_router.patch("/reports-safety/{case_id}")
def update_case(case_id: str, payload: CaseUpdate, db: DBSession, admin: CurrentAdmin):
    case = _case_or_404(db, case_id)
    if case.status in {"resolved", "dismissed"}:
        raise HTTPException(status_code=409, detail="Closed case cannot return to queue")
    case.status = payload.status
    case.assigned_to = admin.get("sub") if payload.status == "reviewing" else None
    if payload.priority: case.priority = payload.priority
    db.add(ModerationAction(case_id=case.id, subject_user_id=case.subject_user_id, moderator_id=admin.get("sub"), action="case_update", comment=f"Status changed to {payload.status}", metadata_json={"priority": case.priority}))
    db.commit(); db.refresh(case)
    return serialize_case(db, case)


@admin_router.post("/reports-safety/{case_id}/decision")
def decide(case_id: str, payload: ModerationDecision, db: DBSession, admin: CurrentAdmin):
    case = _case_or_404(db, case_id)
    if case.status in {"resolved", "dismissed"}:
        raise HTTPException(status_code=409, detail="Case already closed")
    user = db.get(User, case.subject_user_id) if case.subject_user_id else None
    if user and user.is_superuser and payload.action in {"warn", "hide", "suspend", "ban", "reject"}:
        raise HTTPException(status_code=403, detail="Superuser safety status cannot be changed here")
    if payload.action in {"warn", "suspend", "ban"} and not user:
        raise HTTPException(status_code=400, detail="Case has no account subject")
    profile_review = case.source_type in {"social_profile_review", "professional_profile_review"}
    if payload.action in {"approve", "reject"} and not profile_review:
        raise HTTPException(status_code=400, detail="Approve/reject only apply to profile review cases")
    if profile_review and payload.action not in {"approve", "reject", "suspend", "ban"}:
        raise HTTPException(status_code=400, detail="Profile review requires approve or reject")

    now = utcnow()
    sanction = None
    if payload.action == "approve":
        profile = db.get(SocialProfile if case.source_type == "social_profile_review" else ProfessionalProfile, case.source_id)
        if not profile: raise HTTPException(status_code=404, detail="Profile not found")
        profile.moderation_status = "approved"; profile.moderation_reason = payload.comment; profile.moderated_at = now; profile.moderated_by = admin.get("sub")
    elif payload.action == "reject":
        profile = db.get(SocialProfile if case.source_type == "social_profile_review" else ProfessionalProfile, case.source_id)
        if not profile: raise HTTPException(status_code=404, detail="Profile not found")
        profile.moderation_status = "rejected"; profile.moderation_reason = payload.comment; profile.moderated_at = now; profile.moderated_by = admin.get("sub")
    elif payload.action == "warn":
        sanction = UserSanction(user_id=user.id, case_id=case.id, action="warn", strike_points=1, reason=payload.comment, created_by=admin.get("sub"))
        user.safety_strike_count += 1
    elif payload.action == "hide":
        _hide_source(db, case)
        if user:
            sanction = UserSanction(user_id=user.id, case_id=case.id, action="hide", strike_points=1, reason=payload.comment, created_by=admin.get("sub"))
            user.safety_strike_count += 1
    elif payload.action == "suspend":
        expires = now + timedelta(days=payload.suspension_days or 1)
        sanction = UserSanction(user_id=user.id, case_id=case.id, action="suspend", strike_points=2, reason=payload.comment, expires_at=expires, created_by=admin.get("sub"))
        user.safety_status = "suspended"; user.safety_suspended_until = expires; user.safety_strike_count += 2
    elif payload.action == "ban":
        sanction = UserSanction(user_id=user.id, case_id=case.id, action="ban", strike_points=3, reason=payload.comment, created_by=admin.get("sub"))
        user.safety_status = "banned"; user.safety_suspended_until = None; user.safety_strike_count += 3

    if sanction: db.add(sanction)
    case.status = "dismissed" if payload.action == "dismiss" else "resolved"
    case.decision = payload.action
    case.moderator_comment = payload.comment
    case.assigned_to = admin.get("sub")
    case.resolved_at = now
    _sync_legacy_report(db, case, case.status)
    db.add(ModerationAction(case_id=case.id, subject_user_id=case.subject_user_id, moderator_id=admin.get("sub"), action=payload.action, comment=payload.comment, metadata_json={"suspension_days": payload.suspension_days}))
    if user and payload.action != "dismiss":
        titles = {"approve": "Profile approved", "reject": "Profile needs changes", "dismiss": "Report review completed", "warn": "Account warning", "hide": "Content hidden", "suspend": "Account temporarily suspended", "ban": "Account blocked"}
        notify_user(db, user_id=user.id, case_id=case.id, kind=payload.action, title=titles[payload.action], body=payload.comment, event_key=f"moderation:decision:{case.id}")
    if case.reporter_id:
        notify_user(db, user_id=case.reporter_id, case_id=case.id, kind="report_result", title="Report reviewed", body="Thank you. Moderation completed review of your report.", event_key=f"moderation:reporter:{case.id}")
    db.commit(); db.refresh(case)
    return serialize_case(db, case)


@admin_router.get("/reports-safety/users/{user_id}/history")
def user_history(user_id: str, db: DBSession, _: CurrentAdmin):
    user = db.get(User, user_id)
    if not user: raise HTTPException(status_code=404, detail="User not found")
    cases = db.scalars(select(ModerationCase).where(ModerationCase.subject_user_id == user_id).order_by(ModerationCase.created_at.desc())).all()
    sanctions = db.scalars(select(UserSanction).where(UserSanction.user_id == user_id).order_by(UserSanction.created_at.desc())).all()
    return {"user": {"id": user.id, "email": user.email, "safety_status": user.safety_status, "strike_count": user.safety_strike_count, "suspended_until": user.safety_suspended_until}, "cases": [serialize_case(db, row) for row in cases], "sanctions": [{"id": row.id, "action": row.action, "status": row.status, "reason": row.reason, "strike_points": row.strike_points, "expires_at": row.expires_at, "created_at": row.created_at} for row in sanctions]}


@admin_router.post("/reports-safety/sanctions/{sanction_id}/revoke")
def revoke(sanction_id: str, payload: ModerationDecision, db: DBSession, admin: CurrentAdmin):
    sanction = db.get(UserSanction, sanction_id)
    if not sanction: raise HTTPException(status_code=404, detail="Sanction not found")
    if sanction.status != "active": raise HTTPException(status_code=409, detail="Sanction is not active")
    if payload.action != "dismiss": raise HTTPException(status_code=400, detail="Use dismiss to revoke")
    sanction.status = "revoked"; sanction.revoked_at = utcnow(); sanction.revoked_by = admin.get("sub"); sanction.revoke_reason = payload.comment
    user = db.get(User, sanction.user_id)
    if user and sanction.action in {"suspend", "ban"}:
        other_ban = db.scalar(select(UserSanction.id).where(UserSanction.user_id == user.id, UserSanction.id != sanction.id, UserSanction.action == "ban", UserSanction.status == "active").limit(1))
        other_suspend = db.scalar(select(UserSanction).where(UserSanction.user_id == user.id, UserSanction.id != sanction.id, UserSanction.action == "suspend", UserSanction.status == "active", UserSanction.expires_at > utcnow()).order_by(UserSanction.expires_at.desc()).limit(1))
        if other_ban:
            user.safety_status = "banned"; user.safety_suspended_until = None
        elif other_suspend:
            user.safety_status = "suspended"; user.safety_suspended_until = other_suspend.expires_at
        else:
            user.safety_status = "active"; user.safety_suspended_until = None
    if sanction.case_id:
        db.add(ModerationAction(case_id=sanction.case_id, subject_user_id=sanction.user_id, moderator_id=admin.get("sub"), action="revoke", comment=payload.comment, metadata_json={"sanction_id": sanction.id}))
    notify_user(db, user_id=sanction.user_id, case_id=sanction.case_id, kind="sanction_revoked", title="Account restriction removed", body=payload.comment, event_key=f"moderation:revoke:{sanction.id}")
    db.commit()
    return {"ok": True}


@router.get("/moderation/notifications")
def notifications(db: DBSession, user: CurrentUser, unread_only: bool = False):
    query = select(ModerationNotification).where(ModerationNotification.user_id == user.id)
    if unread_only: query = query.where(ModerationNotification.read_at.is_(None))
    rows = db.scalars(query.order_by(ModerationNotification.created_at.desc()).limit(100)).all()
    return [{"id": row.id, "kind": row.kind, "title": row.title, "body": row.body, "read_at": row.read_at, "created_at": row.created_at} for row in rows]


@router.patch("/moderation/notifications/{notification_id}/read")
def read_notification(notification_id: str, db: DBSession, user: CurrentUser):
    row = db.get(ModerationNotification, notification_id)
    if not row or row.user_id != user.id: raise HTTPException(status_code=404, detail="Notification not found")
    row.read_at = datetime.now(timezone.utc); db.commit()
    return {"ok": True}
