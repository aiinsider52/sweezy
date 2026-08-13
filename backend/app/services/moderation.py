from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy import func, select

from ..models.chat import NotificationOutbox
from ..models.moderation import ModerationAction, ModerationCase, ModerationNotification, UserSanction
from ..models.user import User


AUTO_SUSPEND_UNIQUE_REPORTERS = 5
AUTO_SUSPEND_WINDOW_HOURS = 24
AUTO_SUSPEND_HOURS = 24
HIGH_RISK_REASONS = {"fraud", "harassment", "unsafe", "threat", "scam"}


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def ensure_case(
    db,
    *,
    source_type: str,
    source_id: str,
    subject_user_id: str | None,
    reporter_id: str | None,
    reason: str,
    details: str | None = None,
    context: dict[str, Any] | None = None,
    source_key: str | None = None,
    priority: str | None = None,
) -> ModerationCase:
    key = source_key or f"{source_type}:{source_id}:{reporter_id or 'system'}"
    existing = db.scalar(select(ModerationCase).where(ModerationCase.source_key == key))
    if existing:
        return existing
    normalized_reason = reason.strip().lower()[:40]
    case = ModerationCase(
        source_key=key,
        source_type=source_type,
        source_id=str(source_id),
        subject_user_id=subject_user_id,
        reporter_id=reporter_id,
        reason=normalized_reason,
        details=details.strip() if details else None,
        priority=priority or ("high" if normalized_reason in HIGH_RISK_REASONS else "normal"),
        context_json=context or {},
    )
    db.add(case)
    db.flush()
    if subject_user_id and reporter_id and normalized_reason in HIGH_RISK_REASONS:
        _auto_suspend_if_needed(db, subject_user_id, case)
    return case


def ensure_profile_review_case(db, *, kind: str, user_id: str, context: dict[str, Any]) -> ModerationCase:
    case = ensure_case(
        db,
        source_type=f"{kind}_profile_review",
        source_id=user_id,
        subject_user_id=user_id,
        reporter_id=None,
        reason="profile_review",
        context=context,
        source_key=f"{kind}_profile_review:{user_id}",
    )
    if case.status in {"resolved", "dismissed"}:
        case.status = "open"
        case.decision = None
        case.moderator_comment = None
        case.resolved_at = None
        case.assigned_to = None
    case.context_json = context
    return case


def _auto_suspend_if_needed(db, user_id: str, trigger_case: ModerationCase) -> None:
    target = db.get(User, user_id)
    if not target or target.is_superuser:
        return
    cutoff = utcnow() - timedelta(hours=AUTO_SUSPEND_WINDOW_HOURS)
    reporter_count = db.scalar(
        select(func.count(func.distinct(ModerationCase.reporter_id))).where(
            ModerationCase.subject_user_id == user_id,
            ModerationCase.reporter_id.is_not(None),
            ModerationCase.reason.in_(HIGH_RISK_REASONS),
            ModerationCase.status.in_(("open", "reviewing")),
            ModerationCase.created_at >= cutoff,
        )
    ) or 0
    if reporter_count < AUTO_SUSPEND_UNIQUE_REPORTERS:
        return
    active = db.scalar(
        select(UserSanction).where(
            UserSanction.user_id == user_id,
            UserSanction.action == "suspend",
            UserSanction.status == "active",
            UserSanction.expires_at > utcnow(),
        ).limit(1)
    )
    if active:
        return
    expires_at = utcnow() + timedelta(hours=AUTO_SUSPEND_HOURS)
    reason = f"Automatic safety hold after {reporter_count} unique high-risk reports"
    sanction = UserSanction(
        user_id=user_id,
        case_id=trigger_case.id,
        action="suspend",
        strike_points=1,
        reason=reason,
        expires_at=expires_at,
    )
    db.add(sanction)
    db.flush()
    user = db.get(User, user_id)
    if user:
        user.safety_status = "suspended"
        user.safety_suspended_until = expires_at
        user.safety_strike_count += 1
    db.add(
        ModerationAction(
            case_id=trigger_case.id,
            subject_user_id=user_id,
            moderator_id=None,
            action="auto_suspend",
            comment=reason,
            metadata_json={"expires_at": expires_at.isoformat(), "unique_reporters": reporter_count},
        )
    )
    notify_user(
        db,
        user_id=user_id,
        case_id=trigger_case.id,
        kind="suspended",
        title="Account temporarily restricted",
        body=f"Access is restricted while safety reports are reviewed. Restriction ends {expires_at:%Y-%m-%d %H:%M UTC}.",
        event_key=f"moderation:auto_suspend:{sanction.id}",
    )


