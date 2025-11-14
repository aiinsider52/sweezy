from __future__ import annotations

from typing import Any, Dict, List
import re
import time
from datetime import datetime
from urllib.parse import urlparse, urljoin

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..dependencies import DBSession, CurrentAdmin
from ..models import User, Guide, Template, Checklist, Appointment
from ..models.audit_log import AuditLog
from ..models.news import News
from ..schemas import GuideCreate, TemplateCreate, ChecklistCreate
from ..core.config import get_settings
from ..routers.media import UPLOAD_DIR
from ..models.rss_feed import RSSFeed
from ..services.rss_importer import RSSImporter
from ..models.subscription import Subscription, SubscriptionEvent
from ..models.analytics import PaywallEvent
from ..services import stripe_service
from datetime import datetime, timedelta, timezone
from sqlalchemy import func
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
        db.query(User.id, User.email, User.is_superuser, User.role, User.created_at)
        .order_by(User.created_at.desc())
        .limit(100)
        .all()
    )
    return [
        {
            "id": r.id,
            "email": r.email,
            "is_superuser": bool(r.is_superuser),
            "role": r.role,
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


@router.put("/users/{user_id}/role")
def update_user_role(user_id: str, payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    role = payload.get("role")
    if role not in ["admin", "editor", "translator", "viewer"]:
        raise HTTPException(status_code=400, detail="Invalid role")
    user.role = role
    # Keep is_superuser in sync for 'admin'
    user.is_superuser = bool(role == "admin")
    db.add(user)
    db.commit()
    return {"ok": True}


@router.get("/audit-logs")
def list_audit_logs(_: CurrentAdmin, db: DBSession, limit: int = 100) -> List[Dict[str, Any]]:
    rows = db.query(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit).all()
    return [
        {
            "id": r.id,
            "user_email": r.user_email,
            "action": r.action,
            "entity": r.entity,
            "entity_id": r.entity_id,
            "changes": r.changes,
            "created_at": r.created_at.isoformat(),
        }
        for r in rows
    ]
 
 
@router.get("/subscriptions")
def list_subscriptions(_: CurrentAdmin, db: DBSession, limit: int = 200) -> List[Dict[str, Any]]:
    rows = (
        db.query(User.id, User.email, User.subscription_status, User.subscription_expire_at, User.stripe_customer_id, User.stripe_subscription_id)
        .order_by(User.created_at.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "user_id": r[0],
            "email": r[1],
            "status": r[2],
            "expire_at": r[3].isoformat() if r[3] else None,
            "stripe_customer_id": r[4],
            "stripe_subscription_id": r[5],
        }
        for r in rows
    ]
 
 
@router.get("/subscriptions/events")
def list_subscription_events(_: CurrentAdmin, db: DBSession, limit: int = 200) -> List[Dict[str, Any]]:
    rows = (
        db.query(SubscriptionEvent)
        .order_by(SubscriptionEvent.created_at.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "id": e.id,
            "user_id": e.user_id,
            "type": e.type,
            "payload": e.payload,
            "created_at": e.created_at.isoformat() if e.created_at else None,
        }
        for e in rows
    ]
 
 
@router.post("/users/{user_id}/subscription")
def set_user_subscription(user_id: str, payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    status_value = payload.get("status")
    if status_value not in {"free", "trial", "premium"}:
        raise HTTPException(status_code=400, detail="Invalid status")
    if status_value == "free":
        stripe_service.apply_free(db, user)
    elif status_value == "trial":
        stripe_service.apply_trial(db, user, days=7)
    else:
        # Manual premium with optional plan and duration
        plan = payload.get("plan") or "monthly"  # 'monthly' | 'yearly'
        if plan not in {"monthly", "yearly"}:
            plan = "monthly"
        period = timedelta(days=365 if plan == "yearly" else 30)
        expire_at = datetime.now(timezone.utc) + period
        # Ensure subscriptions row
        sub = db.query(Subscription).filter(Subscription.user_id == user.id).one_or_none()
        if sub is None:
            sub = Subscription(user_id=user.id, status="active", plan=plan, current_period_end=expire_at)
        else:
            sub.status = "active"
            sub.plan = plan
            sub.current_period_end = expire_at
        user.subscription_status = "premium"
        user.subscription_expire_at = expire_at
        db.add(sub)
        db.add(user)
        db.commit()
    return {"ok": True}

@router.get("/subscriptions/analytics")
def subscriptions_analytics(_: CurrentAdmin, db: DBSession, months: int = 6) -> Dict[str, Any]:
    # Totals by plan
    monthly = db.query(func.count()).select_from(Subscription).filter(Subscription.status == "active", Subscription.plan == "monthly").scalar() or 0
    yearly = db.query(func.count()).select_from(Subscription).filter(Subscription.status == "active", Subscription.plan == "yearly").scalar() or 0
    premium_users = db.query(func.count()).select_from(User).filter(User.subscription_status == "premium").scalar() or 0
    trial_users = db.query(func.count()).select_from(User).filter(User.subscription_status == "trial").scalar() or 0
    free_users = db.query(func.count()).select_from(User).filter(User.subscription_status == "free").scalar() or 0
    # Last 6 months time series
    rows = (
        db.query(
            func.date_trunc("month", Subscription.created_at).label("m"),
            func.sum(func.case((Subscription.plan == "monthly", 1), else_=0)).label("monthly"),
            func.sum(func.case((Subscription.plan == "yearly", 1), else_=0)).label("yearly"),
        )
        .filter(Subscription.status == "active")
        .group_by(func.date_trunc("month", Subscription.created_at))
        .order_by(func.date_trunc("month", Subscription.created_at).desc())
        .limit(max(1, min(24, months)))
        .all()
    )
    series = [
        {"month": r[0].strftime("%Y-%m"), "monthly": int(r[1] or 0), "yearly": int(r[2] or 0)}
        for r in reversed(rows)
    ]
    return {
        "totals": {
            "monthly": int(monthly),
            "yearly": int(yearly),
            "premium_users": int(premium_users),
            "trial_users": int(trial_users),
            "free_users": int(free_users),
        },
        "by_month": series,
    }

@router.get("/paywall/funnel")
def paywall_funnel(_: CurrentAdmin, db: DBSession, days: int = 30) -> Dict[str, Any]:
    """
    Returns counts for paywall events over the last N days.
    """
    from datetime import datetime, timedelta, timezone
    since = datetime.now(timezone.utc) - timedelta(days=max(1, min(365, days)))
    rows = (
        db.query(PaywallEvent.event_type, func.count().label("cnt"))
        .filter(PaywallEvent.created_at >= since)
        .group_by(PaywallEvent.event_type)
        .all()
    )
    by_type = {r[0]: int(r[1]) for r in rows}
    contexts = (
        db.query(PaywallEvent.context, func.count().label("cnt"))
        .filter(PaywallEvent.created_at >= since)
        .group_by(PaywallEvent.context)
        .order_by(func.count().desc())
        .limit(10)
        .all()
    )
    top_contexts = [{"context": r[0] or "none", "count": int(r[1])} for r in contexts]
    return {"by_type": by_type, "top_contexts": top_contexts, "since": since.isoformat()}

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

@router.get("/rss-feeds")
def list_rss_feeds(_: CurrentAdmin, db: DBSession) -> List[Dict[str, Any]]:
    rows = db.query(RSSFeed).order_by(RSSFeed.created_at.desc()).all()
    return [{
        "id": r.id,
        "url": r.url,
        "language": r.language,
        "status": r.status,
        "enabled": bool(r.enabled),
        "max_items": r.max_items,
        "download_images": bool(r.download_images),
        "last_imported_at": r.last_imported_at.isoformat() if r.last_imported_at else None,
    } for r in rows]

@router.post("/rss-feeds")
def create_rss_feed(payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    r = RSSFeed(
        id=str(__import__("uuid").uuid4()),
        url=payload["url"],
        language=payload.get("language", "uk"),
        status=payload.get("status", "draft"),
        enabled=bool(payload.get("enabled", True)),
        max_items=int(payload.get("max_items", 20)),
        download_images=bool(payload.get("download_images", True)),
        created_at=__import__("datetime").datetime.utcnow(),
        updated_at=__import__("datetime").datetime.utcnow(),
    )
    db.add(r); db.commit()
    return {"id": r.id}

@router.delete("/rss-feeds/{feed_id}")
def delete_rss_feed(feed_id: str, db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    r = db.query(RSSFeed).filter(RSSFeed.id == feed_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Not found")
    db.delete(r); db.commit()
    return {"ok": True}

@router.post("/rss-feeds/{feed_id}/import")
def run_rss_feed_import(feed_id: str, db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    r = db.query(RSSFeed).filter(RSSFeed.id == feed_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Not found")
    return RSSImporter.import_feed_record(db, r)

@router.patch("/rss-feeds/{feed_id}")
def update_rss_feed(feed_id: str, payload: Dict[str, Any], db: DBSession, _: CurrentAdmin) -> Dict[str, Any]:
    r = db.query(RSSFeed).filter(RSSFeed.id == feed_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Not found")
    for k in ["url","language","status"]:
        if k in payload and payload[k] is not None:
            setattr(r, k, payload[k])
    if "enabled" in payload: r.enabled = bool(payload["enabled"])
    if "max_items" in payload: r.max_items = int(payload["max_items"])
    if "download_images" in payload: r.download_images = bool(payload["download_images"])
    r.updated_at = __import__("datetime").datetime.utcnow()
    db.add(r); db.commit()
    return {"ok": True}

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


