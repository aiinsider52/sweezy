"""Idempotent bootstrap of guides/checklists/templates/news from iOS seed JSON.

Runs on startup when tables are empty so production Directory/News are not blank
after a fresh database. Existing rows are never overwritten.
"""
from __future__ import annotations

import json
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

from sqlalchemy.orm import Session

from ..models.checklist import Checklist
from ..models.guide import Guide
from ..models.news import News
from ..models.template import Template


REPO_ROOT = Path(__file__).resolve().parents[3]
SEED_DIRS = [
    REPO_ROOT / "sweezy" / "sweezy" / "Resources" / "AppContent" / "seeds",
    REPO_ROOT / "backend" / "seeds",
]


def _seed_dir() -> Optional[Path]:
    for path in SEED_DIRS:
        if path.exists():
            return path
    return None


def _slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9\s-]", "", value)
    value = re.sub(r"[\s-]+", "-", value).strip("-")
    return value[:80] or "guide"


def _load_json_lists(seed_dir: Path, names: list[str]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for name in names:
        path = seed_dir / name
        if not path.exists():
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if isinstance(data, list):
            rows.extend([item for item in data if isinstance(item, dict)])
    return rows


def _seed_guides(db: Session, seed_dir: Path) -> int:
    if db.query(Guide.id).first() is not None:
        return 0
    files = [
        "guides_uk.json",
        "guides_comprehensive_uk.json",
        "guides_documents_all.json",
        "guides_housing_all.json",
        "guides_health_insurance_all.json",
        "guides_work_finance_all.json",
        "guides_education_integration_all.json",
        "guides_legal_emergency_all.json",
        "guides_transport_banking_all.json",
        "guides_lifestyle_uk.json",
        "guides_extra.json",
    ]
    seen_slugs: set[str] = set()
    created = 0
    for raw in _load_json_lists(seed_dir, files):
        title = raw.get("title") or raw.get("name")
        if not title:
            continue
        slug = str(raw.get("slug") or _slugify(str(title)))
        base = slug
        n = 2
        while slug in seen_slugs:
            slug = f"{base}-{n}"
            n += 1
        seen_slugs.add(slug)
        category = raw.get("category") or "documents"
        if isinstance(category, dict):
            category = category.get("rawValue") or "documents"
        description = raw.get("subtitle") or raw.get("description")
        if isinstance(description, str):
            description = description[:500]
        content = raw.get("bodyMarkdown") or raw.get("content")
        if isinstance(content, str) and len(content) > 50000:
            content = content[:50000]
        source_url = None
        source_title = raw.get("sourceTitle")
        source = raw.get("source")
        if isinstance(source, dict):
            source_url = source.get("url")
            source_title = source.get("title") or source_title
        elif isinstance(source, str):
            source_title = source_title or source
        guide_id = str(raw.get("id") or uuid.uuid5(uuid.NAMESPACE_URL, f"guide:{slug}"))
        db.add(
            Guide(
                id=guide_id,
                title=str(title),
                slug=slug,
                description=description,
                content=content,
                category=str(category),
                image_url=raw.get("heroImage") or raw.get("image_url"),
                source_url=source_url,
                source_title=source_title,
                is_published=True,
                status="published",
                version=int(raw.get("version") or 1),
            )
        )
        created += 1
        if created >= 120:
            break
    if created:
        db.commit()
    return created


def _seed_checklists(db: Session, seed_dir: Path) -> int:
    if db.query(Checklist.id).first() is not None:
        return 0
    created = 0
    for raw in _load_json_lists(seed_dir, ["checklists_uk.json", "checklists.json", "checklists_extra.json"]):
        title = raw.get("title") or raw.get("name")
        if not title:
            continue
        steps = raw.get("steps") or raw.get("items") or []
        items: list[Any] = []
        for step in steps:
            if isinstance(step, str):
                items.append(step)
            elif isinstance(step, dict):
                items.append(step.get("title") or step.get("text") or step.get("name") or step)
        checklist_id = str(raw.get("id") or uuid.uuid5(uuid.NAMESPACE_URL, f"checklist:{title}"))
        description = raw.get("description") or raw.get("subtitle")
        if isinstance(description, str):
            description = description[:500]
        db.add(
            Checklist(
                id=checklist_id,
                title=str(title),
                description=description,
                items=items,
                is_published=True,
                status="published",
            )
        )
        created += 1
    if created:
        db.commit()
    return created


def _seed_templates(db: Session, seed_dir: Path) -> int:
    if db.query(Template.id).first() is not None:
        return 0
    created = 0
    for raw in _load_json_lists(seed_dir, ["templates.json", "templates_uk.json"]):
        name = raw.get("name") or raw.get("title")
        if not name:
            continue
        content = raw.get("content") or raw.get("body") or raw.get("bodyMarkdown") or ""
        template_id = str(raw.get("id") or uuid.uuid5(uuid.NAMESPACE_URL, f"template:{name}"))
        db.add(
            Template(
                id=template_id,
                name=str(name),
                category=str(raw.get("category") or "general"),
                content=str(content),
                status="published",
            )
        )
        created += 1
    if created:
        db.commit()
    return created


def _seed_news(db: Session) -> int:
    if db.query(News.id).first() is not None:
        return 0
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    rows = [
        ("Вітаємо у Sweezy", "Короткий гайд зі старту в Швейцарії вже в додатку.", "uk"),
        ("Permit checklist", "What to prepare before your first Gemeinde appointment.", "en"),
        ("Krankenversicherung", "Fristen und Tipps zur Grundversicherung in der Schweiz.", "de"),
    ]
    for title, summary, language in rows:
        news_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"news:{title}"))
        db.add(
            News(
                id=news_id,
                title=title,
                summary=summary,
                content=summary,
                url="https://sweezy.app",
                source="Sweezy",
                language=language,
                status="published",
                import_source="seed",
                published_at=now,
                created_at=now,
                updated_at=now,
            )
        )
    db.commit()
    return len(rows)


def seed_core_content(db: Session) -> dict[str, int]:
    seed_dir = _seed_dir()
    result = {"guides": 0, "checklists": 0, "templates": 0, "news": 0}
    if seed_dir is not None:
        result["guides"] = _seed_guides(db, seed_dir)
        result["checklists"] = _seed_checklists(db, seed_dir)
        result["templates"] = _seed_templates(db, seed_dir)
    result["news"] = _seed_news(db)
    return result