def refresh_safety_state(db, user: User) -> None:
    now = utcnow()
    until = user.safety_suspended_until
    if until is not None and until.tzinfo is None:
        until = until.replace(tzinfo=timezone.utc)
    if user.safety_status == "suspended" and until and until <= now:
        sanctions = db.scalars(
            select(UserSanction).where(
                UserSanction.user_id == user.id,
                UserSanction.action == "suspend",
                UserSanction.status == "active",
                UserSanction.expires_at <= now,
            )
        ).all()
        for sanction in sanctions:
            sanction.status = "expired"
        user.safety_status = "active"
        user.safety_suspended_until = None
        db.commit()


def notify_user(
    db,
    *,
    user_id: str,
    case_id: str | None,
    kind: str,
    title: str,
    body: str,
    event_key: str,
) -> None:
    if db.scalar(select(ModerationNotification.id).where(ModerationNotification.event_key == event_key)):
        return
    db.add(
        ModerationNotification(
            event_key=event_key,
            user_id=user_id,
            case_id=case_id,
            kind=kind,
            title=title,
            body=body,
        )
    )
    from ..core.config import get_settings
    if not get_settings().PUSH_NOTIFICATIONS_ENABLED:
        return
    payload = {
        "aps": {"alert": {"title": title[:80], "body": body[:180]}, "sound": "default"},
        "type": "moderation",
        "case_id": case_id,
        "kind": kind,
    }
    db.add(
        NotificationOutbox(
            event_key=f"push:{event_key}",
            recipient_id=user_id,
            event_type="moderation",
            payload_json=json.dumps(payload, ensure_ascii=False),
        )
    )


def serialize_case(db, case: ModerationCase) -> dict[str, Any]:
    subject = db.get(User, case.subject_user_id) if case.subject_user_id else None
    reporter = db.get(User, case.reporter_id) if case.reporter_id else None
    actions = db.scalars(
        select(ModerationAction).where(ModerationAction.case_id == case.id).order_by(ModerationAction.created_at)
    ).all()
    sanctions = db.scalars(
        select(UserSanction).where(UserSanction.case_id == case.id).order_by(UserSanction.created_at)
    ).all()
    return {
        "id": case.id,
        "source_type": case.source_type,
        "source_id": case.source_id,
        "subject_user_id": case.subject_user_id,
        "subject_email": subject.email if subject else None,
        "subject_safety_status": subject.safety_status if subject else None,
        "subject_strikes": subject.safety_strike_count if subject else 0,
        "reporter_id": case.reporter_id,
        "reporter_email": reporter.email if reporter else None,
        "reason": case.reason,
        "details": case.details,
        "status": case.status,
        "priority": case.priority,
        "context": case.context_json,
        "assigned_to": case.assigned_to,
        "decision": case.decision,
        "moderator_comment": case.moderator_comment,
        "resolved_at": case.resolved_at.isoformat() if case.resolved_at else None,
        "created_at": case.created_at.isoformat() if case.created_at else None,
        "updated_at": case.updated_at.isoformat() if case.updated_at else None,
        "actions": [
            {
                "id": row.id,
                "action": row.action,
                "comment": row.comment,
                "moderator_id": row.moderator_id,
                "metadata": row.metadata_json,
                "created_at": row.created_at.isoformat() if row.created_at else None,
            }
            for row in actions
        ],
        "sanctions": [
            {
                "id": row.id,
                "action": row.action,
                "status": row.status,
                "strike_points": row.strike_points,
                "reason": row.reason,
                "expires_at": row.expires_at.isoformat() if row.expires_at else None,
                "created_at": row.created_at.isoformat() if row.created_at else None,
            }
            for row in sanctions
        ],
    }


