from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from uuid import uuid4
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import APIRouter, HTTPException, Query, Request
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError

from ..core.rate_limit import limiter
from ..dependencies import CurrentAdmin, CurrentUser, DBSession, require_premium
from ..models.business import (
    BusinessAvailabilityRule,
    BusinessBooking,
    BusinessClient,
    BusinessDocument,
    BusinessLead,
    BusinessProfile,
    BusinessQuickReply,
    BusinessService,
    BusinessTeamMember,
)
from ..models.chat import ChatConversation, MarketplaceReview
from ..models.marketplace import ServiceListing
from ..models.user import PublicUserProfile, User
from ..schemas.business import (
    AIReceptionistDraftRequest,
    AIReceptionistDraftResponse,
    AdminBusinessProfileResponse,
    AdminBusinessReview,
    AvailabilityRuleCreate,
    AvailabilityRuleResponse,
    BusinessAISettingsResponse,
    BusinessAISettingsUpdate,
    BusinessBookingCreate,
    BusinessBookingResponse,
    BusinessBookingUpdate,
    BusinessClientCreate,
    BusinessClientResponse,
    BusinessClientUpdate,
    BusinessDashboardResponse,
    BusinessDocumentCreate,
    BusinessDocumentResponse,
    BusinessLeadCreate,
    BusinessLeadResponse,
    BusinessLeadUpdate,
    BusinessProfileResponse,
    BusinessProfileUpdate,
    BusinessServiceCreate,
    BusinessServiceResponse,
    BusinessServiceUpdate,
    BusinessWorkspaceResponse,
    QuickReplyCreate,
    QuickReplyResponse,
    PublicBookingCreate,
    PublicBookingSlot,
    PublicBusinessProfileResponse,
    CustomerBookingResponse,
    TeamMemberCreate,
    TeamMemberResponse,
)
from ..services.business_receptionist import generate_receptionist_draft, sync_marketplace_leads
from ..services.audit import log_audit
from ..services.push_notifications import enqueue_account_notification


router = APIRouter(dependencies=[require_premium()])
public_router = APIRouter()
admin_router = APIRouter()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _aware_utc(value: datetime) -> datetime:
    return value.astimezone(timezone.utc) if value.tzinfo else value.replace(tzinfo=timezone.utc)


def _profile(db: DBSession, user_id: str) -> BusinessProfile:
    profile = db.get(BusinessProfile, user_id)
    if not profile:
        raise HTTPException(status_code=404, detail={"code": "business_profile_required"})
    return profile


def _owned(db: DBSession, model, row_id: str, user_id: str):
    row = db.get(model, row_id)
    if not row or row.business_user_id != user_id:
        raise HTTPException(status_code=404, detail="Not found")
    return row


def _apply(row, payload) -> None:
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(row, key, value)


def _premium_active(user: User | None) -> bool:
    if not user or user.subscription_status not in {"trial", "premium"}:
        return False
    expires = user.subscription_expire_at
    if expires is None:
        return True
    comparable = expires if expires.tzinfo else expires.replace(tzinfo=timezone.utc)
    return comparable > _now()


def _approved_business(db: DBSession, user_id: str) -> tuple[BusinessProfile, User]:
    profile = db.get(BusinessProfile, user_id)
    owner = db.get(User, user_id)
    if not profile or profile.status != "approved" or not profile.is_verified or not _premium_active(owner):
        raise HTTPException(status_code=404, detail="Business not found")
    return profile, owner


def _workspace_role(db: DBSession, user: User, owner_id: str, *, write: bool = False) -> str:
    owner = db.get(User, owner_id)
    profile = db.get(BusinessProfile, owner_id)
    if not owner or not profile or not _premium_active(owner):
        raise HTTPException(status_code=404, detail="Business workspace not found")
    if user.id == owner_id:
        return "owner"
    member = db.execute(
        select(BusinessTeamMember).where(
            BusinessTeamMember.business_user_id == owner_id,
            BusinessTeamMember.member_user_id == user.id,
            BusinessTeamMember.status == "active",
        )
    ).scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=403, detail={"code": "business_workspace_access_denied"})
    if write and member.role == "viewer":
        raise HTTPException(status_code=403, detail={"code": "business_workspace_read_only"})
    return member.role


def _business_timezone(profile: BusinessProfile) -> ZoneInfo:
    try:
        return ZoneInfo(profile.timezone)
    except ZoneInfoNotFoundError:
        return ZoneInfo("Europe/Zurich")


