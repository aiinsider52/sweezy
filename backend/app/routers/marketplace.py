import math
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, or_, select

from ..core.security import decode_token
from ..dependencies import CurrentAdmin, CurrentUser, DBSession
from ..models.marketplace import MarketplaceBlock, MarketplaceReport, ServiceListing
from ..schemas.marketplace import (
    AdminServiceListingDetail,
    ListingType,
    MarketplaceReportCreate,
    MarketplaceSafetyResponse,
    ServiceListingCreate,
    ServiceListingDetail,
    ServiceListingPage,
    ServiceListingResponse,
    ServiceListingUpdate,
)
from ..services.marketplace_moderation import moderate_listing
from ..services.users import UserService


router = APIRouter()
admin_router = APIRouter()

_optional_bearer = HTTPBearer(auto_error=False)


def _ensure_ai_metadata(listing: ServiceListing) -> bool:
    if listing.ai_score is not None:
        return False

    from ..services.marketplace_moderation import _fallback_score

    _, _, score, score_reason = _fallback_score(listing)
    listing.ai_score = score
    listing.ai_score_reason = score_reason
    return True


def _apply_trust_payload(listing: ServiceListing, payload: Dict[str, Any]) -> None:
    is_verified = bool(payload.get("is_verified", listing.is_verified))
    is_featured = bool(payload.get("is_featured", listing.is_featured))
    partner_label = payload.get("partner_label")
    moderation_notes = payload.get("moderation_notes")

    listing.is_verified = is_verified or is_featured
    listing.is_featured = is_featured
    listing.trust_level = "partner" if is_featured else ("verified" if is_verified else "community")
    if isinstance(partner_label, str):
        listing.partner_label = partner_label.strip()[:80] or None
    if isinstance(moderation_notes, str):
        listing.moderation_notes = moderation_notes.strip() or None

    # Expert profile fields (optional). When provided, also implies verified.
    if "is_expert" in payload:
        listing.is_expert = bool(payload.get("is_expert"))
        if listing.is_expert:
            listing.is_verified = True
    specialty = payload.get("expert_specialty")
    if isinstance(specialty, str):
        listing.expert_specialty = specialty.strip().lower()[:40] or None
    langs = payload.get("expert_languages")
    if isinstance(langs, list):
        listing.expert_languages = [str(x)[:10].lower() for x in langs if isinstance(x, (str, int))][:8]
    response_hours = payload.get("response_time_hours")
    if isinstance(response_hours, int) and response_hours > 0:
        listing.response_time_hours = min(response_hours, 24 * 14)
    elif response_hours is None and "response_time_hours" in payload:
        listing.response_time_hours = None
    bio = payload.get("expert_bio")
    if isinstance(bio, str):
        listing.expert_bio = bio.strip()[:4000] or None


def _get_optional_user_id(
    db: DBSession,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_optional_bearer),
) -> str | None:
    """Extract user id from a Bearer token when present; return None otherwise."""
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


# ── Public endpoints ─────────────────────────────────────────────────────────


@router.get("/", response_model=ServiceListingPage)
def list_listings(
    db: DBSession,
    user_id: str | None = Depends(_get_optional_user_id),
    category: Optional[str] = Query(None, min_length=2, max_length=30),
    canton: Optional[str] = None,
    listing_type: Optional[ListingType] = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
) -> ServiceListingPage:
    stmt = select(ServiceListing).where(ServiceListing.status == "approved")
    count_stmt = select(func.count()).select_from(ServiceListing).where(ServiceListing.status == "approved")

    if user_id:
        blocked_authors = select(MarketplaceBlock.blocked_author_id).where(MarketplaceBlock.user_id == user_id)
        visible = or_(ServiceListing.author_id.is_(None), ServiceListing.author_id.not_in(blocked_authors))
        stmt = stmt.where(visible)
        count_stmt = count_stmt.where(visible)

    if listing_type:
        stmt = stmt.where(ServiceListing.listing_type == listing_type.value)
        count_stmt = count_stmt.where(ServiceListing.listing_type == listing_type.value)
    if category:
        stmt = stmt.where(ServiceListing.category == category)
        count_stmt = count_stmt.where(ServiceListing.category == category)
    if canton:
        stmt = stmt.where(ServiceListing.canton == canton)
        count_stmt = count_stmt.where(ServiceListing.canton == canton)

    total: int = db.scalar(count_stmt) or 0
    pages = max(1, math.ceil(total / per_page))
    offset = (page - 1) * per_page

    rows = db.execute(
        stmt.order_by(ServiceListing.is_featured.desc(), ServiceListing.is_verified.desc(), ServiceListing.created_at.desc())
        .offset(offset)
        .limit(per_page)
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
        .filter(ServiceListing.author_id == user.id)
        .order_by(ServiceListing.created_at.desc())
        .all()
    )
    return [ServiceListingDetail.model_validate(r) for r in rows]


