from __future__ import annotations

from fastapi import APIRouter, HTTPException
from sqlalchemy import select, update

from ..dependencies import CurrentUser, DBSession
from ..models.country_context import UserCountryContext
from ..schemas.country_context import (
    CountryCatalog,
    CountryContextResponse,
    CountryContextUpsert,
    country_catalog,
)


router = APIRouter()


@router.get("/catalog", response_model=CountryCatalog)
def catalog() -> CountryCatalog:
    return country_catalog()


@router.get("/me", response_model=list[CountryContextResponse])
def list_my_contexts(db: DBSession, user: CurrentUser) -> list[UserCountryContext]:
    return list(
        db.execute(
            select(UserCountryContext)
            .where(UserCountryContext.user_id == user.id)
            .order_by(UserCountryContext.is_active.desc(), UserCountryContext.updated_at.desc())
        ).scalars().all()
    )


@router.get("/me/active", response_model=CountryContextResponse)
def active_context(db: DBSession, user: CurrentUser) -> UserCountryContext:
    context = db.execute(
        select(UserCountryContext).where(
            UserCountryContext.user_id == user.id,
            UserCountryContext.is_active.is_(True),
        )
    ).scalar_one_or_none()
    if not context:
        raise HTTPException(status_code=404, detail="Country context not configured")
    return context


@router.put("/me/{country_code}", response_model=CountryContextResponse)
def upsert_context(
    country_code: str,
    payload: CountryContextUpsert,
    db: DBSession,
    user: CurrentUser,
) -> UserCountryContext:
    if country_code.upper() != payload.country_code:
        raise HTTPException(status_code=409, detail="Country code path and payload mismatch")
    context = db.execute(
        select(UserCountryContext).where(
            UserCountryContext.user_id == user.id,
            UserCountryContext.country_code == payload.country_code,
        )
    ).scalar_one_or_none()
    values = payload.model_dump()
    if payload.is_active:
        db.execute(
            update(UserCountryContext)
            .where(UserCountryContext.user_id == user.id)
            .values(is_active=False)
        )
    if context is None:
        context = UserCountryContext(user_id=user.id, **values)
    else:
        for key, value in values.items():
            setattr(context, key, value)
    db.add(context)
    db.commit()
    db.refresh(context)
    return context

