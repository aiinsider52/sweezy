from __future__ import annotations

from typing import Any, Dict, List
import re

from fastapi import APIRouter
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..dependencies import DBSession, CurrentAdmin
from ..models import User, Guide, Template, Checklist, Appointment
from ..schemas import GuideCreate, TemplateCreate, ChecklistCreate
from ..core.config import get_settings


router = APIRouter()


@router.get("/stats")
def stats(_: CurrentAdmin, db: DBSession) -> Dict[str, Any]:
    settings = get_settings()
    counts = {
        "users": db.scalar(select(func.count()).select_from(User)) or 0,
        "guides": db.scalar(select(func.count()).select_from(Guide)) or 0,
        "templates": db.scalar(select(func.count()).select_from(Template)) or 0,
        "checklists": db.scalar(select(func.count()).select_from(Checklist)) or 0,
        "appointments": db.scalar(select(func.count()).select_from(Appointment)) or 0,
    }
    return {
        "app_version": settings.APP_VERSION,
        "counts": counts,
    }


@router.get("/users")
def list_users(_: CurrentAdmin, db: DBSession) -> List[Dict[str, Any]]:
    rows = (
        db.query(User.id, User.email, User.is_superuser, User.created_at)
        .order_by(User.created_at.desc())
        .limit(100)
        .all()
    )
    return [
        {
            "id": r.id,
            "email": r.email,
            "is_superuser": bool(r.is_superuser),
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]


@router.get("/activity")
def activity(_: CurrentAdmin, db: DBSession) -> Dict[str, Any]:
    def recent_simple(model):
        created = getattr(model, "created_at")
        rows = db.query(model.id, created).order_by(created.desc()).limit(5).all()
        return [
            {"id": r.id, "created_at": r.created_at.isoformat() if r.created_at else None}
            for r in rows
        ]

    recent_users = (
        db.query(User.id, User.email, User.created_at)
        .order_by(User.created_at.desc())
        .limit(5)
        .all()
    )
    return {
        "users": [
            {
                "id": r.id,
                "email": r.email,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in recent_users
        ],
        "guides": recent_simple(Guide),
        "templates": recent_simple(Template),
        "checklists": recent_simple(Checklist),
        "appointments": recent_simple(Appointment),
    }


@router.get("/categories/guides")
def guide_categories(_: CurrentAdmin) -> Dict[str, Any]:
    # Keep in sync with Swift enum GuideCategory
    categories = [
        "documents", "housing", "insurance", "work", "finance", "education",
        "healthcare", "legal", "emergency", "integration", "transport", "banking",
    ]
    return {"categories": categories}


@router.post("/import/guides")
def import_guides(payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    items = payload.get("items") or []
    created = 0
    for raw in items:
        try:
            try:
                # Try backend shape first
                data = GuideCreate(**raw)
                title = data.title
                slug = data.slug
                description = data.description
                content = data.content
                category = data.category
                image_url = getattr(data, "image_url", None)
                is_published = data.is_published
                version = data.version
            except Exception:
                # Fallback to iOS seed shape
                def slugify(s: str) -> str:
                    s = s.lower()
                    s = re.sub(r"[^a-z0-9\s-]", "", s)
                    s = re.sub(r"[\s-]+", "-", s).strip("-")
                    return s or "guide"

                title = raw.get("title") or raw.get("name") or "Untitled"
                slug = raw.get("slug") or slugify(title)
                description = raw.get("subtitle") or raw.get("description")
                content = raw.get("bodyMarkdown") or raw.get("content")
                category = (raw.get("category") or "documents")
                image_url = raw.get("heroImage") or raw.get("image_url")
                is_published = bool(raw.get("is_published", True))
                version = int(raw.get("version", 1))

            obj = Guide(
                title=title,
                slug=slug,
                description=description,
                content=content,
                category=category,
                image_url=image_url,
                is_published=is_published,
                version=version,
            )
            db.add(obj)
            created += 1
        except Exception:
            continue
    db.commit()
    return {"created": created}


@router.post("/import/templates")
def import_templates(payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    items = payload.get("items") or []
    created = 0
    for raw in items:
        try:
            try:
                data = TemplateCreate(**raw)
                name = data.name
                category = data.category
                content = data.content
            except Exception:
                name = raw.get("name") or raw.get("title") or "Untitled"
                category = raw.get("category") or "general"
                content = raw.get("content") or ""
            obj = Template(name=name, category=category, content=content)
            db.add(obj)
            created += 1
        except Exception:
            continue
    db.commit()
    return {"created": created}


@router.post("/import/checklists")
def import_checklists(payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    items = payload.get("items") or []
    created = 0
    for raw in items:
        try:
            try:
                data = ChecklistCreate(**raw)
                title = data.title
                description = data.description
                items_list = data.items
                is_published = data.is_published
            except Exception:
                title = raw.get("title") or "Checklist"
                description = raw.get("description") or ""
                # iOS shape: steps: [{ title: ... }]
                if isinstance(raw.get("steps"), list):
                    items_list = [str(step.get("title") or step.get("description") or "Step") for step in raw.get("steps", [])]
                else:
                    items_list = raw.get("items") or []
                is_published = bool(raw.get("is_published", True))
            obj = Checklist(title=title, description=description, items=items_list, is_published=is_published)
            db.add(obj)
            created += 1
        except Exception:
            continue
    db.commit()
    return {"created": created}


