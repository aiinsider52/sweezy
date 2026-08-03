from typing import List

from fastapi import APIRouter, HTTPException, Query, Request

from ..dependencies import CurrentAdmin, DBSession, OptionalAdmin
from ..schemas import ChecklistCreate, ChecklistOut, ChecklistUpdate
from ..services import ChecklistService


router = APIRouter()


@router.get("/", response_model=List[ChecklistOut])
def list_checklists(
    db: DBSession,
    is_admin: OptionalAdmin,
    offset: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    status: str | None = None,
    include_drafts: bool = False,
) -> list[ChecklistOut]:
    if (include_drafts or (status and status != "published")) and not is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return ChecklistService.list(db, offset=offset, limit=limit, status=status, include_drafts=include_drafts)


@router.get("/{checklist_id}", response_model=ChecklistOut)
def get_checklist(checklist_id: str, db: DBSession, is_admin: OptionalAdmin) -> ChecklistOut:
    obj = ChecklistService.get(db, checklist_id)
    if not obj or ((obj.status != "published" or not obj.is_published) and not is_admin):
        raise HTTPException(status_code=404, detail="Checklist not found")
    return obj


@router.post("/", response_model=ChecklistOut)
def create_checklist(payload: ChecklistCreate, db: DBSession, req: Request, _: CurrentAdmin) -> ChecklistOut:
    try:
        obj = ChecklistService.create(db, payload)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    try:
        from ..services.audit import log_audit
        log_audit(db, user_email=req.headers.get("x-user-email") or "admin", action="create", entity="checklists", entity_id=obj.id, before=None, after=obj)
    except Exception:
        pass
    return obj


@router.put("/{checklist_id}", response_model=ChecklistOut)
def update_checklist(checklist_id: str, payload: ChecklistUpdate, db: DBSession, req: Request, _: CurrentAdmin) -> ChecklistOut:
    obj = ChecklistService.get(db, checklist_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Checklist not found")
    before = obj
    try:
        obj = ChecklistService.update(db, obj, payload)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    try:
        from ..services.audit import log_audit
        log_audit(db, user_email=req.headers.get("x-user-email") or "admin", action="update", entity="checklists", entity_id=obj.id, before=before, after=obj)
    except Exception:
        pass
    return obj


@router.delete("/{checklist_id}", status_code=204)
def delete_checklist(checklist_id: str, db: DBSession, req: Request, _: CurrentAdmin) -> None:
    obj = ChecklistService.get(db, checklist_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Checklist not found")
    ChecklistService.delete(db, obj)
    try:
        from ..services.audit import log_audit
        log_audit(db, user_email=req.headers.get("x-user-email") or "admin", action="delete", entity="checklists", entity_id=checklist_id, before=obj, after=None)
    except Exception:
        pass
    return None
