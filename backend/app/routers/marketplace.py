import math
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import and_, func, or_, select

from ..core.security import decode_token
from ..core.rate_limit import limiter
from ..dependencies import CurrentAdmin, CurrentUser, DBSession
from ..models.chat import ChatConversation, MarketplaceReview
from ..models.marketplace import MarketplaceBlock, MarketplaceReport, ServiceListing
from ..models.user import PublicUserProfile, User
from ..schemas.marketplace import (
    AdminServiceListingDetail,
    ListingType,
    MarketplaceReportCreate,
    MarketplaceProClient,
    MarketplaceProDashboard,
    MarketplaceSafetyResponse,
    PublicProfileListing,
    PublicUserProfileResponse,
    ServiceListingCreate,
    ServiceListingDetail,
    ServiceListingPage,
    ServiceListingResponse,
    ServiceListingUpdate,
)
from ..services.marketplace_moderation import moderate_listing
from ..services.users import UserService
from ..services.moderation import ensure_case


router = APIRouter()
admin_router = APIRouter()

_optional_bearer = HTTPBearer(auto_error=False)


def _premium(user: User) -> bool:
    if (user.subscription_status or "free") not in {"trial", "premium"}:
        return False
    expires = user.subscription_expire_at
    if expires is None:
        return True
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    return expires > datetime.now(timezone.utc)


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
    now = datetime.now(timezone.utc)
    expired = db.execute(select(ServiceListing).where(
        ServiceListing.is_featured.is_(True),
        ServiceListing.featured_until.is_not(None),
        ServiceListing.featured_until <= now,
    )).scalars().all()
    if expired:
        for item in expired:
            item.is_featured = False
            item.featured_until = None
            if item.trust_level == "plus_pro": item.trust_level = "community"
        db.commit()
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


@router.get("/pro/dashboard", response_model=MarketplaceProDashboard)
def pro_dashboard(db: DBSession, user: CurrentUser) -> MarketplaceProDashboard:
    if not _premium(user):
        raise HTTPException(status_code=402, detail={"code": "plus_required", "feature": "marketplace_pro"})
    listings = db.execute(select(ServiceListing).where(ServiceListing.author_id == user.id)).scalars().all()
    conversations = db.execute(select(ChatConversation).where(
        ChatConversation.seller_id == user.id,
        ChatConversation.listing_id.is_not(None),
    ).order_by(ChatConversation.last_message_at.desc().nullslast(), ChatConversation.created_at.desc()).limit(50)).scalars().all()
    buyer_ids = {item.buyer_id for item in conversations}
    profiles = db.execute(
        select(PublicUserProfile).where(PublicUserProfile.user_id.in_(buyer_ids))
    ).scalars().all() if buyer_ids else []
    display_names = {profile.user_id: profile.display_name for profile in profiles}
    clients = [MarketplaceProClient(
        conversation_id=item.id,
        display_name=display_names.get(item.buyer_id, "Sweezy client"),
        listing_title=item.listing_title,
        last_message_preview=item.last_message_preview,
        last_message_at=item.last_message_at,
    ) for item in conversations]
    return MarketplaceProDashboard(
        total_listings=len(listings),
        active_listings=sum(item.status == "approved" for item in listings),
        total_views=sum(item.view_count for item in listings),
        inquiries=len(conversations),
        publication_limit=20,
        clients=clients,
    )


@router.post("/{listing_id}/promote", response_model=ServiceListingDetail)
def promote_listing(listing_id: str, db: DBSession, user: CurrentUser) -> ServiceListingDetail:
    if not _premium(user):
        raise HTTPException(status_code=402, detail={"code": "plus_required", "feature": "listing_promotion"})
    listing = db.get(ServiceListing, listing_id)
    if not listing or listing.author_id != user.id:
        raise HTTPException(404, "Listing not found")
    if listing.status != "approved":
        raise HTTPException(409, "Only approved listings can be promoted")
    listing.is_featured = True
    listing.featured_until = datetime.now(timezone.utc) + timedelta(days=7)
    if not listing.is_verified:
        listing.trust_level = "plus_pro"
    db.add(listing); db.commit(); db.refresh(listing)
    return ServiceListingDetail.model_validate(listing)


@router.get("/blocked", response_model=list[str])
def blocked_authors(db: DBSession, user: CurrentUser) -> list[str]:
    return list(
        db.execute(
            select(MarketplaceBlock.blocked_author_id).where(MarketplaceBlock.user_id == user.id)
        ).scalars().all()
    )


