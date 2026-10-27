from __future__ import annotations

from datetime import timedelta

from fastapi import APIRouter, HTTPException, Query, Request, Response
from sqlalchemy import func, or_, select

from ..core.config import get_settings
from ..core.rate_limit import limiter
from ..dependencies import CurrentAdmin, CurrentUser, DBSession
from ..models.business import (
    BusinessBooking,
    BusinessClient,
    BusinessClubMember,
    BusinessOffer,
    BusinessProfile,
    BusinessReview,
    BusinessService,
    BusinessStatDaily,
)
from ..models.user import PublicUserProfile, User
from ..schemas.business import (
    AdminBusinessReviewModeration,
    BusinessAppleTransaction,
    BusinessDirectoryResponse,
    BusinessOfferCreate,
    BusinessOfferResponse,
    BusinessOfferUpdate,
    BusinessPlanLimits,
    BusinessPlanResponse,
    BusinessReviewCreate,
    BusinessReviewEligibility,
    BusinessReviewReply,
    BusinessReviewResponse,
    BusinessStatsDay,
    BusinessStatsResponse,
    BusinessSummary,
    BusinessTrackEvent,
    ClubMemberResponse,
    ClubMembershipUpdate,
    PublicOfferResponse,
)
from ..services import apple_iap_service
from ..services.business_directory import active_offers_query, summarize, top_offer_labels
from ..services.business_plans import (
    CONTEXT_TOPICS,
    PLAN_LIMITS,
    BusinessPurchaseError,
    apply_business_transaction,
    effective_plan,
    is_boosted,
    limits_dict,
    limits_for,
    now_utc,
    ranking_key,
    record_stat,
    refresh_rating,
    require_plan,
)
from ..services.push_notifications import enqueue_account_notification


public_router = APIRouter()
owner_router = APIRouter()
admin_router = APIRouter()

ACTION_METRICS = ("call", "website", "route", "message", "booking", "offer", "share")


def _own_profile(db: DBSession, user_id: str) -> BusinessProfile:
    profile = db.get(BusinessProfile, user_id)
    if not profile:
        raise HTTPException(status_code=404, detail={"code": "business_profile_required"})
    return profile


def _public_profile(db: DBSession, user_id: str) -> BusinessProfile:
    profile = db.get(BusinessProfile, user_id)
    owner = db.get(User, user_id)
    if not profile or not owner or not owner.is_active or profile.status != "approved":
        raise HTTPException(status_code=404, detail="Business not found")
    return profile


def _matching_profiles(
    db: DBSession,
    *,
    country: str | None,
    subdivision: str | None,
    city: str | None,
    categories: tuple[str, ...] | None,
    kind: str | None,
    language: str | None,
    q: str | None,
    verified: bool,
    with_location: bool,
) -> list[BusinessProfile]:
    stmt = select(BusinessProfile).join(User, User.id == BusinessProfile.user_id).where(
        BusinessProfile.status == "approved",
        User.is_active.is_(True),
    )
    if country:
        stmt = stmt.where(BusinessProfile.country_code == country.upper())
    if subdivision:
        stmt = stmt.where(BusinessProfile.subdivision_code == subdivision.upper())
    if city:
        stmt = stmt.where(func.lower(BusinessProfile.city) == city.strip().lower())
    if categories:
        stmt = stmt.where(BusinessProfile.category.in_(categories))
    if kind:
        stmt = stmt.where(BusinessProfile.kind == kind)
    if verified:
        stmt = stmt.where(BusinessProfile.is_verified.is_(True))
    if with_location:
        stmt = stmt.where(BusinessProfile.latitude.is_not(None), BusinessProfile.longitude.is_not(None))
    if q and q.strip():
        pattern = f"%{q.strip().lower()}%"
        stmt = stmt.where(or_(
            func.lower(BusinessProfile.display_name).like(pattern),
            func.lower(func.coalesce(BusinessProfile.tagline, "")).like(pattern),
            func.lower(BusinessProfile.description).like(pattern),
        ))
    rows = db.execute(stmt.limit(1000)).scalars().all()
    if language:
        wanted = language.strip().lower()
        rows = [row for row in rows if wanted in [item.lower() for item in (row.languages or [])]]
    return sorted(rows, key=ranking_key, reverse=True)


