from typing import List

from fastapi import APIRouter, HTTPException, Query, Request

from ..dependencies import CurrentAdmin, DBSession, OptionalAdmin
from ..schemas import TemplateCreate, TemplateOut, TemplateUpdate
from ..services import TemplateService
from ..services.audit import log_audit


router = APIRouter()


@router.get("/", response_model=List[TemplateOut])
def list_templates(
    db: DBSession,
    is_admin: OptionalAdmin,
    offset: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    status: str | None = None,
    include_drafts: bool = False,
) -> list[TemplateOut]:
    if (include_drafts or (status and status != "published")) and not is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return TemplateService.list(db, offset=offset, limit=limit, status=status, include_drafts=include_drafts)


@router.get("/{template_id}", response_model=TemplateOut)
def get_template(template_id: str, db: DBSession, is_admin: OptionalAdmin) -> TemplateOut:
    obj = TemplateService.get(db, template_id)
    if not obj or (obj.status != "published" and not is_admin):
        raise HTTPException(status_code=404, detail="Template not found")
    return obj


@router.post("/", response_model=TemplateOut)
def create_template(payload: TemplateCreate, db: DBSession, req: Request, _: CurrentAdmin) -> TemplateOut:
    obj = TemplateService.create(db, payload)
    log_audit(db, user_email=req.headers.get("x-user-email") or "admin", action="create", entity="templates", entity_id=obj.id, before=None, after=obj)
    return obj


@router.put("/{template_id}", response_model=TemplateOut)
def update_template(template_id: str, payload: TemplateUpdate, db: DBSession, req: Request, _: CurrentAdmin) -> TemplateOut:
    obj = TemplateService.get(db, template_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Template not found")
    before = obj
    obj = TemplateService.update(db, obj, payload)
    log_audit(db, user_email=req.headers.get("x-user-email") or "admin", action="update", entity="templates", entity_id=obj.id, before=before, after=obj)
    return obj


@router.delete("/{template_id}", status_code=204)
def delete_template(template_id: str, db: DBSession, req: Request, _: CurrentAdmin) -> None:
    obj = TemplateService.get(db, template_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Template not found")
    TemplateService.delete(db, obj)
    log_audit(db, user_email=req.headers.get("x-user-email") or "admin", action="delete", entity="templates", entity_id=template_id, before=obj, after=None)
    return None

