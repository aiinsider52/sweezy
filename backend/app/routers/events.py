import math
from datetime import datetime
from typing import Any, Dict, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, select

from ..core.security import decode_token
from ..dependencies import CurrentAdmin, CurrentUser, DBSession
from ..models.event_listing import EventListing, EventReport
from ..models.marketplace import MarketplaceBlock
from ..schemas.events import (
    EventCategory,
    EventListingCreate,
    EventListingDetail,
    EventListingPage,
    EventListingResponse,
    EventListingUpdate,
    EventReportCreate,
    EventSafetyResponse,
)
from ..services.events_moderation import moderate_event_listing
from ..services.users import UserService


router = APIRouter()
admin_router = APIRouter()

_optional_bearer = HTTPBearer(auto_error=False)


def _is_premium(user) -> bool:
    if (user.subscription_status or "free") not in {"trial", "premium"}: return False
    expires = user.subscription_expire_at
    if expires is None: return True
    now = datetime.now(expires.tzinfo) if expires.tzinfo else datetime.utcnow()
    return expires > now


def _get_optional_user_id(
    db: DBSession,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_optional_bearer),
) -> str | None:
    if credentials is None:
        return None
    try:
        payload = decode_token(credentials.credentials)
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authentication")
        user = UserService.get_by_id(db, user_id)
        if not user or not user.is_active:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authentication")
        return user.id
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authentication")


@router.get("/", response_model=EventListingPage)
def list_events(
    db: DBSession,
    category: Optional[EventCategory] = None,
    canton: Optional[str] = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    upcoming_only: bool = Query(True),
    user_id: str | None = Depends(_get_optional_user_id),
) -> EventListingPage:
    stmt = select(EventListing).where(EventListing.status == "approved", EventListing.is_private.is_(False))
    count_stmt = select(func.count()).select_from(EventListing).where(
        EventListing.status == "approved", EventListing.is_private.is_(False))

    if category:
        stmt = stmt.where(EventListing.category == category.value)
        count_stmt = count_stmt.where(EventListing.category == category.value)
    if canton:
        stmt = stmt.where(EventListing.canton == canton)
        count_stmt = count_stmt.where(EventListing.canton == canton)
    if upcoming_only:
        now = datetime.utcnow()
        stmt = stmt.where(EventListing.starts_at >= now)
        count_stmt = count_stmt.where(EventListing.starts_at >= now)
    if user_id:
        blocked_authors = select(MarketplaceBlock.blocked_author_id).where(MarketplaceBlock.user_id == user_id)
        stmt = stmt.where((EventListing.author_id.is_(None)) | (~EventListing.author_id.in_(blocked_authors)))
        count_stmt = count_stmt.where((EventListing.author_id.is_(None)) | (~EventListing.author_id.in_(blocked_authors)))

    total: int = db.scalar(count_stmt) or 0
    pages = max(1, math.ceil(total / per_page))
    offset = (page - 1) * per_page

    rows = db.execute(
        stmt.order_by(EventListing.starts_at.asc(), EventListing.created_at.desc()).offset(offset).limit(per_page)
    ).scalars().all()

    return EventListingPage(
        items=[EventListingResponse.model_validate(r) for r in rows],
        total=total,
        page=page,
        per_page=per_page,
        pages=pages,
    )


@router.get("/my", response_model=list[EventListingDetail])
def my_events(db: DBSession, user: CurrentUser) -> list[EventListingDetail]:
    rows = (
        db.query(EventListing)
        .filter(EventListing.author_id == user.id)
        .order_by(EventListing.starts_at.asc(), EventListing.created_at.desc())
        .all()
    )
    return [EventListingDetail.model_validate(r) for r in rows]


@router.post("/{event_id}/report", response_model=EventSafetyResponse)
def report_event(
    event_id: str,
    payload: EventReportCreate,
    db: DBSession,
    user: CurrentUser,
) -> EventSafetyResponse:
    event = db.get(EventListing, event_id)
    if not event or event.status != "approved":
        raise HTTPException(status_code=404, detail="Event not found")
    if event.author_id == user.id:
        raise HTTPException(status_code=400, detail="You cannot report your own event")

    existing = db.execute(
        select(EventReport).where(EventReport.event_id == event_id, EventReport.reporter_id == user.id)
    ).scalar_one_or_none()
    if existing:
        return EventSafetyResponse(message="Report already received")

    db.add(
        EventReport(
            event_id=event_id,
            reporter_id=user.id,
            reason=payload.reason.strip().lower(),
            details=payload.details.strip() if payload.details else None,
        )
    )
    event.report_count += 1
    if event.report_count >= 3:
        event.status = "pending"
        event.is_verified = False
    db.add(event)
    db.commit()
    return EventSafetyResponse(message="Report received for moderation")


