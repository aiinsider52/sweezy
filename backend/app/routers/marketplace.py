from __future__ import annotations

import math
from typing import Any, Dict, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, or_, select

from ..core.security import decode_token
from ..dependencies import CurrentAdmin, CurrentUser, DBSession
from ..models.marketplace import ServiceListing
from ..schemas.marketplace import (
    AdminServiceListingDetail,
    ServiceCategory,
    ServiceListingCreate,
    ServiceListingDetail,
    ServiceListingPage,
    ServiceListingResponse,
)
from ..services.marketplace_moderation import moderate_listing
from ..services.users import UserService


router = APIRouter()
admin_router = APIRouter()

_optional_bearer = HTTPBearer(auto_error=False)


def _get_optional_user_id(
    db: DBSession,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_optional_bearer),
) -> str | None:
    """Extract user id from a Bearer token when present; return None otherwise."""
    if credentials is None:
        return None
    try:
        payload = decode_token(credentials.credentials)
        email = payload.get("sub")
        if not email:
            return None
        user = UserService.get_by_email(db, email)
        return user.id if user else None
    except Exception:
        return None


# ── Public endpoints ─────────────────────────────────────────────────────────


@router.get("/", response_model=ServiceListingPage)
def list_listings(
    db: DBSession,
    category: Optional[ServiceCategory] = None,
    canton: Optional[str] = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
) -> ServiceListingPage:
    stmt = select(ServiceListing).where(ServiceListing.status == "approved")
    count_stmt = select(func.count()).select_from(ServiceListing).where(ServiceListing.status == "approved")

    if category:
        stmt = stmt.where(ServiceListing.category == category.value)
        count_stmt = count_stmt.where(ServiceListing.category == category.value)
    if canton:
        stmt = stmt.where(ServiceListing.canton == canton)
        count_stmt = count_stmt.where(ServiceListing.canton == canton)

    total: int = db.scalar(count_stmt) or 0
    pages = max(1, math.ceil(total / per_page))
    offset = (page - 1) * per_page

    rows = db.execute(
        stmt.order_by(ServiceListing.created_at.desc()).offset(offset).limit(per_page)
    ).scalars().all()

    return ServiceListingPage(
        items=[ServiceListingResponse.model_validate(r) for r in rows],
        total=total,
        page=page,
        per_page=per_page,
        pages=pages,
    )


@router.get("/my", response_model=list[ServiceListingDetail])
def my_listings(db: DBSession, user: CurrentUser) -> list[ServiceListingDetail]:
    rows = (
        db.query(ServiceListing)
        .filter(or_(ServiceListing.author_id == user.id, ServiceListing.author_id == user.email))
        .order_by(ServiceListing.created_at.desc())
        .all()
    )
    return [ServiceListingDetail.model_validate(r) for r in rows]


@router.get("/{listing_id}", response_model=ServiceListingDetail)
def get_listing(listing_id: str, db: DBSession) -> ServiceListingDetail:
    listing = db.get(ServiceListing, listing_id)
    if not listing or listing.status != "approved":
        raise HTTPException(status_code=404, detail="Listing not found")

    listing.view_count += 1
    db.add(listing)
    db.commit()
    db.refresh(listing)

    return ServiceListingDetail.model_validate(listing)


@router.post("/", response_model=ServiceListingResponse, status_code=status.HTTP_201_CREATED)
def create_listing(
    payload: ServiceListingCreate,
    bg: BackgroundTasks,
    db: DBSession,
    user_id: str | None = Depends(_get_optional_user_id),
) -> ServiceListingResponse:
    listing = ServiceListing(
        title=payload.title,
        description=payload.description,
        category=payload.category.value,
        canton=payload.canton,
        price_info=payload.price_info,
        contact_type=payload.contact_type.value,
        contact_value=payload.contact_value,
        author_id=user_id,
        author_name=payload.author_name,
        status="pending",
    )
    db.add(listing)
    db.commit()
    db.refresh(listing)

    bg.add_task(moderate_listing, listing.id)

    return ServiceListingResponse.model_validate(listing)


@router.delete("/{listing_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_listing(listing_id: str, db: DBSession, user: CurrentUser) -> None:
    listing = db.get(ServiceListing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    is_admin = getattr(user, "is_superuser", False) or getattr(user, "role", "") == "admin"
    is_owner = listing.author_id in {user.id, getattr(user, "email", None)}
    if not is_owner and not is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    db.delete(listing)
    db.commit()


# ── Admin endpoints ──────────────────────────────────────────────────────────


@admin_router.get("/marketplace", response_model=list[AdminServiceListingDetail])
def admin_list_listings(
    _: CurrentAdmin,
    db: DBSession,
    listing_status: Optional[str] = Query(None, alias="status"),
) -> list[AdminServiceListingDetail]:
    stmt = select(ServiceListing)
    if listing_status:
        stmt = stmt.where(ServiceListing.status == listing_status)
    rows = db.execute(stmt.order_by(ServiceListing.created_at.desc())).scalars().all()
    return [AdminServiceListingDetail.model_validate(r) for r in rows]


@admin_router.patch("/marketplace/{listing_id}/approve", response_model=AdminServiceListingDetail)
def admin_approve_listing(
    listing_id: str, _: CurrentAdmin, db: DBSession
) -> AdminServiceListingDetail:
    listing = db.get(ServiceListing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    listing.status = "approved"
    listing.rejection_reason = None
    db.add(listing)
    db.commit()
    db.refresh(listing)
    return AdminServiceListingDetail.model_validate(listing)


@admin_router.patch("/marketplace/{listing_id}/reject", response_model=AdminServiceListingDetail)
def admin_reject_listing(
    listing_id: str,
    payload: Dict[str, Any],
    _: CurrentAdmin,
    db: DBSession,
) -> AdminServiceListingDetail:
    reason = payload.get("reason")
    if not reason:
        raise HTTPException(status_code=400, detail="Rejection reason is required")

    listing = db.get(ServiceListing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    listing.status = "rejected"
    listing.rejection_reason = reason
    db.add(listing)
    db.commit()
    db.refresh(listing)
    return AdminServiceListingDetail.model_validate(listing)