def _summaries(db: DBSession, profiles: list[BusinessProfile]) -> list[BusinessSummary]:
    labels = top_offer_labels(db, [profile.user_id for profile in profiles])
    return [summarize(profile, top_offer_label=labels.get(profile.user_id)) for profile in profiles]


# MARK: - Public discovery


@public_router.get("/directory", response_model=BusinessDirectoryResponse)
def business_directory(
    db: DBSession,
    country: str | None = Query(default=None, min_length=2, max_length=2),
    subdivision: str | None = Query(default=None, max_length=10),
    city: str | None = Query(default=None, max_length=100),
    category: str | None = Query(default=None, max_length=40),
    kind: str | None = Query(default=None, pattern="^(business|specialist|club)$"),
    language: str | None = Query(default=None, max_length=10),
    q: str | None = Query(default=None, max_length=100),
    verified: bool = False,
    with_location: bool = False,
    limit: int = Query(default=30, ge=1, le=500),
    offset: int = Query(default=0, ge=0, le=5000),
) -> BusinessDirectoryResponse:
    rows = _matching_profiles(
        db,
        country=country,
        subdivision=subdivision,
        city=city,
        categories=(category,) if category else None,
        kind=kind,
        language=language,
        q=q,
        verified=verified,
        with_location=with_location,
    )
    return BusinessDirectoryResponse(items=_summaries(db, rows[offset:offset + limit]), total=len(rows))


@public_router.get("/contextual", response_model=list[BusinessSummary])
def contextual_businesses(
    db: DBSession,
    topic: str = Query(min_length=2, max_length=40),
    country: str | None = Query(default=None, min_length=2, max_length=2),
    subdivision: str | None = Query(default=None, max_length=10),
    limit: int = Query(default=3, ge=1, le=10),
) -> list[BusinessSummary]:
    categories = CONTEXT_TOPICS.get(topic.lower())
    if not categories:
        return []
    rows = _matching_profiles(
        db,
        country=country,
        subdivision=None,
        city=None,
        categories=categories,
        kind=None,
        language=None,
        q=None,
        verified=False,
        with_location=False,
    )
    if subdivision:
        # Same canton/Land first, the rest of the country after.
        local = subdivision.upper()
        rows = sorted(rows, key=lambda row: row.subdivision_code == local, reverse=True)
    return _summaries(db, rows[:limit])


@public_router.get("/offers", response_model=list[PublicOfferResponse])
def offers_feed(
    db: DBSession,
    country: str | None = Query(default=None, min_length=2, max_length=2),
    subdivision: str | None = Query(default=None, max_length=10),
    limit: int = Query(default=30, ge=1, le=100),
) -> list[PublicOfferResponse]:
    offers = db.execute(active_offers_query().limit(500)).scalars().all()
    owners = {
        profile.user_id: profile
        for profile in _matching_profiles(
            db,
            country=country,
            subdivision=subdivision,
            city=None,
            categories=None,
            kind=None,
            language=None,
            q=None,
            verified=False,
            with_location=False,
        )
    }
    visible = [offer for offer in offers if offer.business_user_id in owners]
    visible.sort(key=lambda offer: (is_boosted(owners[offer.business_user_id]), offer.created_at), reverse=True)
    return [
        PublicOfferResponse(
            **BusinessOfferResponse.model_validate(offer).model_dump(),
            business=summarize(owners[offer.business_user_id], top_offer_label=offer.discount_label),
        )
        for offer in visible[:limit]
    ]


@public_router.post("/{user_id}/track", status_code=204)
@limiter.limit("60/minute")
def track_business_event(request: Request, user_id: str, payload: BusinessTrackEvent, db: DBSession) -> Response:
    _public_profile(db, user_id)
    record_stat(db, user_id, payload.event)
    return Response(status_code=204)


