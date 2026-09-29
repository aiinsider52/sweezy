from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Query, Request, status

from ..core.rate_limit import limiter
from ..dependencies import CurrentAdmin, CurrentUser, DBSession
from ..models.place_suggestion import PlaceSuggestion
from ..schemas.place_suggestion import (
    CommunityPlaceResponse,
    PlaceSuggestionCreate,
    PlaceSuggestionModeration,
    PlaceSuggestionResponse,
)

router = APIRouter()
admin_router = APIRouter()


@router.post("/suggestions", response_model=PlaceSuggestionResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/hour")
def create_suggestion(
    request: Request,
    payload: PlaceSuggestionCreate,
    db: DBSession,
    user: CurrentUser,
) -> PlaceSuggestion:
    suggestion = PlaceSuggestion(user_id=user.id, **payload.model_dump())
    db.add(suggestion)
    db.commit()
    db.refresh(suggestion)
    return suggestion


@router.get("/suggestions/me", response_model=list[PlaceSuggestionResponse])
def my_suggestions(db: DBSession, user: CurrentUser) -> list[PlaceSuggestion]:
    return (
        db.query(PlaceSuggestion)
        .filter(PlaceSuggestion.user_id == user.id)
        .order_by(PlaceSuggestion.created_at.desc())
        .limit(50)
        .all()
    )


@router.get("/community", response_model=list[CommunityPlaceResponse])
def community_places(db: DBSession, country: str = Query(default="CH", min_length=2, max_length=2)) -> list[PlaceSuggestion]:
    return (
        db.query(PlaceSuggestion)
        .filter(
            PlaceSuggestion.status == "approved",
            PlaceSuggestion.country_code == country.upper(),
            PlaceSuggestion.latitude.isnot(None),
            PlaceSuggestion.longitude.isnot(None),
        )
        .order_by(PlaceSuggestion.reviewed_at.desc())
        .limit(500)
        .all()
    )


@admin_router.get("/places/suggestions", response_model=list[PlaceSuggestionResponse])
def admin_suggestions(
    db: DBSession,
    admin: CurrentAdmin,
    suggestion_status: str | None = Query(default="pending", alias="status"),
) -> list[PlaceSuggestion]:
    query = db.query(PlaceSuggestion)
    if suggestion_status:
        query = query.filter(PlaceSuggestion.status == suggestion_status)
    return query.order_by(PlaceSuggestion.created_at.desc()).limit(500).all()


@admin_router.patch("/places/suggestions/{suggestion_id}", response_model=PlaceSuggestionResponse)
def moderate_suggestion(
    suggestion_id: str,
    payload: PlaceSuggestionModeration,
    db: DBSession,
    admin: CurrentAdmin,
) -> PlaceSuggestion:
    suggestion = db.get(PlaceSuggestion, suggestion_id)
    if not suggestion:
        raise HTTPException(status_code=404, detail="Suggestion not found")

    if payload.latitude is not None:
        suggestion.latitude = payload.latitude
    if payload.longitude is not None:
        suggestion.longitude = payload.longitude
    if payload.name:
        suggestion.name = " ".join(payload.name.split())
    if payload.subdivision_code and payload.subdivision_code.strip():
        suggestion.subdivision_code = payload.subdivision_code.strip().upper()

    # A place on the map needs a checked location; approving without one would publish nothing useful.
    if payload.status == "approved" and (suggestion.latitude is None or suggestion.longitude is None):
        raise HTTPException(status_code=422, detail="Approval needs latitude and longitude")
    if payload.status == "rejected" and not (payload.rejection_reason or "").strip():
        raise HTTPException(status_code=422, detail="Rejection needs a reason")

    suggestion.status = payload.status
    suggestion.rejection_reason = (payload.rejection_reason or "").strip() if payload.status == "rejected" else None
    suggestion.reviewed_at = datetime.now(timezone.utc) if payload.status != "pending" else None
    db.commit()
    db.refresh(suggestion)
    return suggestion
