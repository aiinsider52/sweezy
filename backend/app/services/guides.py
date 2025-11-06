from __future__ import annotations

from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Guide
from ..schemas import GuideCreate, GuideUpdate


class GuideService:
    @staticmethod
    def list(db: Session, *, offset: int = 0, limit: int = 100) -> List[Guide]:
        stmt = select(Guide).offset(offset).limit(limit)
        return list(db.execute(stmt).scalars().all())

    @staticmethod
    def get(db: Session, guide_id: str) -> Optional[Guide]:
        return db.get(Guide, guide_id)

    @staticmethod
    def get_by_slug(db: Session, slug: str) -> Optional[Guide]:
        stmt = select(Guide).where(Guide.slug == slug)
        return db.execute(stmt).scalar_one_or_none()

    @staticmethod
    def create(db: Session, data: GuideCreate) -> Guide:
        obj = Guide(**data.model_dump())
        db.add(obj)
        db.commit()
        db.refresh(obj)
        return obj

    @staticmethod
    def update(db: Session, guide: Guide, data: GuideUpdate) -> Guide:
        for key, value in data.model_dump(exclude_unset=True).items():
            setattr(guide, key, value)
        db.add(guide)
        db.commit()
        db.refresh(guide)
        return guide

    @staticmethod
    def delete(db: Session, guide: Guide) -> None:
        db.delete(guide)
        db.commit()


