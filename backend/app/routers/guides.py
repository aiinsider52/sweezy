from typing import List

from fastapi import APIRouter, HTTPException, Query, Request

from ..dependencies import CurrentAdmin, DBSession
from ..schemas import GuideCreate, GuideOut, GuideUpdate
from ..services import GuideService


router = APIRouter()


@router.get("/", response_model=List[GuideOut])
def list_guides(
    db: DBSession,
    offset: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    status: str | None = None,
    include_drafts: bool = False,
) -> list[GuideOut]:
    return GuideService.list(db, offset=offset, limit=limit, status=status, include_drafts=include_drafts)


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
def create_guide(payload: GuideCreate, db: DBSession, req: Request, _: CurrentAdmin) -> GuideOut:
    try:
        obj = GuideService.create(db, payload)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    try:
        from ..services.audit import log_audit
        user_email = req.headers.get("x-user-email") or "admin"
        log_audit(db, user_email=user_email, action="create", entity="guides", entity_id=obj.id, before=None, after=obj)
    except Exception:
        pass
    return obj


@router.put("/{guide_id}", response_model=GuideOut)
def update_guide(guide_id: str, payload: GuideUpdate, db: DBSession, req: Request, _: CurrentAdmin) -> GuideOut:
    obj = GuideService.get(db, guide_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Guide not found")
    before = obj
    try:
        obj = GuideService.update(db, obj, payload)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    try:
        from ..services.audit import log_audit
        user_email = req.headers.get("x-user-email") or "admin"
        log_audit(db, user_email=user_email, action="update", entity="guides", entity_id=obj.id, before=before, after=obj)
    except Exception:
        pass
    return obj


@router.delete("/{guide_id}", status_code=204)
def delete_guide(guide_id: str, db: DBSession, req: Request, _: CurrentAdmin) -> None:
    obj = GuideService.get(db, guide_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Guide not found")
    before = obj
    GuideService.delete(db, obj)
    try:
        from ..services.audit import log_audit
        user_email = req.headers.get("x-user-email") or "admin"
        log_audit(db, user_email=user_email, action="delete", entity="guides", entity_id=guide_id, before=before, after=None)
    except Exception:
        pass
    return None