@router.get("/blocked", response_model=list[str])
def blocked_authors(db: DBSession, user: CurrentUser) -> list[str]:
    return list(
        db.execute(
            select(MarketplaceBlock.blocked_author_id).where(MarketplaceBlock.user_id == user.id)
        ).scalars().all()
    )


@router.get("/{listing_id}", response_model=ServiceListingResponse)
def get_listing(listing_id: str, db: DBSession) -> ServiceListingResponse:
    listing = db.get(ServiceListing, listing_id)
    if not listing or listing.status != "approved":
        raise HTTPException(status_code=404, detail="Listing not found")

    listing.view_count += 1
    db.add(listing)
    db.commit()
    db.refresh(listing)

    # Public listing details intentionally exclude the external contact value.
    # Buyers contact sellers through the moderated in-app conversation flow.
    return ServiceListingResponse.model_validate(listing)


@router.post("/{listing_id}/report", response_model=MarketplaceSafetyResponse)
def report_listing(
    listing_id: str,
    payload: MarketplaceReportCreate,
    db: DBSession,
    user: CurrentUser,
) -> MarketplaceSafetyResponse:
    listing = db.get(ServiceListing, listing_id)
    if not listing or listing.status != "approved":
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.author_id == user.id:
        raise HTTPException(status_code=400, detail="You cannot report your own listing")

    existing = db.execute(
        select(MarketplaceReport).where(
            MarketplaceReport.listing_id == listing_id,
            MarketplaceReport.reporter_id == user.id,
        )
    ).scalar_one_or_none()
    if existing:
        return MarketplaceSafetyResponse(message="Report already received")

    db.add(
        MarketplaceReport(
            listing_id=listing_id,
            reporter_id=user.id,
            reason=payload.reason.strip().lower(),
            details=payload.details.strip() if payload.details else None,
        )
    )
    listing.report_count += 1
    if listing.report_count >= 3:
        listing.is_featured = False
        listing.trust_level = "review"
    db.add(listing)
    db.commit()
    return MarketplaceSafetyResponse(message="Report received for moderation")


@router.post("/{listing_id}/block", response_model=MarketplaceSafetyResponse)
def block_listing_author(listing_id: str, db: DBSession, user: CurrentUser) -> MarketplaceSafetyResponse:
    listing = db.get(ServiceListing, listing_id)
    if not listing or not listing.author_id:
        raise HTTPException(status_code=404, detail="Listing author not found")
    if listing.author_id == user.id:
        raise HTTPException(status_code=400, detail="You cannot block yourself")

    existing = db.execute(
        select(MarketplaceBlock).where(
            MarketplaceBlock.user_id == user.id,
            MarketplaceBlock.blocked_author_id == listing.author_id,
        )
    ).scalar_one_or_none()
    if not existing:
        db.add(MarketplaceBlock(user_id=user.id, blocked_author_id=listing.author_id))
        db.commit()
    return MarketplaceSafetyResponse(message="Author blocked")


