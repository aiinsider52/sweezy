from __future__ import annotations

from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Checklist
from ..schemas import ChecklistCreate, ChecklistUpdate
from .official_sources import validate_publishable_source


class ChecklistService:
    @staticmethod
    def list(db: Session, *, offset: int = 0, limit: int = 100, status: str | None = None, include_drafts: bool = False) -> List[Checklist]:
        stmt = select(Checklist)
        if status:
            stmt = stmt.where(getattr(Checklist, "status", None) == status)  # type: ignore[attr-defined]
        elif not include_drafts and hasattr(Checklist, "status"):
            stmt = stmt.where(Checklist.status == "published")  # type: ignore[attr-defined]
        stmt = stmt.offset(offset).limit(limit)
        return list(db.execute(stmt).scalars().all())

    @staticmethod
    def get(db: Session, checklist_id: str) -> Optional[Checklist]:
        return db.get(Checklist, checklist_id)

    @staticmethod
    def create(db: Session, data: ChecklistCreate) -> Checklist:
        validate_publishable_source(
            is_published=data.is_published,
            status=data.status,
            source_url=data.source_url,
            source_title=data.source_title,
            verified_at=data.verified_at,
        )
        obj = Checklist(**data.model_dump())
        db.add(obj)
        db.commit()
        db.refresh(obj)
        return obj

    @staticmethod
    def update(db: Session, checklist: Checklist, data: ChecklistUpdate) -> Checklist:
        changes = data.model_dump(exclude_unset=True)
        validate_publishable_source(
            is_published=changes.get("is_published", checklist.is_published),
            status=changes.get("status", checklist.status),
            source_url=changes.get("source_url", checklist.source_url),
            source_title=changes.get("source_title", checklist.source_title),
            verified_at=changes.get("verified_at", checklist.verified_at),
        )
        for key, value in changes.items():
            setattr(checklist, key, value)
        db.add(checklist)
        db.commit()
        db.refresh(checklist)
        return checklist

    @staticmethod
    def delete(db: Session, checklist: Checklist) -> None:
        db.delete(checklist)
        db.commit()

