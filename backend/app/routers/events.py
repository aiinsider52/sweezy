from __future__ import annotations

import math
from datetime import datetime
from typing import Any, Dict, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, or_, select

from ..core.security import decode_token
from ..dependencies import CurrentAdmin, CurrentUser, DBSession
from ..models.event_listing import EventListing
from ..schemas.events import (
    EventCategory,
    EventListingCreate,
    EventListingDetail,
    EventListingPage,
    EventListingResponse,
    EventListingUpdate,
)
from ..services.events_moderation import moderate_event_listing
from ..services.users import UserService


router = APIRouter()
admin_router = APIRouter()

_optional_bearer = HTTPBearer(auto_error=False)


def _get_optional_user_id(
    db: DBSession,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_optional_bearer),
) -> str | None:
    if credentials is None:
        return None
    try:
        payload = decode_token(credentials.credentials)
        email = payload.get("sub")
        if not email:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authentication")
        user = UserService.get_by_email(db, email)
        if not user:
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
) -> EventListingPage:
    stmt = select(EventListing).where(EventListing.status == "approved")
    count_stmt = select(func.count()).select_from(EventListing).where(EventListing.status == "approved")

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
        .filter(or_(EventListing.author_id == user.id, EventListing.author_id == user.email))
        .order_by(EventListing.starts_at.asc(), EventListing.created_at.desc())
        .all()
    )
    return [EventListingDetail.model_validate(r) for r in rows]


@router.get("/{event_id}", response_model=EventListingDetail)
def get_event(event_id: str, db: DBSession) -> EventListingDetail:
    event = db.get(EventListing, event_id)
    if not event or event.status != "approved":
        raise HTTPException(status_code=404, detail="Event not found")

    event.view_count += 1
    db.add(event)
    db.commit()
    db.refresh(event)
    return EventListingDetail.model_validate(event)


@router.post("/", response_model=EventListingResponse, status_code=status.HTTP_201_CREATED)
def create_event(
    payload: EventListingCreate,
    bg: BackgroundTasks,
    db: DBSession,
    user: CurrentUser,
) -> EventListingResponse:
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

    is_owner = event.author_id in {user.id, getattr(user, "email", None)}
    if not is_owner:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    data = payload.model_dump(exclude_unset=True)
    if not data:
        return EventListingDetail.model_validate(event)

    for field in ["title", "description", "venue_name", "address", "starts_at", "ends_at", "is_free", "price_info"]:
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
    is_owner = event.author_id in {user.id, getattr(user, "email", None)}
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