@router.delete("/blocked/{author_id}", response_model=MarketplaceSafetyResponse)
def unblock_author(author_id: str, db: DBSession, user: CurrentUser) -> MarketplaceSafetyResponse:
    row = db.execute(
        select(MarketplaceBlock).where(
            MarketplaceBlock.user_id == user.id,
            MarketplaceBlock.blocked_author_id == author_id,
        )
    ).scalar_one_or_none()
    if row:
        db.delete(row)
        db.commit()
    return MarketplaceSafetyResponse(message="Author unblocked")


@router.post("/", response_model=ServiceListingResponse, status_code=status.HTTP_201_CREATED)
def create_listing(
    payload: ServiceListingCreate,
    bg: BackgroundTasks,
    db: DBSession,
    user: CurrentUser,
) -> ServiceListingResponse:
    listing = ServiceListing(
        listing_type=payload.listing_type.value,
        title=payload.title,
        description=payload.description,
        category=payload.category,
        canton=payload.canton,
        price_info=payload.price_info,
        price_chf=payload.price_chf,
        is_free=payload.is_free,
        condition=payload.condition.value if payload.condition else None,
        negotiable=payload.negotiable,
        contact_type=payload.contact_type.value,
        contact_value=payload.contact_value,
        image_urls=payload.image_urls,
        author_id=user.id,
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
    is_owner = listing.author_id == user.id
    if not is_owner and not is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    db.delete(listing)
    db.commit()


@router.patch("/{listing_id}", response_model=ServiceListingDetail)
def update_listing(
    listing_id: str,
    payload: ServiceListingUpdate,
    db: DBSession,
    user: CurrentUser,
) -> ServiceListingDetail:
    listing = db.get(ServiceListing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    is_owner = listing.author_id == user.id
    if not is_owner:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    data = payload.model_dump(exclude_unset=True)
    if not data:
        return ServiceListingDetail.model_validate(listing)

    if "title" in data:
        listing.title = data["title"]
    if "description" in data:
        listing.description = data["description"]
    if "price_info" in data:
        listing.price_info = data["price_info"]
    if "price_chf" in data:
        listing.price_chf = data["price_chf"]
    if "is_free" in data and data["is_free"] is not None:
        listing.is_free = data["is_free"]
        if listing.is_free:
            listing.price_chf = None
    if "condition" in data:
        listing.condition = data["condition"].value if data["condition"] else None
    if "negotiable" in data and data["negotiable"] is not None:
        listing.negotiable = data["negotiable"]
    if "image_urls" in data and data["image_urls"] is not None:
        listing.image_urls = data["image_urls"]

    if listing.status == "rejected":
        listing.status = "pending"
        listing.rejection_reason = None

    db.add(listing)
    db.commit()
    db.refresh(listing)
    return ServiceListingDetail.model_validate(listing)


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

    updated = False
    for row in rows:
        if _ensure_ai_metadata(row):
            updated = True

    if updated:
        db.commit()
        for row in rows:
            db.refresh(row)

    return [AdminServiceListingDetail.model_validate(r) for r in rows]


@admin_router.patch("/marketplace/{listing_id}/approve", response_model=AdminServiceListingDetail)
def admin_approve_listing(
    listing_id: str,
    _: CurrentAdmin,
    db: DBSession,
    payload: Dict[str, Any] | None = None,
) -> AdminServiceListingDetail:
    listing = db.get(ServiceListing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    listing.status = "approved"
    listing.rejection_reason = None
    listing.report_count = 0
    listing.last_moderated_at = datetime.now(timezone.utc)
    _apply_trust_payload(listing, payload or {})
    _ensure_ai_metadata(listing)
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
    listing.last_moderated_at = datetime.now(timezone.utc)
    _ensure_ai_metadata(listing)
    db.add(listing)
    db.commit()
    db.refresh(listing)
    return AdminServiceListingDetail.model_validate(listing)


@admin_router.delete("/marketplace/{listing_id}", status_code=status.HTTP_204_NO_CONTENT)
def admin_delete_listing(
    listing_id: str,
    _: CurrentAdmin,
    db: DBSession,
) -> None:
    listing = db.get(ServiceListing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    db.delete(listing)
    db.commit()
