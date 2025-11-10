from __future__ import annotations

from typing import Any, Dict, List
import re
import time
from datetime import datetime
from urllib.parse import urlparse, urljoin

from fastapi import APIRouter
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..dependencies import DBSession, CurrentAdmin
from ..models import User, Guide, Template, Checklist, Appointment
from ..models.news import News
from ..schemas import GuideCreate, TemplateCreate, ChecklistCreate
from ..core.config import get_settings
from ..routers.media import UPLOAD_DIR
import feedparser
import httpx


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
        "news": db.scalar(select(func.count()).select_from(News)) or 0,
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

@router.post("/import/news/rss")
def import_news_rss(payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    """
    Import news items from an RSS/Atom feed.
    Body:
      - feed_url: str
      - language: str = 'uk'
      - status: 'draft'|'published' = 'draft'
      - max_items: int = 50
      - download_images: bool = True
      - extract_full: bool = False (reserved)
    """
    feed_url = payload.get("feed_url")
    if not feed_url:
        return {"created": 0, "updated": 0, "skipped": 0, "error": "feed_url is required"}
    language = payload.get("language", "uk")
    status = payload.get("status", "draft")
    max_items = int(payload.get("max_items", 50))
    download_images = bool(payload.get("download_images", True))

    # Fetch feed with proper headers (some hosts block default user agents)
    client = httpx.Client(timeout=10, follow_redirects=True, headers={
        "User-Agent": "SweezyRSS/1.0 (+https://sweezy.onrender.com)"
    })
    try:
        resp = client.get(feed_url)
        text = resp.text if resp.status_code < 400 else ""
    except Exception:
        text = ""
    parsed = feedparser.parse(text or feed_url)
    # If no entries, try to discover <link rel="alternate" type="application/rss+xml|atom+xml">
    if not getattr(parsed, "entries", None):
        try:
            html = text or ""
            if not html:
                html = client.get(feed_url).text
            import re as _re
            m = _re.search(r'<link[^>]+type="application/(?:rss|atom)\+xml"[^>]+href="([^"]+)"', html, flags=_re.I)
            if m:
                feed_href = m.group(1)
                feed_abs = urljoin(feed_url, feed_href)
                text2 = client.get(feed_abs).text
                parsed = feedparser.parse(text2)
        except Exception:
            pass
    created = updated = skipped = 0
    src = parsed.feed.get("title") or (urlparse(feed_url).hostname or "RSS")

    # If still no entries — treat the URL as single article page and import via OpenGraph
    if not getattr(parsed, "entries", None):
        try:
            html = text or client.get(feed_url).text
            import re as _re
            def meta(prop=None, name=None):
                if prop:
                    m = _re.search(rf'<meta[^>]+property=["\']{_re.escape(prop)}["\'][^>]*content=["\']([^"\']+)["\']', html, flags=_re.I)
                    if m: return m.group(1)
                if name:
                    m = _re.search(rf'<meta[^>]+name=["\']{_re.escape(name)}["\'][^>]*content=["\']([^"\']+)["\']', html, flags=_re.I)
                    if m: return m.group(1)
                return None
            title = meta(prop="og:title") or meta(name="title")
            if not title:
                mtitle = _re.search(r'<title[^>]*>(.*?)</title>', html, flags=_re.I|_re.S)
                title = (mtitle.group(1).strip() if mtitle else "Untitled")
            desc = meta(prop="og:description") or meta(name="description") or ""
            img = meta(prop="og:image") or meta(name="image")
            pub = meta(prop="article:published_time") or meta(name="article:published_time")
            pub_dt = datetime.utcnow()
            try:
                # try ISO-8601 (trim timezone if necessary)
                p = pub.replace("Z","").split("+")[0] if pub else ""
                if p:
                    pub_dt = datetime.fromisoformat(p)
            except Exception:
                pass
            image_url = None
            if img:
                image_url = img
                if download_images:
                    try:
                        r = client.get(urljoin(feed_url, img))
                        if r.status_code == 200:
                            name = f"{__import__('uuid').uuid4()}.jpg"
                            (UPLOAD_DIR / name).write_bytes(r.content)
                            image_url = f"/media/{name}"
                    except Exception:
                        pass
            data = {
                "title": title.strip(),
                "summary": desc.strip(),
                "content": None,
                "url": feed_url,
                "source": src,
                "language": language,
                "status": status,
                "published_at": pub_dt,
                "image_url": image_url,
            }
            existing = db.query(News).filter(News.url == feed_url).first()
            from ..services.news_service import NewsService as _NS
            if existing:
                _NS.update(db, existing, **data); updated += 1
            else:
                _NS.create(db, **data); created += 1
        except Exception:
            skipped += 1
            client.close()
            return {"created": created, "updated": updated, "skipped": skipped}

    for entry in getattr(parsed, "entries", [])[:max_items]:
        try:
            url = entry.get("link")
            if not url:
                skipped += 1
                continue
            existing = db.query(News).filter(News.url == url).first()
            title = (entry.get("title") or "Untitled").strip()
            summary = entry.get("summary") or entry.get("description") or ""
            # published
            pub_dt = datetime.utcnow()
            if entry.get("published_parsed"):
                pub_dt = datetime.fromtimestamp(time.mktime(entry.published_parsed))
            # image
            image_url = None
            media = entry.get("media_content") or entry.get("enclosures") or []
            if isinstance(media, list) and media:
                m0 = media[0]
                if isinstance(m0, dict):
                    image_url = m0.get("url")
            if not image_url and isinstance(summary, str):
                import re as _re
                m = _re.search(r'<img[^>]+src="([^"]+)"', summary)
                if m:
                    image_url = m.group(1)
            # optionally download image
            if download_images and image_url:
                try:
                    r = client.get(image_url)
                    if r.status_code == 200:
                        ext = ".jpg"
                        name = f"{__import__('uuid').uuid4()}{ext}"
                        (UPLOAD_DIR / name).write_bytes(r.content)
                        image_url = f"/media/{name}"
                except Exception:
                    pass

            data = {
                "title": title,
                "summary": summary,
                "content": None,
                "url": url,
                "source": src,
                "language": language,
                "status": status,
                "published_at": pub_dt,
                "image_url": image_url,
            }
            if existing:
                from ..services.news_service import NewsService as _NS
                _NS.update(db, existing, **data)
                updated += 1
            else:
                from ..services.news_service import NewsService as _NS
                _NS.create(db, **data)
                created += 1
        except Exception:
            skipped += 1
            continue
    client.close()
    return {"created": created, "updated": updated, "skipped": skipped}


@router.post("/import/news")
def import_news(payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    items = payload.get("items") or []
    created = 0
    for raw in items:
        try:
            title = raw.get("title") or "Untitled"
            summary = raw.get("summary") or ""
            url = raw.get("url") or ""
            source = raw.get("source") or "Sweezy"
            language = raw.get("language") or "uk"
            published_at = raw.get("published_at") or raw.get("date") or None
            image_url = raw.get("image_url")
            if not url:
                continue
            obj = News(
                id=str(__import__("uuid").uuid4()),
                title=title,
                summary=summary,
                url=url,
                source=source,
                language=language,
                published_at=__import__("datetime").datetime.fromisoformat(published_at) if isinstance(published_at, str) else (__import__("datetime").datetime.utcnow()),
                image_url=image_url,
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


