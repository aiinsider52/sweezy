from __future__ import annotations

from typing import List

from fastapi import APIRouter, HTTPException, Query

from ..dependencies import CurrentAdmin, DBSession
from ..schemas import TemplateCreate, TemplateOut, TemplateUpdate
from ..services import TemplateService


router = APIRouter()


@router.get("/", response_model=List[TemplateOut])
def list_templates(db: DBSession, offset: int = Query(0, ge=0), limit: int = Query(100, ge=1, le=1000)) -> list[TemplateOut]:
    return TemplateService.list(db, offset=offset, limit=limit)


@router.get("/{template_id}", response_model=TemplateOut)
def get_template(template_id: str, db: DBSession) -> TemplateOut:
    obj = TemplateService.get(db, template_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Template not found")
    return obj


@router.post("/", response_model=TemplateOut)
def create_template(payload: TemplateCreate, db: DBSession, _: CurrentAdmin) -> TemplateOut:
    return TemplateService.create(db, payload)


@router.put("/{template_id}", response_model=TemplateOut)
def update_template(template_id: str, payload: TemplateUpdate, db: DBSession, _: CurrentAdmin) -> TemplateOut:
    obj = TemplateService.get(db, template_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Template not found")
    return TemplateService.update(db, obj, payload)


@router.delete("/{template_id}", status_code=204)
def delete_template(template_id: str, db: DBSession, _: CurrentAdmin) -> None:
    obj = TemplateService.get(db, template_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Template not found")
    TemplateService.delete(db, obj)
    return None