def _available_slots(
    db: DBSession,
    profile: BusinessProfile,
    service: BusinessService,
    day: date,
) -> list[PublicBookingSlot]:
    zone = _business_timezone(profile)
    day_start = datetime.combine(day, time.min, tzinfo=zone)
    day_end = day_start + timedelta(days=1)
    if day_start > _now().astimezone(zone) + timedelta(days=93):
        raise HTTPException(status_code=422, detail={"code": "booking_too_far_ahead", "max_days": 93})
    rules = db.execute(
        select(BusinessAvailabilityRule).where(
            BusinessAvailabilityRule.business_user_id == profile.user_id,
            BusinessAvailabilityRule.weekday == day.weekday(),
            BusinessAvailabilityRule.is_active.is_(True),
        )
    ).scalars().all()
    busy = db.execute(
        select(BusinessBooking).where(
            BusinessBooking.business_user_id == profile.user_id,
            BusinessBooking.status.in_(["requested", "confirmed"]),
            BusinessBooking.starts_at < day_end.astimezone(timezone.utc),
            BusinessBooking.ends_at > day_start.astimezone(timezone.utc),
        )
    ).scalars().all()
    now = _now()
    slots: list[PublicBookingSlot] = []
    duration = timedelta(minutes=service.duration_minutes)
    step = duration + timedelta(minutes=service.buffer_minutes)
    for rule in rules:
        start_hour, start_minute = (int(part) for part in rule.start_time.split(":"))
        end_hour, end_minute = (int(part) for part in rule.end_time.split(":"))
        cursor = datetime.combine(day, time(start_hour, start_minute), tzinfo=zone)
        window_end = datetime.combine(day, time(end_hour, end_minute), tzinfo=zone)
        while cursor + duration <= window_end and len(slots) < 96:
            starts_at = cursor.astimezone(timezone.utc)
            ends_at = (cursor + duration).astimezone(timezone.utc)
            blocked_until = (cursor + step).astimezone(timezone.utc)
            conflict = any(
                _aware_utc(item.starts_at) < blocked_until and _aware_utc(item.ends_at) > starts_at
                for item in busy
            )
            if starts_at > now + timedelta(minutes=15) and not conflict:
                slots.append(PublicBookingSlot(starts_at=starts_at, ends_at=ends_at))
            cursor += step
    return slots


@router.get("/profile", response_model=BusinessProfileResponse)
def get_profile(db: DBSession, user: CurrentUser) -> BusinessProfile:
    return _profile(db, user.id)


@router.put("/profile", response_model=BusinessProfileResponse)
@limiter.limit("12/minute")
def save_profile(request: Request, payload: BusinessProfileUpdate, db: DBSession, user: CurrentUser) -> BusinessProfile:
    profile = db.get(BusinessProfile, user.id)
    if profile is None:
        profile = BusinessProfile(user_id=user.id, **payload.model_dump())
    else:
        previous_identity = (profile.display_name, profile.legal_name, profile.category, profile.canton, profile.uid_number)
        _apply(profile, payload)
        new_identity = (profile.display_name, profile.legal_name, profile.category, profile.canton, profile.uid_number)
        if profile.status in {"pending", "rejected"} or (profile.status == "approved" and previous_identity != new_identity):
            profile.status = "draft"
            profile.rejection_reason = None
            profile.is_verified = False
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile


@router.post("/profile/submit", response_model=BusinessProfileResponse)
def submit_profile(db: DBSession, user: CurrentUser) -> BusinessProfile:
    profile = _profile(db, user.id)
    if not profile.description.strip() or not profile.languages or not profile.delivery_modes:
        raise HTTPException(
            status_code=422,
            detail={"code": "business_profile_incomplete", "required": ["description", "languages", "delivery_modes"]},
        )
    profile.status = "pending"
    profile.submitted_at = _now()
    profile.rejection_reason = None
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile


@router.get("/ai-settings", response_model=BusinessAISettingsResponse)
def get_ai_settings(db: DBSession, user: CurrentUser) -> BusinessAISettingsResponse:
    profile = _profile(db, user.id)
    return BusinessAISettingsResponse.model_validate(profile, from_attributes=True)


@router.put("/ai-settings", response_model=BusinessAISettingsResponse)
def save_ai_settings(payload: BusinessAISettingsUpdate, db: DBSession, user: CurrentUser) -> BusinessAISettingsResponse:
    profile = _profile(db, user.id)
    _apply(profile, payload)
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return BusinessAISettingsResponse.model_validate(profile, from_attributes=True)


@router.post("/ai-receptionist/draft", response_model=AIReceptionistDraftResponse)
@limiter.limit("10/minute")
def ai_receptionist_draft(
    request: Request,
    payload: AIReceptionistDraftRequest,
    db: DBSession,
    user: CurrentUser,
) -> AIReceptionistDraftResponse:
    profile = _profile(db, user.id)
    if not profile.ai_enabled:
        raise HTTPException(status_code=409, detail={"code": "ai_receptionist_disabled"})
    if payload.conversation_id:
        conversation = db.get(ChatConversation, payload.conversation_id)
        if not conversation or conversation.seller_id != user.id:
            raise HTTPException(status_code=404, detail="Conversation not found")
    return generate_receptionist_draft(
        db,
        profile,
        [message.model_dump() for message in payload.messages],
        customer_name=payload.customer_name,
        customer_language=payload.customer_language,
    )


@router.get("/services", response_model=list[BusinessServiceResponse])
def list_services(db: DBSession, user: CurrentUser) -> list[BusinessService]:
    _profile(db, user.id)
    return db.execute(
        select(BusinessService).where(BusinessService.business_user_id == user.id).order_by(BusinessService.created_at.desc())
    ).scalars().all()


