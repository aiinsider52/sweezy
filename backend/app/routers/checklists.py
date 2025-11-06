from __future__ import annotations

from typing import List

from fastapi import APIRouter, HTTPException, Query

from ..dependencies import CurrentAdmin, DBSession
from ..schemas import ChecklistCreate, ChecklistOut, ChecklistUpdate
from ..services import ChecklistService


router = APIRouter()


@router.get("/", response_model=List[ChecklistOut])
def list_checklists(db: DBSession, offset: int = Query(0, ge=0), limit: int = Query(100, ge=1, le=1000)) -> list[ChecklistOut]:
    return ChecklistService.list(db, offset=offset, limit=limit)


@router.get("/{checklist_id}", response_model=ChecklistOut)
def get_checklist(checklist_id: str, db: DBSession) -> ChecklistOut:
    obj = ChecklistService.get(db, checklist_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Checklist not found")
    return obj


@router.post("/", response_model=ChecklistOut)
def create_checklist(payload: ChecklistCreate, db: DBSession, _: CurrentAdmin) -> ChecklistOut:
    return ChecklistService.create(db, payload)


@router.put("/{checklist_id}", response_model=ChecklistOut)
def update_checklist(checklist_id: str, payload: ChecklistUpdate, db: DBSession, _: CurrentAdmin) -> ChecklistOut:
    obj = ChecklistService.get(db, checklist_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Checklist not found")
    return ChecklistService.update(db, obj, payload)


@router.delete("/{checklist_id}", status_code=204)
def delete_checklist(checklist_id: str, db: DBSession, _: CurrentAdmin) -> None:
    obj = ChecklistService.get(db, checklist_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Checklist not found")
    ChecklistService.delete(db, obj)
    return None


