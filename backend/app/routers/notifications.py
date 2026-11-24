from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, HTTPException, Response, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from ..core.countries import normalize_country_code, normalize_subdivision_code
from ..dependencies import CurrentUser, DBSession
from ..models.marketplace import ServiceListing
from ..models.notification import MarketplaceFollow, MarketplaceWatch
from ..services.engagement_push import is_valid_timezone, preferences_for

router = APIRouter()


class NotificationPreferencesResponse(BaseModel):
    locale: str
    timezone: str
    social_enabled: bool
    events_enabled: bool
    marketplace_enabled: bool


class NotificationPreferencesUpdate(BaseModel):
    locale: Literal["uk", "de", "en"] | None = None
    timezone: str | None = Field(default=None, max_length=64)
    social_enabled: bool | None = None
    events_enabled: bool | None = None
    marketplace_enabled: bool | None = None


class MarketplaceFollowCreate(BaseModel):
    country_code: str = Field(min_length=2, max_length=2)
    subdivision_code: str = Field(min_length=1, max_length=10)
    category: str | None = Field(default=None, max_length=30)


class MarketplaceFollowResponse(BaseModel):
    id: str
    country_code: str
    subdivision_code: str
    category: str | None


def _preferences_response(prefs) -> NotificationPreferencesResponse:
    return NotificationPreferencesResponse(
        locale=prefs.locale,
        timezone=prefs.timezone,
        social_enabled=prefs.social_enabled,
        events_enabled=prefs.events_enabled,
        marketplace_enabled=prefs.marketplace_enabled,
    )


def _follow_response(follow: MarketplaceFollow) -> MarketplaceFollowResponse:
    return MarketplaceFollowResponse(
        id=follow.id,
        country_code=follow.country_code,
        subdivision_code=follow.subdivision_code,
        category=follow.category or None,
    )


@router.get("/preferences", response_model=NotificationPreferencesResponse)
def get_preferences(db: DBSession, user: CurrentUser) -> NotificationPreferencesResponse:
    prefs = preferences_for(db, user.id)
    db.commit()
    return _preferences_response(prefs)


@router.put("/preferences", response_model=NotificationPreferencesResponse)
def update_preferences(payload: NotificationPreferencesUpdate, db: DBSession, user: CurrentUser) -> NotificationPreferencesResponse:
    data = payload.model_dump(exclude_unset=True, exclude_none=True)
    if "timezone" in data and not is_valid_timezone(data["timezone"]):
        raise HTTPException(status_code=422, detail="Unknown timezone")
    prefs = preferences_for(db, user.id)
    for field, value in data.items():
        setattr(prefs, field, value)
    db.commit()
    return _preferences_response(prefs)


@router.put("/listing-watches/{listing_id}", status_code=status.HTTP_204_NO_CONTENT)
def watch_listing(listing_id: str, db: DBSession, user: CurrentUser) -> Response:
    if not db.get(ServiceListing, listing_id):
        raise HTTPException(status_code=404, detail="Listing not found")
    exists = db.execute(
        select(MarketplaceWatch.id).where(MarketplaceWatch.user_id == user.id, MarketplaceWatch.listing_id == listing_id)
    ).scalar_one_or_none()
    if not exists:
        db.add(MarketplaceWatch(user_id=user.id, listing_id=listing_id))
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/listing-watches/{listing_id}", status_code=status.HTTP_204_NO_CONTENT)
def unwatch_listing(listing_id: str, db: DBSession, user: CurrentUser) -> Response:
    watch = db.execute(
        select(MarketplaceWatch).where(MarketplaceWatch.user_id == user.id, MarketplaceWatch.listing_id == listing_id)
    ).scalar_one_or_none()
    if watch:
        db.delete(watch)
        db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/marketplace-follows", response_model=list[MarketplaceFollowResponse])
def list_follows(db: DBSession, user: CurrentUser) -> list[MarketplaceFollowResponse]:
    rows = db.execute(
        select(MarketplaceFollow).where(MarketplaceFollow.user_id == user.id).order_by(MarketplaceFollow.created_at)
    ).scalars().all()
    return [_follow_response(row) for row in rows]


@router.post("/marketplace-follows", response_model=MarketplaceFollowResponse, status_code=status.HTTP_201_CREATED)
def create_follow(payload: MarketplaceFollowCreate, db: DBSession, user: CurrentUser) -> MarketplaceFollowResponse:
    try:
        country = normalize_country_code(payload.country_code)
        subdivision = normalize_subdivision_code(country, payload.subdivision_code)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from None
    if not subdivision:
        raise HTTPException(status_code=422, detail="Region is required")
    category = (payload.category or "").strip()
    existing = db.execute(
        select(MarketplaceFollow).where(
            MarketplaceFollow.user_id == user.id,
            MarketplaceFollow.country_code == country,
            MarketplaceFollow.subdivision_code == subdivision,
            MarketplaceFollow.category == category,
        )
    ).scalar_one_or_none()
    if existing:
        return _follow_response(existing)
    if db.query(MarketplaceFollow).filter(MarketplaceFollow.user_id == user.id).count() >= 20:
        raise HTTPException(status_code=409, detail="Too many follows")
    follow = MarketplaceFollow(user_id=user.id, country_code=country, subdivision_code=subdivision, category=category)
    db.add(follow)
    db.commit()
    db.refresh(follow)
    return _follow_response(follow)


@router.delete("/marketplace-follows/{follow_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_follow(follow_id: str, db: DBSession, user: CurrentUser) -> Response:
    follow = db.get(MarketplaceFollow, follow_id)
    if follow and follow.user_id == user.id:
        db.delete(follow)
        db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