@router.post("/services", response_model=BusinessServiceResponse, status_code=201)
def create_service(payload: BusinessServiceCreate, db: DBSession, user: CurrentUser) -> BusinessService:
    _profile(db, user.id)
    count = db.scalar(select(func.count()).select_from(BusinessService).where(BusinessService.business_user_id == user.id)) or 0
    if count >= 20:
        raise HTTPException(status_code=409, detail={"code": "business_service_limit", "limit": 20})
    if payload.listing_id:
        listing = db.get(ServiceListing, payload.listing_id)
        if not listing or listing.author_id != user.id or listing.listing_type != "service":
            raise HTTPException(status_code=404, detail="Listing not found")
    row = BusinessService(business_user_id=user.id, **payload.model_dump())
    db.add(row)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Listing already connected") from exc
    db.refresh(row)
    return row


@router.patch("/services/{service_id}", response_model=BusinessServiceResponse)
def update_service(service_id: str, payload: BusinessServiceUpdate, db: DBSession, user: CurrentUser) -> BusinessService:
    row = _owned(db, BusinessService, service_id, user.id)
    _apply(row, payload)
    if row.price_cents is not None and row.price_to_cents is not None and row.price_to_cents < row.price_cents:
        raise HTTPException(status_code=422, detail="Invalid price range")
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.delete("/services/{service_id}", status_code=204)
def delete_service(service_id: str, db: DBSession, user: CurrentUser) -> None:
    row = _owned(db, BusinessService, service_id, user.id)
    db.delete(row)
    db.commit()


@router.get("/availability", response_model=list[AvailabilityRuleResponse])
def get_availability(db: DBSession, user: CurrentUser) -> list[BusinessAvailabilityRule]:
    _profile(db, user.id)
    return db.execute(
        select(BusinessAvailabilityRule)
        .where(BusinessAvailabilityRule.business_user_id == user.id)
        .order_by(BusinessAvailabilityRule.weekday, BusinessAvailabilityRule.start_time)
    ).scalars().all()


@router.put("/availability", response_model=list[AvailabilityRuleResponse])
def replace_availability(payload: list[AvailabilityRuleCreate], db: DBSession, user: CurrentUser) -> list[BusinessAvailabilityRule]:
    _profile(db, user.id)
    if len(payload) > 28:
        raise HTTPException(status_code=422, detail="Too many availability windows")
    db.query(BusinessAvailabilityRule).filter(BusinessAvailabilityRule.business_user_id == user.id).delete()
    rows = [BusinessAvailabilityRule(business_user_id=user.id, **item.model_dump()) for item in payload]
    db.add_all(rows)
    db.commit()
    for row in rows:
        db.refresh(row)
    return rows


@router.get("/leads", response_model=list[BusinessLeadResponse])
def list_leads(
    db: DBSession,
    user: CurrentUser,
    lead_status: str | None = Query(default=None, alias="status", max_length=30),
) -> list[BusinessLead]:
    _profile(db, user.id)
    sync_marketplace_leads(db, user.id)
    stmt = select(BusinessLead).where(BusinessLead.business_user_id == user.id)
    if lead_status:
        stmt = stmt.where(BusinessLead.status == lead_status)
    return db.execute(stmt.order_by(BusinessLead.updated_at.desc())).scalars().all()


@router.post("/leads", response_model=BusinessLeadResponse, status_code=201)
def create_lead(payload: BusinessLeadCreate, db: DBSession, user: CurrentUser) -> BusinessLead:
    _profile(db, user.id)
    row = BusinessLead(business_user_id=user.id, **payload.model_dump())
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.patch("/leads/{lead_id}", response_model=BusinessLeadResponse)
def update_lead(lead_id: str, payload: BusinessLeadUpdate, db: DBSession, user: CurrentUser) -> BusinessLead:
    row = _owned(db, BusinessLead, lead_id, user.id)
    _apply(row, payload)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.get("/clients", response_model=list[BusinessClientResponse])
def list_clients(db: DBSession, user: CurrentUser) -> list[BusinessClient]:
    _profile(db, user.id)
    return db.execute(
        select(BusinessClient).where(BusinessClient.business_user_id == user.id).order_by(BusinessClient.last_activity_at.desc().nullslast())
    ).scalars().all()


@router.post("/clients", response_model=BusinessClientResponse, status_code=201)
def create_client(payload: BusinessClientCreate, db: DBSession, user: CurrentUser) -> BusinessClient:
    _profile(db, user.id)
    row = BusinessClient(business_user_id=user.id, **payload.model_dump())
    db.add(row)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Client already exists") from exc
    db.refresh(row)
    return row


@router.patch("/clients/{client_id}", response_model=BusinessClientResponse)
def update_client(client_id: str, payload: BusinessClientUpdate, db: DBSession, user: CurrentUser) -> BusinessClient:
    row = _owned(db, BusinessClient, client_id, user.id)
    _apply(row, payload)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def _validate_booking_refs(db: DBSession, user_id: str, payload: BusinessBookingCreate) -> None:
    for model, row_id in ((BusinessClient, payload.client_id), (BusinessLead, payload.lead_id), (BusinessService, payload.service_id)):
        if row_id:
            _owned(db, model, row_id, user_id)


def _booking_conflict(db: DBSession, user_id: str, starts_at: datetime, ends_at: datetime, excluding: str | None = None) -> bool:
    stmt = select(func.count()).select_from(BusinessBooking).where(
        BusinessBooking.business_user_id == user_id,
        BusinessBooking.status.in_(["requested", "confirmed"]),
        BusinessBooking.starts_at < ends_at,
        BusinessBooking.ends_at > starts_at,
    )
    if excluding:
        stmt = stmt.where(BusinessBooking.id != excluding)
    return (db.scalar(stmt) or 0) > 0


