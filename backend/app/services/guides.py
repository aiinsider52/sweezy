from __future__ import annotations

from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Guide
from ..schemas import GuideCreate, GuideUpdate
from .official_sources import validate_publishable_source


class GuideService:
    @staticmethod
    def list(db: Session, *, offset: int = 0, limit: int = 100, status: str | None = None, include_drafts: bool = False) -> List[Guide]:
        stmt = select(Guide)
        if status:
            stmt = stmt.where(getattr(Guide, "status", None) == status)  # type: ignore[attr-defined]
        elif not include_drafts:
            # fallback: filter published via status or is_published
            if hasattr(Guide, "status"):
                stmt = stmt.where(Guide.status == "published")  # type: ignore[attr-defined]
            else:
                stmt = stmt.where(Guide.is_published == True)  # noqa: E712
        stmt = stmt.offset(offset).limit(limit)
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
        validate_publishable_source(
            is_published=data.is_published,
            status=data.status,
            source_url=data.source_url,
            source_title=data.source_title,
            verified_at=data.verified_at,
        )
        obj = Guide(**data.model_dump())
        db.add(obj)
        db.commit()
        db.refresh(obj)
        return obj

    @staticmethod
    def update(db: Session, guide: Guide, data: GuideUpdate) -> Guide:
        changes = data.model_dump(exclude_unset=True)
        validate_publishable_source(
            is_published=changes.get("is_published", guide.is_published),
            status=changes.get("status", guide.status),
            source_url=changes.get("source_url", guide.source_url),
            source_title=changes.get("source_title", guide.source_title),
            verified_at=changes.get("verified_at", guide.verified_at),
        )
        for key, value in changes.items():
            setattr(guide, key, value)
        db.add(guide)
        db.commit()
        db.refresh(guide)
        return guide

    @staticmethod
    def delete(db: Session, guide: Guide) -> None:
        db.delete(guide)
        db.commit()

