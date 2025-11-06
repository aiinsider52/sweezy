from __future__ import annotations

from typing import List

from fastapi import APIRouter, HTTPException, Query

from ..dependencies import CurrentAdmin, DBSession
from ..schemas import GuideCreate, GuideOut, GuideUpdate
from ..services import GuideService


router = APIRouter()


@router.get("/", response_model=List[GuideOut])
def list_guides(db: DBSession, offset: int = Query(0, ge=0), limit: int = Query(100, ge=1, le=1000)) -> list[GuideOut]:
    return GuideService.list(db, offset=offset, limit=limit)


@router.get("/{guide_id}", response_model=GuideOut)
def get_guide(guide_id: str, db: DBSession) -> GuideOut:
    obj = GuideService.get(db, guide_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Guide not found")
    return obj


@router.get("/slug/{slug}", response_model=GuideOut)
def get_guide_by_slug(slug: str, db: DBSession) -> GuideOut:
    obj = GuideService.get_by_slug(db, slug)
    if not obj:
        raise HTTPException(status_code=404, detail="Guide not found")
    return obj


@router.post("/", response_model=GuideOut)
def create_guide(payload: GuideCreate, db: DBSession, _: CurrentAdmin) -> GuideOut:
    return GuideService.create(db, payload)


@router.put("/{guide_id}", response_model=GuideOut)
def update_guide(guide_id: str, payload: GuideUpdate, db: DBSession, _: CurrentAdmin) -> GuideOut:
    obj = GuideService.get(db, guide_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Guide not found")
    return GuideService.update(db, obj, payload)


@router.delete("/{guide_id}", status_code=204)
def delete_guide(guide_id: str, db: DBSession, _: CurrentAdmin) -> None:
    obj = GuideService.get(db, guide_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Guide not found")
    GuideService.delete(db, obj)
    return None