@router.get("/bookings", response_model=list[BusinessBookingResponse])
def list_bookings(
    db: DBSession,
    user: CurrentUser,
    start: datetime | None = None,
    end: datetime | None = None,
) -> list[BusinessBooking]:
    _profile(db, user.id)
    stmt = select(BusinessBooking).where(BusinessBooking.business_user_id == user.id)
    if start:
        stmt = stmt.where(BusinessBooking.ends_at >= start)
    if end:
        stmt = stmt.where(BusinessBooking.starts_at <= end)
    return db.execute(stmt.order_by(BusinessBooking.starts_at.asc()).limit(500)).scalars().all()


@router.post("/bookings", response_model=BusinessBookingResponse, status_code=201)
def create_booking(payload: BusinessBookingCreate, db: DBSession, user: CurrentUser) -> BusinessBooking:
    _profile(db, user.id)
    _validate_booking_refs(db, user.id, payload)
    if _booking_conflict(db, user.id, payload.starts_at, payload.ends_at):
        raise HTTPException(status_code=409, detail={"code": "booking_conflict"})
    row = BusinessBooking(business_user_id=user.id, **payload.model_dump())
    db.add(row)
    if payload.client_id:
        client = _owned(db, BusinessClient, payload.client_id, user.id)
        client.booking_count += 1
        client.last_activity_at = _now()
    db.commit()
    db.refresh(row)
    return row


def _update_booking_for_owner(
    db: DBSession,
    owner_id: str,
    booking_id: str,
    payload: BusinessBookingUpdate,
) -> BusinessBooking:
    row = _owned(db, BusinessBooking, booking_id, owner_id)
    values = payload.model_dump(exclude_unset=True)
    starts_at = values.get("starts_at", row.starts_at)
    ends_at = values.get("ends_at", row.ends_at)
    if ends_at <= starts_at:
        raise HTTPException(status_code=422, detail="ends_at must be after starts_at")
    if values.get("status", row.status) in {"requested", "confirmed"} and _booking_conflict(db, owner_id, starts_at, ends_at, row.id):
        raise HTTPException(status_code=409, detail={"code": "booking_conflict"})
    previous = row.status
    _apply(row, payload)
    if row.client_id:
        client = _owned(db, BusinessClient, row.client_id, owner_id)
        client.last_activity_at = _now()
        if previous != "completed" and row.status == "completed":
            client.completed_count += 1
            client.total_spend_cents += row.price_cents or 0
        if previous != row.status and client.customer_user_id:
            enqueue_account_notification(
                db,
                event_key=f"business-booking-status:{row.id}:{row.status}",
                recipient_id=client.customer_user_id,
                event_type="business_booking_status",
                title="Оновлення запису",
                body=f"{row.customer_name}: статус запису — {row.status}",
                data={"booking_id": row.id, "business_user_id": owner_id, "status": row.status},
            )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.patch("/bookings/{booking_id}", response_model=BusinessBookingResponse)
def update_booking(booking_id: str, payload: BusinessBookingUpdate, db: DBSession, user: CurrentUser) -> BusinessBooking:
    return _update_booking_for_owner(db, user.id, booking_id, payload)


@router.get("/quick-replies", response_model=list[QuickReplyResponse])
def list_quick_replies(db: DBSession, user: CurrentUser) -> list[BusinessQuickReply]:
    _profile(db, user.id)
    return db.execute(
        select(BusinessQuickReply).where(BusinessQuickReply.business_user_id == user.id).order_by(BusinessQuickReply.sort_order)
    ).scalars().all()


@router.post("/quick-replies", response_model=QuickReplyResponse, status_code=201)
def create_quick_reply(payload: QuickReplyCreate, db: DBSession, user: CurrentUser) -> BusinessQuickReply:
    _profile(db, user.id)
    count = db.scalar(select(func.count()).select_from(BusinessQuickReply).where(BusinessQuickReply.business_user_id == user.id)) or 0
    if count >= 50:
        raise HTTPException(status_code=409, detail={"code": "quick_reply_limit", "limit": 50})
    row = BusinessQuickReply(business_user_id=user.id, **payload.model_dump())
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.put("/quick-replies/{reply_id}", response_model=QuickReplyResponse)
def update_quick_reply(reply_id: str, payload: QuickReplyCreate, db: DBSession, user: CurrentUser) -> BusinessQuickReply:
    row = _owned(db, BusinessQuickReply, reply_id, user.id)
    _apply(row, payload)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.delete("/quick-replies/{reply_id}", status_code=204)
def delete_quick_reply(reply_id: str, db: DBSession, user: CurrentUser) -> None:
    row = _owned(db, BusinessQuickReply, reply_id, user.id)
    db.delete(row)
    db.commit()


@router.get("/team", response_model=list[TeamMemberResponse])
def list_team(db: DBSession, user: CurrentUser) -> list[BusinessTeamMember]:
    _profile(db, user.id)
    return db.execute(select(BusinessTeamMember).where(BusinessTeamMember.business_user_id == user.id)).scalars().all()