@router.get("/profiles/{profile_user_id}", response_model=PublicUserProfileResponse)
@limiter.limit("30/minute")
def public_profile(
    request: Request,
    profile_user_id: str,
    db: DBSession,
    user: CurrentUser,
    listing_id: str | None = None,
    conversation_id: str | None = None,
) -> PublicUserProfileResponse:
    target = db.get(User, profile_user_id)
    blocked = db.scalar(
        select(func.count()).select_from(MarketplaceBlock).where(
            or_(
                and_(MarketplaceBlock.user_id == user.id, MarketplaceBlock.blocked_author_id == profile_user_id),
                and_(MarketplaceBlock.user_id == profile_user_id, MarketplaceBlock.blocked_author_id == user.id),
            )
        )
    ) or 0
    legitimate = False
    if listing_id:
        legitimate = (db.scalar(
            select(func.count()).select_from(ServiceListing).where(
                ServiceListing.id == listing_id,
                ServiceListing.author_id == profile_user_id,
                ServiceListing.status == "approved",
            )
        ) or 0) > 0
    if conversation_id:
        legitimate = legitimate or (db.scalar(
            select(func.count()).select_from(ChatConversation).where(
                ChatConversation.id == conversation_id,
                or_(
                    and_(ChatConversation.buyer_id == user.id, ChatConversation.seller_id == profile_user_id),
                    and_(ChatConversation.seller_id == user.id, ChatConversation.buyer_id == profile_user_id),
                ),
            )
        ) or 0) > 0
    if not target or not target.is_active or blocked or not legitimate:
        raise HTTPException(status_code=404, detail="Profile not found")

    profile = db.get(PublicUserProfile, profile_user_id)
    if not profile:
        latest = db.execute(
            select(ServiceListing).where(
                ServiceListing.author_id == profile_user_id,
                ServiceListing.status == "approved",
            ).order_by(ServiceListing.updated_at.desc())
        ).scalars().first()
        if not latest:
            raise HTTPException(status_code=404, detail="Profile not found")
        profile = PublicUserProfile(
            user_id=profile_user_id,
            display_name=latest.author_name.strip()[:100] or "Sweezy user",
            is_verified=target.email_verified,
        )
        db.add(profile)
        db.commit()
        db.refresh(profile)

    listings = db.execute(
        select(ServiceListing).where(
            ServiceListing.author_id == profile_user_id,
            ServiceListing.status == "approved",
        ).order_by(ServiceListing.is_featured.desc(), ServiceListing.created_at.desc()).limit(20)
    ).scalars().all()
    average, review_count = db.execute(
        select(func.avg(MarketplaceReview.rating), func.count(MarketplaceReview.id)).where(
            MarketplaceReview.reviewed_user_id == profile_user_id
        )
    ).one()
    words = [word for word in profile.display_name.split() if word]
    initials = "".join(word[0].upper() for word in words[:2]) or "S"
    badges = []
    if profile.is_verified:
        badges.append("verified")
    if profile.trust_badge:
        badges.append(profile.trust_badge)
    if any(item.is_expert for item in listings):
        badges.append("expert")
    return PublicUserProfileResponse(
        user_id=profile_user_id,
        display_name=profile.display_name,
        initials=initials,
        avatar_url=profile.avatar_url,
        registered_month=target.created_at.strftime("%Y-%m"),
        is_verified=profile.is_verified,
        trust_badges=badges,
        average_rating=round(float(average), 2) if average is not None else None,
        review_count=review_count,
        active_listings=[PublicProfileListing.model_validate(item) for item in listings],
        viewer_has_blocked=False,
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

    report = MarketplaceReport(
            listing_id=listing_id,
            reporter_id=user.id,
            reason=payload.reason.strip().lower(),
            details=payload.details.strip() if payload.details else None,
        )
    db.add(report)
    db.flush()
    ensure_case(db, source_type="marketplace_listing", source_id=listing.id, subject_user_id=listing.author_id, reporter_id=user.id, reason=payload.reason, details=payload.details, context={"legacy_report_id": report.id, "title": listing.title, "listing_type": listing.listing_type})
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
    if not user.email_verified:
        raise HTTPException(status_code=403, detail="Verify your email before creating a listing")
    current_count = db.scalar(select(func.count()).select_from(ServiceListing).where(
        ServiceListing.author_id == user.id,
        ServiceListing.status.in_(("pending", "approved")),
    )) or 0
    publication_limit = 20 if _premium(user) else 3
    if current_count >= publication_limit:
        code = "publication_limit" if _premium(user) else "plus_required"
        raise HTTPException(status_code=409 if _premium(user) else 402,
            detail={"code": code, "feature": "marketplace_publications", "limit": publication_limit})
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
    profile = db.get(PublicUserProfile, user.id)
    if profile is None:
        db.add(PublicUserProfile(
            user_id=user.id,
            display_name=payload.author_name.strip()[:100],
            is_verified=user.email_verified,
        ))
    elif profile.display_name != payload.author_name.strip():
        listing.author_name = profile.display_name
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
