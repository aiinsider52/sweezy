from __future__ import annotations

import hashlib

from fastapi import APIRouter, HTTPException, Query, Request, status
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError

from ..core.rate_limit import limiter
from ..dependencies import CurrentAdmin, CurrentUser, DBSession
from ..models.discovery_review import DiscoveryReview, DiscoveryReviewReport
from ..schemas.discovery import (
    DiscoveryRatingSummary,
    DiscoveryReportResponse,
    DiscoveryReviewModerationUpdate,
    DiscoveryReviewPage,
    DiscoveryReviewReportCreate,
    DiscoveryReviewResponse,
    DiscoveryReviewUpsert,
)

router = APIRouter()
admin_router = APIRouter()

DISCOVERY_PLACE_IDS = {
    "aletsch", "lavaux", "creux-du-van", "rhine-falls", "oeschinensee", "ruinaulta",
    "monte-generoso", "st-gallen-abbey", "matterhorn", "jungfraujoch", "bern", "rigi",
    "zurich", "geneva", "lucerne", "basel", "lausanne", "montreux", "lugano", "davos",
    "ascona", "engadin",
    "interlaken", "crans-montana", "locarno", "martigny", "flims-laax", "vaud-region",
    "jura-three-lakes", "bern-region",
}


def _require_place(place_id: str) -> None:
    if place_id not in DISCOVERY_PLACE_IDS:
        raise HTTPException(status_code=404, detail="Discovery place not found")


def _author_label(user_id: str) -> str:
    digest = hashlib.sha256(user_id.encode("utf-8")).hexdigest()[:4].upper()
    return f"Sweezy traveler {digest}"


def _response(review: DiscoveryReview, *, is_mine: bool = False) -> DiscoveryReviewResponse:
    return DiscoveryReviewResponse(
        id=review.id,
        place_id=review.place_id,
        rating=review.rating,
        comment=review.comment,
        author_label=_author_label(review.user_id),
        created_at=review.created_at,
        updated_at=review.updated_at,
        is_mine=is_mine,
    )


@router.get("/ratings", response_model=list[DiscoveryRatingSummary])
def rating_summaries(db: DBSession) -> list[DiscoveryRatingSummary]:
    rows = (
        db.query(
            DiscoveryReview.place_id,
            func.avg(DiscoveryReview.rating),
            func.count(DiscoveryReview.id),
        )
        .filter(DiscoveryReview.status == "published")
        .group_by(DiscoveryReview.place_id)
        .all()
    )
    mapped = {place_id: (float(average), int(count)) for place_id, average, count in rows}
    return [
        DiscoveryRatingSummary(
            place_id=place_id,
            average_rating=round(mapped.get(place_id, (0.0, 0))[0], 1),
            review_count=mapped.get(place_id, (0.0, 0))[1],
        )
        for place_id in sorted(DISCOVERY_PLACE_IDS)
    ]


@router.get("/{place_id}/reviews", response_model=DiscoveryReviewPage)
def list_reviews(
    place_id: str,
    db: DBSession,
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
) -> DiscoveryReviewPage:
    _require_place(place_id)
    base = db.query(DiscoveryReview).filter(
        DiscoveryReview.place_id == place_id,
        DiscoveryReview.status == "published",
    )
    count = base.count()
    average = db.query(func.avg(DiscoveryReview.rating)).filter(
        DiscoveryReview.place_id == place_id,
        DiscoveryReview.status == "published",
    ).scalar()
    rows = base.order_by(DiscoveryReview.created_at.desc()).offset(offset).limit(limit).all()
    return DiscoveryReviewPage(
        average_rating=round(float(average or 0), 1),
        review_count=count,
        items=[_response(review) for review in rows],
    )


@router.get("/{place_id}/reviews/me", response_model=DiscoveryReviewResponse)
def my_review(place_id: str, db: DBSession, user: CurrentUser) -> DiscoveryReviewResponse:
    _require_place(place_id)
    review = db.query(DiscoveryReview).filter_by(place_id=place_id, user_id=user.id).first()
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    return _response(review, is_mine=True)


@router.put("/{place_id}/reviews/me", response_model=DiscoveryReviewResponse)
@limiter.limit("8/minute")
def upsert_review(
    request: Request,
    place_id: str,
    payload: DiscoveryReviewUpsert,
    db: DBSession,
    user: CurrentUser,
) -> DiscoveryReviewResponse:
    _require_place(place_id)
    review = db.query(DiscoveryReview).filter_by(place_id=place_id, user_id=user.id).first()
    if review:
        review.rating = payload.rating
        review.comment = payload.comment
        review.status = "published"
        review.report_count = 0
    else:
        review = DiscoveryReview(
            place_id=place_id,
            user_id=user.id,
            rating=payload.rating,
            comment=payload.comment,
        )
        db.add(review)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Review already exists") from exc
    db.refresh(review)
    return _response(review, is_mine=True)


@router.delete("/{place_id}/reviews/me", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("8/minute")
def delete_my_review(request: Request, place_id: str, db: DBSession, user: CurrentUser) -> None:
    _require_place(place_id)
    review = db.query(DiscoveryReview).filter_by(place_id=place_id, user_id=user.id).first()
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    db.delete(review)
    db.commit()


@router.post("/reviews/{review_id}/report", response_model=DiscoveryReportResponse)
@limiter.limit("10/hour")
def report_review(
    request: Request,
    review_id: str,
    payload: DiscoveryReviewReportCreate,
    db: DBSession,
    user: CurrentUser,
) -> DiscoveryReportResponse:
    review = db.get(DiscoveryReview, review_id)
    if not review or review.status != "published":
        raise HTTPException(status_code=404, detail="Review not found")
    if review.user_id == user.id:
        raise HTTPException(status_code=400, detail="You cannot report your own review")
    existing = db.query(DiscoveryReviewReport).filter_by(review_id=review_id, reporter_id=user.id).first()
    if existing:
        return DiscoveryReportResponse(status="already_reported")
    db.add(DiscoveryReviewReport(review_id=review_id, reporter_id=user.id, reason=payload.reason))
    review.report_count += 1
    if review.report_count >= 3:
        review.status = "hidden"
    db.commit()
    return DiscoveryReportResponse(status="reported")


@admin_router.get("/discovery/reviews", response_model=list[DiscoveryReviewResponse])
def admin_reviews(db: DBSession, admin: CurrentAdmin, review_status: str | None = None) -> list[DiscoveryReviewResponse]:
    query = db.query(DiscoveryReview)
    if review_status:
        query = query.filter(DiscoveryReview.status == review_status)
    return [_response(row) for row in query.order_by(DiscoveryReview.created_at.desc()).limit(500).all()]


@admin_router.patch("/discovery/reviews/{review_id}", response_model=DiscoveryReviewResponse)
def moderate_review(
    review_id: str,
    payload: DiscoveryReviewModerationUpdate,
    db: DBSession,
    admin: CurrentAdmin,
) -> DiscoveryReviewResponse:
    review = db.get(DiscoveryReview, review_id)
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    review.status = payload.status
    db.commit()
    db.refresh(review)
    return _response(review)