@router.post("/team", response_model=TeamMemberResponse, status_code=201)
def add_team_member(payload: TeamMemberCreate, db: DBSession, user: CurrentUser) -> BusinessTeamMember:
    _profile(db, user.id)
    normalized_email = payload.email.lower().strip()
    member_user = db.execute(select(User).where(func.lower(User.email) == normalized_email)).scalar_one_or_none()
    row = BusinessTeamMember(
        business_user_id=user.id,
        member_user_id=member_user.id if member_user and member_user.email_verified and member_user.is_active else None,
        email=normalized_email,
        display_name=payload.display_name,
        role=payload.role,
        status="active" if member_user and member_user.email_verified and member_user.is_active else "pending",
    )
    db.add(row)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Team member already exists") from exc
    db.refresh(row)
    if row.member_user_id:
        profile = db.get(BusinessProfile, user.id)
        enqueue_account_notification(
            db,
            event_key=f"business-team-invite:{row.id}",
            recipient_id=row.member_user_id,
            event_type="business_team_invite",
            title="Запрошення до команди",
            body=f"{profile.display_name if profile else 'Sweezy Pro'} додав вас до робочого простору",
            data={"business_user_id": user.id, "role": row.role},
        )
        db.commit()
    return row


@router.delete("/team/{member_id}", status_code=204)
def remove_team_member(member_id: str, db: DBSession, user: CurrentUser) -> None:
    row = _owned(db, BusinessTeamMember, member_id, user.id)
    db.delete(row)
    db.commit()


@router.get("/documents", response_model=list[BusinessDocumentResponse])
def list_documents(db: DBSession, user: CurrentUser) -> list[BusinessDocument]:
    _profile(db, user.id)
    return db.execute(
        select(BusinessDocument).where(BusinessDocument.business_user_id == user.id).order_by(BusinessDocument.created_at.desc())
    ).scalars().all()


