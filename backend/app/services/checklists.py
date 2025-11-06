from __future__ import annotations

from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Checklist
from ..schemas import ChecklistCreate, ChecklistUpdate


class ChecklistService:
    @staticmethod
    def list(db: Session, *, offset: int = 0, limit: int = 100) -> List[Checklist]:
        stmt = select(Checklist).offset(offset).limit(limit)
        return list(db.execute(stmt).scalars().all())

    @staticmethod
    def get(db: Session, checklist_id: str) -> Optional[Checklist]:
        return db.get(Checklist, checklist_id)

    @staticmethod
    def create(db: Session, data: ChecklistCreate) -> Checklist:
        obj = Checklist(**data.model_dump())
        db.add(obj)
        db.commit()
        db.refresh(obj)
        return obj

    @staticmethod
    def update(db: Session, checklist: Checklist, data: ChecklistUpdate) -> Checklist:
        for key, value in data.model_dump(exclude_unset=True).items():
            setattr(checklist, key, value)
        db.add(checklist)
        db.commit()
        db.refresh(checklist)
        return checklist

    @staticmethod
    def delete(db: Session, checklist: Checklist) -> None:
        db.delete(checklist)
        db.commit()