@router.get("/{event_id}", response_model=EventListingResponse)
def get_event(event_id: str, db: DBSession) -> EventListingResponse:
    """Public event detail omits contact_value; owners still get it via /events/my."""
    event = db.get(EventListing, event_id)
    if not event or event.status != "approved":
        raise HTTPException(status_code=404, detail="Event not found")

    event.view_count += 1
    db.add(event)
    db.commit()
    db.refresh(event)
    return EventListingResponse.model_validate(event)


@router.post("/", response_model=EventListingResponse, status_code=status.HTTP_201_CREATED)
def create_event(
    payload: EventListingCreate,
    bg: BackgroundTasks,
    db: DBSession,
    user: CurrentUser,
) -> EventListingResponse:
    if not user.email_verified:
        raise HTTPException(status_code=403, detail="Verify your email before creating an event")
    if payload.is_private and not _is_premium(user):
        raise HTTPException(status_code=402, detail={"code": "plus_required", "feature": "private_events"})
    event = EventListing(
        title=payload.title,
        description=payload.description,
        category=payload.category.value,
        canton=payload.canton,
        city=payload.city,
        venue_name=payload.venue_name,
        address=payload.address,
        starts_at=payload.starts_at,
        ends_at=payload.ends_at,
        is_free=payload.is_free,
        is_private=payload.is_private,
        price_info=payload.price_info,
        contact_type=payload.contact_type.value,
        contact_value=payload.contact_value,
        organizer_name=payload.organizer_name,
        author_id=user.id,
        status="pending",
    )
    db.add(event)
    db.commit()
    db.refresh(event)

    bg.add_task(moderate_event_listing, event.id)
    return EventListingResponse.model_validate(event)


@router.patch("/{event_id}", response_model=EventListingDetail)
def update_event(
    event_id: str,
    payload: EventListingUpdate,
    db: DBSession,
    user: CurrentUser,
) -> EventListingDetail:
    event = db.get(EventListing, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    is_owner = event.author_id == user.id
    if not is_owner:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    data = payload.model_dump(exclude_unset=True)
    if not data:
        return EventListingDetail.model_validate(event)

    if data.get("is_private") and not _is_premium(user):
        raise HTTPException(status_code=402, detail={"code": "plus_required", "feature": "private_events"})
    for field in ["title", "description", "venue_name", "address", "starts_at", "ends_at", "is_free", "is_private", "price_info"]:
        if field in data:
            setattr(event, field, data[field])

    if event.status == "rejected":
        event.status = "pending"
        event.rejection_reason = None

    db.add(event)
    db.commit()
    db.refresh(event)
    return EventListingDetail.model_validate(event)


@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_event(event_id: str, db: DBSession, user: CurrentUser) -> None:
    event = db.get(EventListing, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    is_admin = getattr(user, "is_superuser", False) or getattr(user, "role", "") == "admin"
    is_owner = event.author_id == user.id
    if not is_owner and not is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    db.delete(event)
    db.commit()


@admin_router.get("/events", response_model=list[EventListingDetail])
def admin_list_events(
    _: CurrentAdmin,
    db: DBSession,
    listing_status: Optional[str] = Query(None, alias="status"),
) -> list[EventListingDetail]:
    stmt = select(EventListing)
    if listing_status:
        stmt = stmt.where(EventListing.status == listing_status)
    rows = db.execute(stmt.order_by(EventListing.starts_at.asc(), EventListing.created_at.desc())).scalars().all()
    return [EventListingDetail.model_validate(r) for r in rows]


@admin_router.patch("/events/{event_id}/approve", response_model=EventListingDetail)
def admin_approve_event(event_id: str, _: CurrentAdmin, db: DBSession) -> EventListingDetail:
    event = db.get(EventListing, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    event.status = "approved"
    event.rejection_reason = None
    event.last_moderated_at = datetime.utcnow()
    # Curated Sweezy events have no community author. Community organizers are
    # moderated, but are not represented as identity-verified.
    event.is_verified = event.author_id is None
    db.add(event)
    db.commit()
    db.refresh(event)
    return EventListingDetail.model_validate(event)


@admin_router.patch("/events/{event_id}/reject", response_model=EventListingDetail)
def admin_reject_event(
    event_id: str,
    payload: Dict[str, Any],
    _: CurrentAdmin,
    db: DBSession,
) -> EventListingDetail:
    reason = payload.get("reason")
    if not reason:
        raise HTTPException(status_code=400, detail="Rejection reason is required")

    event = db.get(EventListing, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    event.status = "rejected"
    event.rejection_reason = reason
    db.add(event)
    db.commit()
    db.refresh(event)
    return EventListingDetail.model_validate(event)


@admin_router.delete("/events/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
def admin_delete_event(event_id: str, _: CurrentAdmin, db: DBSession) -> None:
    event = db.get(EventListing, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    db.delete(event)
    db.commit()