@public_router.get("/{user_id}/reviews", response_model=list[BusinessReviewResponse])
def business_reviews(
    user_id: str,
    db: DBSession,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[BusinessReview]:
    _public_profile(db, user_id)
    return db.execute(
        select(BusinessReview)
        .where(BusinessReview.business_user_id == user_id, BusinessReview.status == "published")
        .order_by(BusinessReview.created_at.desc())
        .offset(offset)
        .limit(limit)
    ).scalars().all()


def _visited_booking(db: DBSession, business_user_id: str, customer_id: str) -> BusinessBooking | None:
    return db.execute(
        select(BusinessBooking)
        .join(BusinessClient, BusinessClient.id == BusinessBooking.client_id)
        .where(
            BusinessBooking.business_user_id == business_user_id,
            BusinessClient.customer_user_id == customer_id,
            BusinessBooking.status.in_(["confirmed", "completed"]),
            BusinessBooking.starts_at <= now_utc(),
        )
        .order_by(BusinessBooking.starts_at.desc())
        .limit(1)
    ).scalar_one_or_none()


def _own_review(db: DBSession, business_user_id: str, author_id: str) -> BusinessReview | None:
    return db.execute(
        select(BusinessReview).where(
            BusinessReview.business_user_id == business_user_id,
            BusinessReview.author_id == author_id,
        )
    ).scalar_one_or_none()


@public_router.get("/{user_id}/reviews/eligibility", response_model=BusinessReviewEligibility)
def review_eligibility(user_id: str, db: DBSession, user: CurrentUser) -> BusinessReviewEligibility:
    _public_profile(db, user_id)
    existing = _own_review(db, user_id, user.id)
    if user.id == user_id:
        return BusinessReviewEligibility(can_review=False, reason="own_business")
    if existing:
        return BusinessReviewEligibility(can_review=True, existing=BusinessReviewResponse.model_validate(existing))
    if _visited_booking(db, user_id, user.id) is None:
        return BusinessReviewEligibility(can_review=False, reason="review_requires_visit")
    return BusinessReviewEligibility(can_review=True)


@public_router.post("/{user_id}/reviews", response_model=BusinessReviewResponse, status_code=201)
@limiter.limit("10/hour")
def write_review(
    request: Request,
    user_id: str,
    payload: BusinessReviewCreate,
    db: DBSession,
    user: CurrentUser,
) -> BusinessReview:
    profile = _public_profile(db, user_id)
    if user.id == user_id:
        raise HTTPException(status_code=409, detail={"code": "cannot_review_own_business"})
    review = _own_review(db, user_id, user.id)
    booking = _visited_booking(db, user_id, user.id)
    if review is None and booking is None:
        raise HTTPException(status_code=403, detail={"code": "review_requires_visit"})
    if review is not None and review.status == "hidden":
        raise HTTPException(status_code=409, detail={"code": "review_hidden_by_moderation"})
    display = db.get(PublicUserProfile, user.id)
    author_name = (display.display_name if display and display.display_name else "Sweezy user")[:120]
    if review is None:
        review = BusinessReview(
            business_user_id=user_id,
            author_id=user.id,
            booking_id=booking.id if booking else None,
            author_name=author_name,
            rating=payload.rating,
            text=payload.text,
        )
    else:
        review.rating = payload.rating
        review.text = payload.text
        review.author_name = author_name
    db.add(review)
    db.flush()
    refresh_rating(db, user_id)
    enqueue_account_notification(
        db,
        event_key=f"business-review:{review.id}:{payload.rating}:{len(payload.text)}",
        recipient_id=profile.user_id,
        event_type="business_review",
        title="Новий відгук",
        body=f"{author_name}: {'★' * payload.rating}",
        data={"business_user_id": user_id, "review_id": review.id},
    )
    db.commit()
    db.refresh(review)
    return review


# MARK: - Owner: plan, stats, offers, reviews, clubs


def _plan_response(db: DBSession, profile: BusinessProfile) -> BusinessPlanResponse:
    plan = effective_plan(profile)
    services = db.scalar(select(func.count()).select_from(BusinessService).where(BusinessService.business_user_id == profile.user_id)) or 0
    offers = db.scalar(
        select(func.count()).select_from(BusinessOffer).where(
            BusinessOffer.business_user_id == profile.user_id,
            BusinessOffer.is_active.is_(True),
        )
    ) or 0
    return BusinessPlanResponse(
        plan=profile.plan if profile.plan in PLAN_LIMITS else "free",
        effective_plan=plan,
        plan_expires_at=profile.plan_expires_at,
        plan_source=profile.plan_source,
        boost_until=profile.boost_until,
        is_boosted=is_boosted(profile),
        limits=BusinessPlanLimits(**limits_dict(plan)),
        usage={"services": services, "offers": offers},
        product_ids=get_settings().parsed_apple_business_product_ids(),
    )


@owner_router.get("/plan", response_model=BusinessPlanResponse)
def business_plan(db: DBSession, user: CurrentUser) -> BusinessPlanResponse:
    return _plan_response(db, _own_profile(db, user.id))


@owner_router.post("/plan/apple", response_model=BusinessPlanResponse)
def sync_business_purchase(payload: BusinessAppleTransaction, db: DBSession, user: CurrentUser) -> BusinessPlanResponse:
    _own_profile(db, user.id)
    try:
        decoded = apple_iap_service.verify_signed_transaction(payload.signed_transaction)
        profile = apply_business_transaction(db, user, decoded)
    except apple_iap_service.AppleIAPNotConfigured as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except (apple_iap_service.AppleIAPError, BusinessPurchaseError) as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return _plan_response(db, profile)


@owner_router.get("/stats", response_model=BusinessStatsResponse)
def business_stats(db: DBSession, user: CurrentUser, days: int = Query(default=30, ge=1, le=365)) -> BusinessStatsResponse:
    profile = _own_profile(db, user.id)
    max_days = limits_for(profile).stats_days
    window = min(days, max_days)
    today = now_utc().date()
    start = today - timedelta(days=window - 1)
    rows = db.execute(
        select(BusinessStatDaily).where(
            BusinessStatDaily.business_user_id == user.id,
            BusinessStatDaily.day >= start,
        )
    ).scalars().all()
    totals = {metric: 0 for metric in ("view", *ACTION_METRICS)}
    per_day: dict[str, dict[str, int]] = {}
    for row in rows:
        totals[row.metric] = totals.get(row.metric, 0) + row.count
        bucket = per_day.setdefault(row.day.isoformat(), {"views": 0, "actions": 0})
        bucket["views" if row.metric == "view" else "actions"] += row.count
    series = []
    for offset in range(window):
        key = (start + timedelta(days=offset)).isoformat()
        bucket = per_day.get(key, {"views": 0, "actions": 0})
        series.append(BusinessStatsDay(day=key, views=bucket["views"], actions=bucket["actions"]))
    return BusinessStatsResponse(days=window, max_days=max_days, totals=totals, series=series)


@owner_router.get("/offers", response_model=list[BusinessOfferResponse])
def list_offers(db: DBSession, user: CurrentUser) -> list[BusinessOffer]:
    _own_profile(db, user.id)
    return db.execute(
        select(BusinessOffer).where(BusinessOffer.business_user_id == user.id).order_by(BusinessOffer.created_at.desc())
    ).scalars().all()


def _active_offer_count(db: DBSession, user_id: str, excluding: str | None = None) -> int:
    stmt = select(func.count()).select_from(BusinessOffer).where(
        BusinessOffer.business_user_id == user_id,
        BusinessOffer.is_active.is_(True),
    )
    if excluding:
        stmt = stmt.where(BusinessOffer.id != excluding)
    return db.scalar(stmt) or 0


@owner_router.post("/offers", response_model=BusinessOfferResponse, status_code=201)
def create_offer(payload: BusinessOfferCreate, db: DBSession, user: CurrentUser) -> BusinessOffer:
    profile = _own_profile(db, user.id)
    require_plan(profile, "pro")
    limit = limits_for(profile).offers
    if payload.is_active and _active_offer_count(db, user.id) >= limit:
        raise HTTPException(status_code=409, detail={"code": "business_offer_limit", "limit": limit})
    row = BusinessOffer(business_user_id=user.id, **payload.model_dump())
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def _owned_offer(db: DBSession, offer_id: str, user_id: str) -> BusinessOffer:
    row = db.get(BusinessOffer, offer_id)
    if not row or row.business_user_id != user_id:
        raise HTTPException(status_code=404, detail="Offer not found")
    return row


@owner_router.patch("/offers/{offer_id}", response_model=BusinessOfferResponse)
def update_offer(offer_id: str, payload: BusinessOfferUpdate, db: DBSession, user: CurrentUser) -> BusinessOffer:
    profile = _own_profile(db, user.id)
    row = _owned_offer(db, offer_id, user.id)
    values = payload.model_dump(exclude_unset=True)
    if values.get("is_active") and not row.is_active:
        require_plan(profile, "pro")
        if _active_offer_count(db, user.id, excluding=row.id) >= limits_for(profile).offers:
            raise HTTPException(status_code=409, detail={"code": "business_offer_limit", "limit": limits_for(profile).offers})
    for key, value in values.items():
        setattr(row, key, value)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@owner_router.delete("/offers/{offer_id}", status_code=204)
def delete_offer(offer_id: str, db: DBSession, user: CurrentUser) -> Response:
    row = _owned_offer(db, offer_id, user.id)
    db.delete(row)
    db.commit()
    return Response(status_code=204)


@owner_router.get("/reviews", response_model=list[BusinessReviewResponse])
def my_reviews(db: DBSession, user: CurrentUser) -> list[BusinessReview]:
    _own_profile(db, user.id)
    return db.execute(
        select(BusinessReview)
        .where(BusinessReview.business_user_id == user.id, BusinessReview.status == "published")
        .order_by(BusinessReview.created_at.desc())
        .limit(200)
    ).scalars().all()


@owner_router.post("/reviews/{review_id}/reply", response_model=BusinessReviewResponse)
def reply_to_review(review_id: str, payload: BusinessReviewReply, db: DBSession, user: CurrentUser) -> BusinessReview:
    _own_profile(db, user.id)
    review = db.get(BusinessReview, review_id)
    if not review or review.business_user_id != user.id or review.status != "published":
        raise HTTPException(status_code=404, detail="Review not found")
    review.owner_reply = payload.text.strip()
    review.owner_replied_at = now_utc()
    db.add(review)
    db.commit()
    db.refresh(review)
    return review


def _club_member_response(db: DBSession, row: BusinessClubMember, business_user_id: str) -> ClubMemberResponse | None:
    business = db.get(BusinessProfile, business_user_id)
    if not business:
        return None
    return ClubMemberResponse(id=row.id, status=row.status, business=summarize(business), created_at=row.created_at)


@owner_router.get("/club/members", response_model=list[ClubMemberResponse])
def club_members(db: DBSession, user: CurrentUser) -> list[ClubMemberResponse]:
    profile = _own_profile(db, user.id)
    if profile.kind != "club":
        raise HTTPException(status_code=409, detail={"code": "business_not_a_club"})
    rows = db.execute(
        select(BusinessClubMember).where(BusinessClubMember.club_user_id == user.id).order_by(BusinessClubMember.created_at.desc())
    ).scalars().all()
    return [item for row in rows if (item := _club_member_response(db, row, row.member_user_id))]


@owner_router.patch("/club/members/{membership_id}", response_model=ClubMemberResponse)
def review_club_member(membership_id: str, payload: ClubMembershipUpdate, db: DBSession, user: CurrentUser) -> ClubMemberResponse:
    _own_profile(db, user.id)
    row = db.get(BusinessClubMember, membership_id)
    if not row or row.club_user_id != user.id:
        raise HTTPException(status_code=404, detail="Membership not found")
    row.status = payload.status
    db.add(row)
    if payload.status == "approved":
        club = db.get(BusinessProfile, user.id)
        enqueue_account_notification(
            db,
            event_key=f"business-club-approved:{row.id}",
            recipient_id=row.member_user_id,
            event_type="business_club_membership",
            title="Вас прийнято до клубу",
            body=f"{club.display_name if club else 'Клуб'} підтвердив ваше членство",
            data={"club_user_id": user.id},
        )
    db.commit()
    db.refresh(row)
    response = _club_member_response(db, row, row.member_user_id)
    if response is None:
        raise HTTPException(status_code=404, detail="Membership not found")
    return response


@owner_router.delete("/club/members/{membership_id}", status_code=204)
def remove_club_member(membership_id: str, db: DBSession, user: CurrentUser) -> Response:
    row = db.get(BusinessClubMember, membership_id)
    if not row or user.id not in {row.club_user_id, row.member_user_id}:
        raise HTTPException(status_code=404, detail="Membership not found")
    db.delete(row)
    db.commit()
    return Response(status_code=204)


@owner_router.get("/clubs/mine", response_model=list[ClubMemberResponse])
def my_club_memberships(db: DBSession, user: CurrentUser) -> list[ClubMemberResponse]:
    _own_profile(db, user.id)
    rows = db.execute(
        select(BusinessClubMember).where(BusinessClubMember.member_user_id == user.id).order_by(BusinessClubMember.created_at.desc())
    ).scalars().all()
    return [item for row in rows if (item := _club_member_response(db, row, row.club_user_id))]


@owner_router.post("/clubs/{club_user_id}/join", response_model=ClubMemberResponse, status_code=201)
@limiter.limit("20/hour")
def join_club(request: Request, club_user_id: str, db: DBSession, user: CurrentUser) -> ClubMemberResponse:
    profile = _own_profile(db, user.id)
    if club_user_id == user.id:
        raise HTTPException(status_code=409, detail={"code": "cannot_join_own_club"})
    club = _public_profile(db, club_user_id)
    if club.kind != "club":
        raise HTTPException(status_code=409, detail={"code": "business_not_a_club"})
    row = db.execute(
        select(BusinessClubMember).where(
            BusinessClubMember.club_user_id == club_user_id,
            BusinessClubMember.member_user_id == user.id,
        )
    ).scalar_one_or_none()
    if row is None:
        row = BusinessClubMember(club_user_id=club_user_id, member_user_id=user.id, status="pending")
        db.add(row)
        db.flush()
        enqueue_account_notification(
            db,
            event_key=f"business-club-request:{row.id}",
            recipient_id=club_user_id,
            event_type="business_club_request",
            title="Нова заявка до клубу",
            body=f"{profile.display_name} хоче приєднатися до клубу",
            data={"membership_id": row.id},
        )
        db.commit()
        db.refresh(row)
    response = _club_member_response(db, row, club_user_id)
    if response is None:
        raise HTTPException(status_code=404, detail="Club not found")
    return response


# MARK: - Admin review moderation


@admin_router.get("/business-reviews", response_model=list[BusinessReviewResponse])
def admin_business_reviews(
    db: DBSession,
    admin: CurrentAdmin,
    review_status: str | None = Query(default=None, alias="status", pattern="^(published|hidden)$"),
) -> list[BusinessReview]:
    stmt = select(BusinessReview).order_by(BusinessReview.created_at.desc()).limit(500)
    if review_status:
        stmt = stmt.where(BusinessReview.status == review_status)
    return db.execute(stmt).scalars().all()


@admin_router.patch("/business-reviews/{review_id}", response_model=BusinessReviewResponse)
def admin_moderate_business_review(
    review_id: str,
    payload: AdminBusinessReviewModeration,
    db: DBSession,
    admin: CurrentAdmin,
) -> BusinessReview:
    review = db.get(BusinessReview, review_id)
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    review.status = payload.status
    db.add(review)
    db.flush()
    refresh_rating(db, review.business_user_id)
    db.commit()
    db.refresh(review)
    return review
