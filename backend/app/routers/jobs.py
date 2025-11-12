from __future__ import annotations

from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from ..dependencies import get_db, CurrentUser, DBSession
from ..schemas.job import JobItem, JobSearchResponse, JobFavoriteIn, JobFavoriteOut, JobSearchEventOut
from ..services.jobs_aggregator import search_jobs
from ..models.job import JobFavorite, JobSearchEvent

router = APIRouter()


@router.get("/search", response_model=JobSearchResponse)
async def search(q: str = Query(..., min_length=2), canton: str | None = None, page: int = 1, per_page: int = 20) -> JobSearchResponse:
    items, sources = await search_jobs(q=q, canton=canton, page=page, per_page=per_page)
    return JobSearchResponse(items=items, total=len(items), sources=sources)


@router.post("/analytics/events", status_code=status.HTTP_204_NO_CONTENT)
def log_event(db: DBSession, keyword: str, canton: str | None = None):
    try:
        db.add(JobSearchEvent(keyword=keyword.strip().lower(), canton=canton))
        db.commit()
    except Exception:
        db.rollback()
    return


@router.get("/analytics/top", response_model=List[JobSearchEventOut])
def top_keywords(db: DBSession, limit: int = 10):
    from sqlalchemy import func
    rows = (
        db.query(JobSearchEvent.keyword, JobSearchEvent.canton, func.count().label("count"))
        .group_by(JobSearchEvent.keyword, JobSearchEvent.canton)
        .order_by(func.count().desc())
        .limit(limit)
        .all()
    )
    return [JobSearchEventOut(keyword=r[0], canton=r[1], count=r[2]) for r in rows]


@router.get("/favorites", response_model=List[JobFavoriteOut])
def list_favorites(user: CurrentUser, db: DBSession):
    rows = (
        db.query(JobFavorite)
        .filter(JobFavorite.user_id == user.id)
        .order_by(JobFavorite.created_at.desc())
        .all()
    )
    return [
        JobFavoriteOut(
            id=str(r.id),
            job_id=r.job_id,
            source=r.source,
            title=r.title,
            company=r.company,
            location=r.location,
            canton=r.canton,
            url=r.url,
            created_at=r.created_at,
        )
        for r in rows
    ]


@router.post("/favorites", response_model=JobFavoriteOut, status_code=status.HTTP_201_CREATED)
def add_favorite(payload: JobFavoriteIn, user: CurrentUser, db: DBSession):
    fav = JobFavorite(
        user_id=user.id,
        job_id=payload.job_id,
        source=payload.source,
        title=payload.title,
        company=payload.company,
        location=payload.location,
        canton=payload.canton,
        url=payload.url,
    )
    db.add(fav)
    db.commit()
    db.refresh(fav)
    return JobFavoriteOut(
        id=str(fav.id),
        job_id=fav.job_id,
        source=fav.source,
        title=fav.title,
        company=fav.company,
        location=fav.location,
        canton=fav.canton,
        url=fav.url,
        created_at=fav.created_at,
    )


@router.delete("/favorites/{favorite_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_favorite(favorite_id: str, user: CurrentUser, db: DBSession):
    fav = db.query(JobFavorite).filter(JobFavorite.id == favorite_id, JobFavorite.user_id == user.id).first()
    if not fav:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Favorite not found")
    db.delete(fav)
    db.commit()
    return


