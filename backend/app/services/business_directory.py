from __future__ import annotations

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from ..models.business import BusinessClubMember, BusinessOffer, BusinessProfile, BusinessReview, BusinessService
from ..schemas.business import (
    BusinessImpressum,
    BusinessOfferResponse,
    BusinessReviewResponse,
    BusinessServiceResponse,
    BusinessSummary,
    PublicBusinessProfileResponse,
)
from .business_plans import effective_plan, is_boosted, now_utc


def active_offers_query(business_user_ids: list[str] | None = None):
    stmt = select(BusinessOffer).where(
        BusinessOffer.is_active.is_(True),
        or_(BusinessOffer.ends_at.is_(None), BusinessOffer.ends_at > now_utc()),
    )
    if business_user_ids is not None:
        stmt = stmt.where(BusinessOffer.business_user_id.in_(business_user_ids))
    return stmt.order_by(BusinessOffer.created_at.desc())


def top_offer_labels(db: Session, business_user_ids: list[str]) -> dict[str, str]:
    if not business_user_ids:
        return {}
    labels: dict[str, str] = {}
    for offer in db.execute(active_offers_query(business_user_ids)).scalars():
        labels.setdefault(offer.business_user_id, offer.discount_label)
    return labels


def summarize(profile: BusinessProfile, *, top_offer_label: str | None = None) -> BusinessSummary:
    return BusinessSummary(
        user_id=profile.user_id,
        kind=profile.kind,
        display_name=profile.display_name,
        tagline=profile.tagline,
        category=profile.category,
        country_code=profile.country_code,
        subdivision_code=profile.subdivision_code,
        city=profile.city,
        languages=profile.languages or [],
        logo_url=profile.logo_url,
        cover_url=profile.cover_url,
        latitude=profile.latitude,
        longitude=profile.longitude,
        is_verified=profile.is_verified,
        average_rating=profile.average_rating,
        review_count=profile.review_count or 0,
        plan=effective_plan(profile),
        is_sponsored=is_boosted(profile),
        top_offer_label=top_offer_label,
    )


def club_links(db: Session, profile: BusinessProfile) -> tuple[list[BusinessSummary], list[BusinessSummary]]:
    """Returns (clubs this business belongs to, approved members when the profile is a club)."""
    clubs: list[BusinessSummary] = []
    memberships = db.execute(
        select(BusinessClubMember).where(
            BusinessClubMember.member_user_id == profile.user_id,
            BusinessClubMember.status == "approved",
        )
    ).scalars().all()
    for membership in memberships:
        club = db.get(BusinessProfile, membership.club_user_id)
        if club and club.status == "approved":
            clubs.append(summarize(club))
    members: list[BusinessSummary] = []
    if profile.kind == "club":
        rows = db.execute(
            select(BusinessClubMember).where(
                BusinessClubMember.club_user_id == profile.user_id,
                BusinessClubMember.status == "approved",
            ).order_by(BusinessClubMember.created_at.asc())
        ).scalars().all()
        for row in rows:
            member = db.get(BusinessProfile, row.member_user_id)
            if member and member.status == "approved":
                members.append(summarize(member))
    return clubs, members


def public_profile_response(db: Session, profile: BusinessProfile) -> PublicBusinessProfileResponse:
    services = db.execute(
        select(BusinessService)
        .where(BusinessService.business_user_id == profile.user_id, BusinessService.is_active.is_(True))
        .order_by(BusinessService.created_at.asc())
    ).scalars().all()
    offers = db.execute(active_offers_query([profile.user_id]).limit(10)).scalars().all()
    reviews = db.execute(
        select(BusinessReview)
        .where(BusinessReview.business_user_id == profile.user_id, BusinessReview.status == "published")
        .order_by(BusinessReview.created_at.desc())
        .limit(10)
    ).scalars().all()
    clubs, members = club_links(db, profile)
    return PublicBusinessProfileResponse(
        user_id=profile.user_id,
        kind=profile.kind,
        display_name=profile.display_name,
        tagline=profile.tagline,
        description=profile.description,
        category=profile.category,
        canton=profile.canton,
        country_code=profile.country_code,
        subdivision_code=profile.subdivision_code,
        city=profile.city,
        address=profile.address,
        latitude=profile.latitude,
        longitude=profile.longitude,
        service_area=profile.service_area,
        languages=profile.languages,
        logo_url=profile.logo_url,
        cover_url=profile.cover_url,
        photo_urls=profile.photo_urls or [],
        website=profile.website,
        phone=profile.phone,
        email=profile.email,
        social_links=profile.social_links or {},
        opening_hours_note=profile.opening_hours_note,
        delivery_modes=profile.delivery_modes,
        cancellation_policy=profile.cancellation_policy,
        is_verified=profile.is_verified,
        plan=effective_plan(profile),
        is_sponsored=is_boosted(profile),
        services=[BusinessServiceResponse.model_validate(item) for item in services],
        offers=[BusinessOfferResponse.model_validate(item) for item in offers],
        reviews=[BusinessReviewResponse.model_validate(item) for item in reviews],
        average_rating=profile.average_rating,
        review_count=profile.review_count or 0,
        clubs=clubs,
        members=members,
        impressum=BusinessImpressum(
            legal_name=profile.legal_name,
            represented_by=profile.represented_by,
            address=profile.address,
            uid_number=profile.uid_number,
            email=profile.email,
            phone=profile.phone,
        ),
    )