@router.post("/documents", response_model=BusinessDocumentResponse, status_code=201)
def create_document(payload: BusinessDocumentCreate, db: DBSession, user: CurrentUser) -> BusinessDocument:
    _profile(db, user.id)
    if payload.client_id:
        _owned(db, BusinessClient, payload.client_id, user.id)
    if payload.lead_id:
        _owned(db, BusinessLead, payload.lead_id, user.id)
    total = 0
    normalized: list[dict] = []
    for item in payload.line_items:
        title = str(item.get("title", "")).strip()[:160]
        quantity = max(1, min(int(item.get("quantity", 1)), 10_000))
        unit = max(0, min(int(item.get("unit_price_cents", 0)), 100_000_000))
        if not title:
            continue
        total += quantity * unit
        normalized.append({"title": title, "quantity": quantity, "unit_price_cents": unit})
    prefix = {"quote": "Q", "confirmation": "C", "invoice": "I"}[payload.document_type]
    number = f"{prefix}-{_now().strftime('%Y%m%d')}-{str(uuid4())[:6].upper()}"
    row = BusinessDocument(
        business_user_id=user.id,
        number=number,
        total_cents=total,
        **payload.model_dump(exclude={"line_items"}),
        line_items=normalized,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def _dashboard_response(db: DBSession, owner_id: str) -> BusinessDashboardResponse:
    profile = _profile(db, owner_id)
    leads = sync_marketplace_leads(db, owner_id)
    listings = db.execute(select(ServiceListing).where(ServiceListing.author_id == owner_id)).scalars().all()
    bookings = db.execute(
        select(BusinessBooking).where(BusinessBooking.business_user_id == owner_id).order_by(BusinessBooking.starts_at.asc()).limit(100)
    ).scalars().all()
    clients = db.execute(
        select(BusinessClient).where(BusinessClient.business_user_id == owner_id).order_by(BusinessClient.last_activity_at.desc().nullslast()).limit(100)
    ).scalars().all()
    replies = db.execute(
        select(BusinessQuickReply).where(BusinessQuickReply.business_user_id == owner_id, BusinessQuickReply.is_active.is_(True)).order_by(BusinessQuickReply.sort_order)
    ).scalars().all()
    conversations = db.execute(select(ChatConversation).where(
        ChatConversation.seller_id == owner_id,
        ChatConversation.listing_id.is_not(None),
    )).scalars().all()
    ratings = db.execute(select(MarketplaceReview.rating).where(MarketplaceReview.reviewed_user_id == owner_id)).scalars().all()
    today = _now().date()
    active_leads = [lead for lead in leads if lead.status not in {"completed", "cancelled", "lost"}]
    booked = [lead for lead in leads if lead.status in {"booked", "completed"}]
    replied = sum(1 for conversation in conversations if conversation.last_message_sender_id == owner_id)
    return BusinessDashboardResponse(
        profile=BusinessProfileResponse.model_validate(profile),
        total_listings=len(listings),
        active_listings=sum(item.status == "approved" for item in listings),
        total_views=sum(item.view_count for item in listings),
        inquiries=len(conversations),
        open_leads=len(active_leads),
        bookings_today=sum(_aware_utc(item.starts_at).date() == today and item.status not in {"cancelled", "no_show"} for item in bookings),
        upcoming_bookings=sum(_aware_utc(item.starts_at) >= _now() and item.status in {"requested", "confirmed"} for item in bookings),
        clients_total=len(clients),
        average_rating=round(sum(ratings) / len(ratings), 1) if ratings else None,
        review_count=len(ratings),
        response_rate_percent=round((replied / len(conversations)) * 100) if conversations else 0,
        conversion_percent=round((len(booked) / len(leads)) * 100) if leads else 0,
        leads=leads[:20],
        bookings=bookings[:20],
        clients=clients[:20],
        quick_replies=replies,
    )


@router.get("/dashboard", response_model=BusinessDashboardResponse)
def dashboard(db: DBSession, user: CurrentUser) -> BusinessDashboardResponse:
    return _dashboard_response(db, user.id)


def _customer_booking_response(db: DBSession, row: BusinessBooking) -> CustomerBookingResponse:
    profile = db.get(BusinessProfile, row.business_user_id)
    service = db.get(BusinessService, row.service_id) if row.service_id else None
    return CustomerBookingResponse(
        **BusinessBookingResponse.model_validate(row).model_dump(),
        business_name=profile.display_name if profile else "Sweezy business",
        service_title=service.title if service else None,
    )


@public_router.get("/me/bookings", response_model=list[CustomerBookingResponse])
def my_business_bookings(db: DBSession, user: CurrentUser) -> list[CustomerBookingResponse]:
    rows = db.execute(
        select(BusinessBooking)
        .join(BusinessClient, BusinessClient.id == BusinessBooking.client_id)
        .where(BusinessClient.customer_user_id == user.id)
        .order_by(BusinessBooking.starts_at.desc())
        .limit(200)
    ).scalars().all()
    return [_customer_booking_response(db, row) for row in rows]


@public_router.get("/me/workspaces", response_model=list[BusinessWorkspaceResponse])
def my_business_workspaces(db: DBSession, user: CurrentUser) -> list[BusinessWorkspaceResponse]:
    result: list[BusinessWorkspaceResponse] = []
    own_profile = db.get(BusinessProfile, user.id)
    if own_profile and _premium_active(user):
        result.append(BusinessWorkspaceResponse(
            owner_user_id=user.id,
            display_name=own_profile.display_name,
            role="owner",
            profile_status=own_profile.status,
            is_verified=own_profile.is_verified,
        ))
    if user.email_verified:
        pending_memberships = db.execute(
            select(BusinessTeamMember).where(
                func.lower(BusinessTeamMember.email) == user.email.lower(),
                BusinessTeamMember.member_user_id.is_(None),
                BusinessTeamMember.status == "pending",
            )
        ).scalars().all()
        for pending in pending_memberships:
            pending.member_user_id = user.id
            pending.status = "active"
            db.add(pending)
        if pending_memberships:
            db.commit()
    memberships = db.execute(
        select(BusinessTeamMember).where(
            BusinessTeamMember.member_user_id == user.id,
            BusinessTeamMember.status == "active",
        )
    ).scalars().all()
    for membership in memberships:
        profile = db.get(BusinessProfile, membership.business_user_id)
        owner = db.get(User, membership.business_user_id)
        if profile and _premium_active(owner):
            result.append(BusinessWorkspaceResponse(
                owner_user_id=membership.business_user_id,
                display_name=profile.display_name,
                role=membership.role,
                profile_status=profile.status,
                is_verified=profile.is_verified,
            ))
    return result


@public_router.get("/workspaces/{owner_id}/dashboard", response_model=BusinessDashboardResponse)
def team_workspace_dashboard(owner_id: str, db: DBSession, user: CurrentUser) -> BusinessDashboardResponse:
    _workspace_role(db, user, owner_id)
    return _dashboard_response(db, owner_id)


@public_router.patch("/workspaces/{owner_id}/leads/{lead_id}", response_model=BusinessLeadResponse)
def team_update_lead(
    owner_id: str,
    lead_id: str,
    payload: BusinessLeadUpdate,
    db: DBSession,
    user: CurrentUser,
) -> BusinessLead:
    _workspace_role(db, user, owner_id, write=True)
    row = _owned(db, BusinessLead, lead_id, owner_id)
    _apply(row, payload)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@public_router.patch("/workspaces/{owner_id}/bookings/{booking_id}", response_model=BusinessBookingResponse)
def team_update_booking(
    owner_id: str,
    booking_id: str,
    payload: BusinessBookingUpdate,
    db: DBSession,
    user: CurrentUser,
) -> BusinessBooking:
    _workspace_role(db, user, owner_id, write=True)
    return _update_booking_for_owner(db, owner_id, booking_id, payload)


@public_router.post("/me/bookings/{booking_id}/cancel", response_model=CustomerBookingResponse)
def cancel_my_business_booking(booking_id: str, db: DBSession, user: CurrentUser) -> CustomerBookingResponse:
    row = db.execute(
        select(BusinessBooking)
        .join(BusinessClient, BusinessClient.id == BusinessBooking.client_id)
        .where(BusinessBooking.id == booking_id, BusinessClient.customer_user_id == user.id)
    ).scalar_one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Booking not found")
    if row.status not in {"requested", "confirmed"}:
        raise HTTPException(status_code=409, detail={"code": "booking_cannot_be_cancelled"})
    if _aware_utc(row.starts_at) <= _now():
        raise HTTPException(status_code=409, detail={"code": "past_booking_cannot_be_cancelled"})
    row.status = "cancelled"
    enqueue_account_notification(
        db,
        event_key=f"business-booking-cancelled:{row.id}",
        recipient_id=row.business_user_id,
        event_type="business_booking_cancelled",
        title="Запис скасовано",
        body=f"{row.customer_name} скасував(-ла) запис",
        data={"booking_id": row.id},
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _customer_booking_response(db, row)


@public_router.get("/{user_id}", response_model=PublicBusinessProfileResponse)
def public_business_profile(user_id: str, db: DBSession) -> PublicBusinessProfileResponse:
    profile, _ = _approved_business(db, user_id)
    services = db.execute(
        select(BusinessService)
        .where(BusinessService.business_user_id == user_id, BusinessService.is_active.is_(True))
        .order_by(BusinessService.created_at.asc())
    ).scalars().all()
    ratings = db.execute(
        select(MarketplaceReview.rating).where(MarketplaceReview.reviewed_user_id == user_id)
    ).scalars().all()
    return PublicBusinessProfileResponse(
        user_id=profile.user_id,
        display_name=profile.display_name,
        description=profile.description,
        category=profile.category,
        canton=profile.canton,
        city=profile.city,
        service_area=profile.service_area,
        languages=profile.languages,
        logo_url=profile.logo_url,
        cover_url=profile.cover_url,
        website=profile.website,
        delivery_modes=profile.delivery_modes,
        cancellation_policy=profile.cancellation_policy,
        is_verified=profile.is_verified,
        services=services,
        average_rating=round(sum(ratings) / len(ratings), 1) if ratings else None,
        review_count=len(ratings),
    )


@public_router.get("/{user_id}/slots", response_model=list[PublicBookingSlot])
def public_business_slots(
    user_id: str,
    db: DBSession,
    service_id: str = Query(min_length=36, max_length=36),
    booking_day: date = Query(alias="date"),
) -> list[PublicBookingSlot]:
    profile, _ = _approved_business(db, user_id)
    service = db.get(BusinessService, service_id)
    if not service or service.business_user_id != user_id or not service.is_active:
        raise HTTPException(status_code=404, detail="Service not found")
    return _available_slots(db, profile, service, booking_day)


@public_router.post("/{user_id}/bookings", response_model=BusinessBookingResponse, status_code=201)
@limiter.limit("8/hour")
def request_public_booking(
    request: Request,
    user_id: str,
    payload: PublicBookingCreate,
    db: DBSession,
    user: CurrentUser,
) -> BusinessBooking:
    profile, _ = _approved_business(db, user_id)
    if user.id == user_id:
        raise HTTPException(status_code=409, detail={"code": "cannot_book_own_business"})
    service = db.get(BusinessService, payload.service_id)
    if not service or service.business_user_id != user_id or not service.is_active:
        raise HTTPException(status_code=404, detail="Service not found")
    starts_at = payload.starts_at.astimezone(timezone.utc)
    slots = _available_slots(db, profile, service, starts_at.astimezone(_business_timezone(profile)).date())
    selected = next((slot for slot in slots if abs((slot.starts_at - starts_at).total_seconds()) < 1), None)
    if selected is None:
        raise HTTPException(status_code=409, detail={"code": "booking_slot_unavailable"})
    duplicate = db.execute(
        select(BusinessBooking)
        .join(BusinessClient, BusinessClient.id == BusinessBooking.client_id)
        .where(
            BusinessBooking.business_user_id == user_id,
            BusinessBooking.service_id == service.id,
            BusinessBooking.starts_at == selected.starts_at,
            BusinessBooking.status.in_(["requested", "confirmed"]),
            BusinessClient.customer_user_id == user.id,
        )
    ).scalar_one_or_none()
    if duplicate:
        return duplicate
    display_profile = db.get(PublicUserProfile, user.id)
    customer_name = display_profile.display_name if display_profile else user.email.split("@", 1)[0]
    client = db.execute(
        select(BusinessClient).where(
            BusinessClient.business_user_id == user_id,
            BusinessClient.customer_user_id == user.id,
        )
    ).scalar_one_or_none()
    if client is None:
        client = BusinessClient(
            business_user_id=user_id,
            customer_user_id=user.id,
            display_name=customer_name,
            email=user.email,
            last_activity_at=_now(),
        )
        db.add(client)
        db.flush()
    lead = BusinessLead(
        business_user_id=user_id,
        customer_user_id=user.id,
        service_id=service.id,
        customer_name=customer_name,
        status="booked",
        source="public_booking",
        desired_at=selected.starts_at,
        notes=payload.notes,
        next_action="Підтвердити запис",
    )
    db.add(lead)
    db.flush()
    row = BusinessBooking(
        business_user_id=user_id,
        client_id=client.id,
        lead_id=lead.id,
        service_id=service.id,
        customer_name=customer_name,
        starts_at=selected.starts_at,
        ends_at=selected.ends_at,
        status="requested",
        location=profile.address if service.delivery_mode == "onsite" else None,
        notes=payload.notes,
        price_cents=service.price_cents,
        currency=service.currency,
    )
    client.booking_count += 1
    client.last_activity_at = _now()
    db.add(row)
    db.flush()
    enqueue_account_notification(
        db,
        event_key=f"business-booking-request:{row.id}",
        recipient_id=user_id,
        event_type="business_booking_request",
        title="Новий запис",
        body=f"{customer_name} хоче записатися на {service.title}",
        data={"booking_id": row.id, "service_id": service.id},
    )
    db.commit()
    db.refresh(row)
    return row


@admin_router.get("/businesses", response_model=list[AdminBusinessProfileResponse])
def admin_list_businesses(
    db: DBSession,
    admin: CurrentAdmin,
    business_status: str | None = Query(default=None, alias="status", max_length=20),
) -> list[AdminBusinessProfileResponse]:
    stmt = select(BusinessProfile).order_by(BusinessProfile.submitted_at.desc().nullslast(), BusinessProfile.created_at.desc())
    if business_status:
        stmt = stmt.where(BusinessProfile.status == business_status)
    rows = db.execute(stmt).scalars().all()
    result: list[AdminBusinessProfileResponse] = []
    for profile in rows:
        owner = db.get(User, profile.user_id)
        result.append(AdminBusinessProfileResponse(
            **BusinessProfileResponse.model_validate(profile).model_dump(),
            owner_email=owner.email if owner else "deleted",
            subscription_status=owner.subscription_status if owner else "free",
            subscription_expire_at=owner.subscription_expire_at if owner else None,
            ai_enabled=profile.ai_enabled,
            ai_auto_reply=profile.ai_auto_reply,
            services_count=db.scalar(select(func.count()).select_from(BusinessService).where(BusinessService.business_user_id == profile.user_id)) or 0,
            leads_count=db.scalar(select(func.count()).select_from(BusinessLead).where(BusinessLead.business_user_id == profile.user_id)) or 0,
            bookings_count=db.scalar(select(func.count()).select_from(BusinessBooking).where(BusinessBooking.business_user_id == profile.user_id)) or 0,
            clients_count=db.scalar(select(func.count()).select_from(BusinessClient).where(BusinessClient.business_user_id == profile.user_id)) or 0,
            documents_count=db.scalar(select(func.count()).select_from(BusinessDocument).where(BusinessDocument.business_user_id == profile.user_id)) or 0,
            team_members_count=db.scalar(select(func.count()).select_from(BusinessTeamMember).where(BusinessTeamMember.business_user_id == profile.user_id)) or 0,
        ))
    return result


@admin_router.patch("/businesses/{user_id}/review", response_model=AdminBusinessProfileResponse)
def admin_review_business(
    user_id: str,
    payload: AdminBusinessReview,
    db: DBSession,
    admin: CurrentAdmin,
) -> AdminBusinessProfileResponse:
    profile = _profile(db, user_id)
    before = {"status": profile.status, "is_verified": profile.is_verified, "reason": profile.rejection_reason}
    profile.status = {"approve": "approved", "reject": "rejected", "suspend": "suspended"}[payload.decision]
    profile.is_verified = payload.decision == "approve"
    profile.rejection_reason = payload.comment if payload.decision != "approve" else None
    profile.reviewed_at = _now()
    profile.reviewed_by = admin.get("sub")
    enqueue_account_notification(
        db,
        event_key=f"business-review:{user_id}:{profile.status}:{int(profile.reviewed_at.timestamp())}",
        recipient_id=user_id,
        event_type="business_profile_review",
        title="Перевірка бізнес-профілю",
        body={
            "approved": "Профіль схвалено — бронювання та Pro-функції активні.",
            "rejected": "Потрібні зміни у бізнес-профілі. Відкрий Sweezy Pro для деталей.",
            "suspended": "Публікацію бізнес-профілю тимчасово призупинено.",
        }[profile.status],
        data={"business_user_id": user_id, "status": profile.status},
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)
    owner = db.get(User, user_id)
    actor = db.get(User, admin.get("sub"))
    log_audit(
        db,
        user_email=actor.email if actor else f"admin:{admin.get('sub', 'unknown')}",
        action=f"business_{payload.decision}",
        entity="business_profile",
        entity_id=user_id,
        before=before,
        after={"status": profile.status, "is_verified": profile.is_verified, "comment": payload.comment},
    )
    return AdminBusinessProfileResponse(
        **BusinessProfileResponse.model_validate(profile).model_dump(),
        owner_email=owner.email if owner else "deleted",
        subscription_status=owner.subscription_status if owner else "free",
        subscription_expire_at=owner.subscription_expire_at if owner else None,
        ai_enabled=profile.ai_enabled,
        ai_auto_reply=profile.ai_auto_reply,
        services_count=db.scalar(select(func.count()).select_from(BusinessService).where(BusinessService.business_user_id == user_id)) or 0,
        leads_count=db.scalar(select(func.count()).select_from(BusinessLead).where(BusinessLead.business_user_id == user_id)) or 0,
        bookings_count=db.scalar(select(func.count()).select_from(BusinessBooking).where(BusinessBooking.business_user_id == user_id)) or 0,
        clients_count=db.scalar(select(func.count()).select_from(BusinessClient).where(BusinessClient.business_user_id == user_id)) or 0,
        documents_count=db.scalar(select(func.count()).select_from(BusinessDocument).where(BusinessDocument.business_user_id == user_id)) or 0,
        team_members_count=db.scalar(select(func.count()).select_from(BusinessTeamMember).where(BusinessTeamMember.business_user_id == user_id)) or 0,
    )