def backfill_legacy_cases(db) -> int:
    """Idempotently expose pre-existing reports and pending profiles in unified queue."""
    from ..models.chat import ChatMessage, ChatMessageReport
    from ..models.discovery_review import DiscoveryReview, DiscoveryReviewReport
    from ..models.event_listing import EventListing, EventReport
    from ..models.job import Job, JobReport
    from ..models.marketplace import MarketplaceReport, ServiceListing
    from ..models.network import ProfessionalProfile, ProfessionalProfileReport
    from ..models.social import SocialProfile, SocialProfileReport

    before = db.scalar(select(func.count()).select_from(ModerationCase)) or 0
    for profile in db.scalars(select(SocialProfile).where(SocialProfile.moderation_status == "pending")).all():
        ensure_profile_review_case(db, kind="social", user_id=profile.user_id, context={"display_name": profile.display_name, "canton": profile.canton, "city": profile.city, "bio": profile.bio, "avatar_url": profile.avatar_url})
    for profile in db.scalars(select(ProfessionalProfile).where(ProfessionalProfile.moderation_status == "pending")).all():
        ensure_profile_review_case(db, kind="professional", user_id=profile.user_id, context={"display_name": profile.display_name, "headline": profile.headline, "company_name": profile.company_name, "canton": profile.canton, "city": profile.city, "bio": profile.bio, "avatar_url": profile.avatar_url})
    for report in db.scalars(select(SocialProfileReport).where(SocialProfileReport.status == "open")).all():
        ensure_case(db, source_type="social_profile", source_id=report.profile_user_id, subject_user_id=report.profile_user_id, reporter_id=report.reporter_id, reason=report.reason, details=report.details, context={"legacy_report_id": report.id})
    for report in db.scalars(select(ProfessionalProfileReport).where(ProfessionalProfileReport.status == "open")).all():
        ensure_case(db, source_type="professional_profile", source_id=report.profile_user_id, subject_user_id=report.profile_user_id, reporter_id=report.reporter_id, reason=report.reason, details=report.details, context={"legacy_report_id": report.id})
    for report in db.scalars(select(MarketplaceReport).where(MarketplaceReport.status == "open")).all():
        listing = db.get(ServiceListing, report.listing_id)
        ensure_case(db, source_type="marketplace_listing", source_id=report.listing_id, subject_user_id=listing.author_id if listing else None, reporter_id=report.reporter_id, reason=report.reason, details=report.details, context={"legacy_report_id": report.id, "title": listing.title if listing else None})
    for report in db.scalars(select(EventReport).where(EventReport.status == "open")).all():
        event = db.get(EventListing, report.event_id)
        ensure_case(db, source_type="event", source_id=report.event_id, subject_user_id=event.author_id if event else None, reporter_id=report.reporter_id, reason=report.reason, details=report.details, context={"legacy_report_id": report.id, "title": event.title if event else None})
    for report in db.scalars(select(ChatMessageReport).where(ChatMessageReport.status == "open")).all():
        message = db.get(ChatMessage, report.message_id)
        ensure_case(db, source_type="chat_message", source_id=report.message_id, subject_user_id=message.sender_id if message else None, reporter_id=report.reporter_id, reason=report.reason, details=report.details, context={"legacy_report_id": report.id, "conversation_id": message.conversation_id if message else None, "message": message.body[:500] if message else None})
    for report in db.scalars(select(JobReport).where(JobReport.status == "open")).all():
        job = db.get(Job, report.job_id)
        ensure_case(db, source_type="job", source_id=report.job_id, subject_user_id=job.employer_id if job else None, reporter_id=report.reporter_id, reason=report.reason, details=report.details, context={"legacy_report_id": report.id, "title": job.title if job else None})
    for report in db.scalars(select(DiscoveryReviewReport)).all():
        review = db.get(DiscoveryReview, report.review_id)
        ensure_case(db, source_type="discovery_review", source_id=report.review_id, subject_user_id=review.user_id if review else None, reporter_id=report.reporter_id, reason=report.reason, context={"legacy_report_id": report.id, "place_id": review.place_id if review else None, "comment": review.comment[:500] if review else None})
    db.commit()
    after = db.scalar(select(func.count()).select_from(ModerationCase)) or 0
    return max(0, after - before)
