from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import or_, select

from ..dependencies import CurrentAdmin, DBSession
from ..models.swiss_moment import SwissMoment
from ..schemas.swiss_moment import (
    SwissMomentCreate,
    SwissMomentResponse,
    SwissMomentUpdate,
)


router = APIRouter()
admin_router = APIRouter()


def _matches_audience(filters: dict, *, canton: Optional[str], permit: Optional[str], tenure_months: Optional[int],
                      has_children: Optional[bool], life_events: list[str]) -> bool:
    """Server-side audience match for the public list endpoint.

    Empty/missing filter dimensions match anyone (so a moment with no filters is
    visible to every user). Mismatching a *provided* filter excludes the moment.
    """
    if not isinstance(filters, dict):
        return True

    cantons = [c for c in (filters.get("cantons") or []) if isinstance(c, str)]
    if cantons and canton and canton.upper() not in {c.upper() for c in cantons}:
        return False

    permits = [p for p in (filters.get("permits") or []) if isinstance(p, str)]
    if permits and permit and permit.upper() not in {p.upper() for p in permits}:
        return False

    min_tenure = filters.get("min_tenure_months")
    if isinstance(min_tenure, int) and tenure_months is not None and tenure_months < min_tenure:
        return False
    max_tenure = filters.get("max_tenure_months")
    if isinstance(max_tenure, int) and tenure_months is not None and tenure_months > max_tenure:
        return False

    needs_children = filters.get("has_children")
    if isinstance(needs_children, bool) and has_children is not None and needs_children != has_children:
        return False

    needed_events = [e for e in (filters.get("life_events") or []) if isinstance(e, str)]
    if needed_events and not (set(needed_events) & set(life_events)):
        return False

    return True


@router.get("/", response_model=list[SwissMomentResponse])
def list_moments(
    db: DBSession,
    canton: Optional[str] = Query(None, max_length=10),
    permit: Optional[str] = Query(None, max_length=10),
    tenure_months: Optional[int] = Query(None, ge=0),
    has_children: Optional[bool] = Query(None),
    life_events: Optional[str] = Query(None, description="Comma-separated"),
    horizon_days: int = Query(60, ge=1, le=365),
) -> list[SwissMomentResponse]:
    now = datetime.utcnow()
    horizon = now + timedelta(days=horizon_days)

    stmt = (
        select(SwissMoment)
        .where(SwissMoment.is_active.is_(True))
        .where(SwissMoment.starts_at <= horizon)
        .where(or_(SwissMoment.ends_at >= now, SwissMoment.ends_at.is_(None)))
        .order_by(SwissMoment.priority.desc(), SwissMoment.starts_at.asc())
    )
    rows = db.execute(stmt).scalars().all()

    events = [e.strip() for e in (life_events.split(",") if life_events else []) if e.strip()]
    filtered = [
        r for r in rows
        if _matches_audience(
            r.audience_filters or {},
            canton=canton,
            permit=permit,
            tenure_months=tenure_months,
            has_children=has_children,
            life_events=events,
        )
    ]
    return [SwissMomentResponse.model_validate(r) for r in filtered]


@router.get("/{moment_id}", response_model=SwissMomentResponse)
def get_moment(moment_id: str, db: DBSession) -> SwissMomentResponse:
    moment = db.get(SwissMoment, moment_id)
    if not moment or not moment.is_active:
        raise HTTPException(status_code=404, detail="Moment not found")
    return SwissMomentResponse.model_validate(moment)


# ── Admin ───────────────────────────────────────────────────────────────────


@admin_router.get("/moments", response_model=list[SwissMomentResponse])
def admin_list_moments(_: CurrentAdmin, db: DBSession) -> list[SwissMomentResponse]:
    rows = db.execute(select(SwissMoment).order_by(SwissMoment.starts_at.asc())).scalars().all()
    return [SwissMomentResponse.model_validate(r) for r in rows]


@admin_router.post("/moments", response_model=SwissMomentResponse, status_code=status.HTTP_201_CREATED)
def admin_create_moment(payload: SwissMomentCreate, _: CurrentAdmin, db: DBSession) -> SwissMomentResponse:
    existing = db.execute(select(SwissMoment).where(SwissMoment.key == payload.key)).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=409, detail="Moment key already exists")

    moment = SwissMoment(
        key=payload.key,
        title=payload.title,
        description_md=payload.description_md,
        starts_at=payload.starts_at,
        ends_at=payload.ends_at,
        recurrence=payload.recurrence.value,
        audience_filters=payload.audience_filters.model_dump(),
        cta_kind=payload.cta_kind.value,
        cta_payload=payload.cta_payload,
        priority=payload.priority,
        is_active=payload.is_active,
    )
    db.add(moment)
    db.commit()
    db.refresh(moment)
    return SwissMomentResponse.model_validate(moment)


@admin_router.patch("/moments/{moment_id}", response_model=SwissMomentResponse)
def admin_update_moment(
    moment_id: str,
    payload: SwissMomentUpdate,
    _: CurrentAdmin,
    db: DBSession,
) -> SwissMomentResponse:
    moment = db.get(SwissMoment, moment_id)
    if not moment:
        raise HTTPException(status_code=404, detail="Moment not found")

    data = payload.model_dump(exclude_unset=True)
    for key, value in data.items():
        if key == "audience_filters" and value is not None:
            moment.audience_filters = value if isinstance(value, dict) else value.model_dump()
        elif key == "recurrence" and value is not None:
            moment.recurrence = value.value if hasattr(value, "value") else value
        elif key == "cta_kind" and value is not None:
            moment.cta_kind = value.value if hasattr(value, "value") else value
        else:
            setattr(moment, key, value)

    db.add(moment)
    db.commit()
    db.refresh(moment)
    return SwissMomentResponse.model_validate(moment)


@admin_router.delete("/moments/{moment_id}", status_code=status.HTTP_204_NO_CONTENT)
def admin_delete_moment(moment_id: str, _: CurrentAdmin, db: DBSession) -> None:
    moment = db.get(SwissMoment, moment_id)
    if not moment:
        raise HTTPException(status_code=404, detail="Moment not found")
    db.delete(moment)
    db.commit()
